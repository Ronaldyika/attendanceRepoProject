"""
Attendance Serializers
======================
"""
import time
from django.conf import settings
from django.utils import timezone
from rest_framework import serializers

from .models import (
    AttendanceRecord,
    AttendanceSession,
    ConflictLog,
    Course,
    IntegrityLog,
    SyncBatch,
)
from .qr_utils import generate_qr_payload, verify_qr_payload


# ---------------------------------------------------------------------------
# Course
# ---------------------------------------------------------------------------
class CourseSerializer(serializers.ModelSerializer):
    lecturer_name = serializers.SerializerMethodField(read_only=True)
    enrolled_count = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Course
        fields = [
            "id", "code", "title", "lecturer", "lecturer_name",
            "enrolled_students", "enrolled_count", "is_active",
            "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def get_lecturer_name(self, obj):
        return obj.lecturer.get_full_name()

    def get_enrolled_count(self, obj):
        return obj.enrolled_students.count()

    def validate_lecturer(self, value):
        if value.role != "lecturer":
            raise serializers.ValidationError("Assigned lecturer must have the 'lecturer' role.")
        return value


# ---------------------------------------------------------------------------
# Attendance Session
# ---------------------------------------------------------------------------
class AttendanceSessionSerializer(serializers.ModelSerializer):
    course_code = serializers.SerializerMethodField(read_only=True)
    course_title = serializers.SerializerMethodField(read_only=True)
    lecturer_name = serializers.SerializerMethodField(read_only=True)
    attendance_count = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = AttendanceSession
        fields = [
            "id", "course", "course_code", "course_title",
            "created_by", "lecturer_name",
            "status", "started_at", "expires_at", "closed_at",
            "venue", "notes", "attendance_count",
        ]
        read_only_fields = [
            "id", "created_by", "started_at", "expires_at",
            "closed_at", "status",
        ]

    def get_course_code(self, obj):
        return obj.course.code

    def get_course_title(self, obj):
        return obj.course.title

    def get_lecturer_name(self, obj):
        return obj.created_by.get_full_name()

    def get_attendance_count(self, obj):
        return obj.records.count()


class SessionCreateSerializer(serializers.ModelSerializer):
    """Used when a lecturer opens a new session."""

    class Meta:
        model = AttendanceSession
        fields = ["course", "venue", "notes"]

    def create(self, validated_data):
        from .qr_utils import generate_session_secret
        from django.utils import timezone
        from datetime import timedelta

        validity = getattr(settings, "QR_CODE_VALIDITY_SECONDS", 900)
        secret = generate_session_secret()
        now = timezone.now()
        session = AttendanceSession.objects.create(
            **validated_data,
            created_by=self.context["request"].user,
            session_secret=secret,
            expires_at=now + timedelta(seconds=validity),
        )
        return session


class SessionWithQRSerializer(serializers.ModelSerializer):
    """Returned after session creation – includes the QR payload for the Lecturer device."""
    qr_payload = serializers.SerializerMethodField()
    expiry_unix = serializers.SerializerMethodField()
    course_code = serializers.SerializerMethodField()

    class Meta:
        model = AttendanceSession
        fields = [
            "id", "course", "course_code", "status",
            "started_at", "expires_at", "expiry_unix",
            "venue", "notes", "session_secret", "qr_payload",
        ]

    def get_qr_payload(self, obj):
        validity = getattr(settings, "QR_CODE_VALIDITY_SECONDS", 900)
        result = generate_qr_payload(
            session_id=str(obj.id),
            course_code=obj.course.code,
            secret=obj.session_secret,
            validity_seconds=validity,
        )
        return result["payload"]

    def get_expiry_unix(self, obj):
        return int(obj.expires_at.timestamp())

    def get_course_code(self, obj):
        return obj.course.code


# ---------------------------------------------------------------------------
# Attendance Record (single online scan)
# ---------------------------------------------------------------------------
class AttendanceRecordSerializer(serializers.ModelSerializer):
    student_name = serializers.SerializerMethodField(read_only=True)
    session_info = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = AttendanceRecord
        fields = [
            "id", "student", "student_name", "session", "session_info",
            "device_uuid", "scan_source", "scanned_at", "synced_at",
            "idempotency_key", "pending_sync",
        ]
        read_only_fields = [
            "id", "synced_at", "idempotency_key", "pending_sync",
        ]

    def get_student_name(self, obj):
        return obj.student.get_full_name()

    def get_session_info(self, obj):
        return {"id": str(obj.session.id), "course": obj.session.course.code}


class OnlineScanSerializer(serializers.Serializer):
    """
    Payload for a real-time (online) QR scan.
    The server validates the HMAC, expiry, device binding, and duplicates.
    """
    session_id = serializers.UUIDField()
    qr_payload = serializers.CharField()
    device_uuid = serializers.CharField()
    scanned_at = serializers.DateTimeField()

    def validate(self, attrs):
        from accounts.models import User

        student = self.context["request"].user
        if not student.is_student:
            raise serializers.ValidationError("Only students can record attendance.")

        # Device binding check
        if student.device_uuid and student.device_uuid != attrs["device_uuid"]:
            raise serializers.ValidationError(
                {"device_uuid": "Device UUID does not match the registered device for this account."}
            )

        # Fetch session
        try:
            session = AttendanceSession.objects.select_related("course").get(
                id=attrs["session_id"]
            )
        except AttendanceSession.DoesNotExist:
            raise serializers.ValidationError({"session_id": "Session not found."})

        if not session.is_open:
            raise serializers.ValidationError({"session_id": "Session is closed or expired."})

        # HMAC + expiry verification
        tolerance = getattr(settings, "CLOCK_SKEW_TOLERANCE_SECONDS", 300)
        ok, reason = verify_qr_payload(attrs["qr_payload"], session.session_secret, tolerance)
        if not ok:
            raise serializers.ValidationError({"qr_payload": f"QR verification failed: {reason}"})

        # Duplicate check
        if AttendanceRecord.objects.filter(
            student=student, session=session, device_uuid=attrs["device_uuid"]
        ).exists():
            raise serializers.ValidationError("Attendance already recorded for this session.")

        attrs["session"] = session
        attrs["student"] = student
        return attrs

    def create(self, validated_data):
        import time as time_mod
        student = validated_data["student"]
        session = validated_data["session"]
        device_uuid = validated_data["device_uuid"]
        scanned_at = validated_data["scanned_at"]

        idempotency_key = (
            f"{device_uuid}|{session.id}|{int(scanned_at.timestamp() * 1000)}"
        )
        record, _ = AttendanceRecord.objects.get_or_create(
            student=student,
            session=session,
            device_uuid=device_uuid,
            defaults={
                "scan_source": AttendanceRecord.ScanSource.ONLINE,
                "scanned_at": scanned_at,
                "synced_at": timezone.now(),
                "idempotency_key": idempotency_key,
                "pending_sync": False,
            },
        )
        return record


# ---------------------------------------------------------------------------
# Sync – Offline record item
# ---------------------------------------------------------------------------
class OfflineRecordItemSerializer(serializers.Serializer):
    """One attendance record within a sync batch payload."""
    session_id = serializers.UUIDField()
    device_uuid = serializers.CharField()
    scanned_at = serializers.DateTimeField()
    idempotency_key = serializers.CharField()
    hmac_signature = serializers.CharField()
    qr_payload = serializers.CharField()


class SyncBatchSerializer(serializers.Serializer):
    """Full batch synchronisation request from the student's mobile device."""
    device_uuid = serializers.CharField()
    records = OfflineRecordItemSerializer(many=True)


class SyncBatchResponseSerializer(serializers.ModelSerializer):
    class Meta:
        model = SyncBatch
        fields = [
            "id", "submitted_at", "total_records", "accepted_records",
            "rejected_records", "duplicate_records", "status",
        ]


# ---------------------------------------------------------------------------
# Conflict & Integrity Logs
# ---------------------------------------------------------------------------
class ConflictLogSerializer(serializers.ModelSerializer):
    student_name = serializers.SerializerMethodField()
    session_course = serializers.SerializerMethodField()

    class Meta:
        model = ConflictLog
        fields = [
            "id", "session", "session_course", "student", "student_name",
            "registered_device_uuid", "submitting_device_uuid",
            "created_at", "resolved", "resolution_note",
        ]
        read_only_fields = ["id", "created_at"]

    def get_student_name(self, obj):
        return obj.student.get_full_name()

    def get_session_course(self, obj):
        return obj.session.course.code


class IntegrityLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = IntegrityLog
        fields = [
            "id", "session", "student", "violation_type",
            "detail", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


# ---------------------------------------------------------------------------
# Report serializers
# ---------------------------------------------------------------------------
class SessionAttendanceReportSerializer(serializers.ModelSerializer):
    records = AttendanceRecordSerializer(many=True, read_only=True)
    course_code = serializers.SerializerMethodField()
    attendance_count = serializers.SerializerMethodField()

    class Meta:
        model = AttendanceSession
        fields = [
            "id", "course_code", "status", "started_at",
            "expires_at", "venue", "attendance_count", "records",
        ]

    def get_course_code(self, obj):
        return obj.course.code

    def get_attendance_count(self, obj):
        return obj.records.count()


from django.utils import timezone
