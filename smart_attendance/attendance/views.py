"""
Attendance Views
================
Organised into logical groups:
  1. Course CRUD
  2. Attendance Session lifecycle
  3. Online (real-time) QR scan
  4. Batch Synchronisation
  5. Reports & Analytics
  6. Conflict & Integrity log management
"""
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminUser, IsLecturer, IsLecturerOrAdmin, IsStudent

from .models import (
    AttendanceRecord,
    AttendanceSession,
    ConflictLog,
    Course,
    IntegrityLog,
    SyncBatch,
)
from .serializers import (
    AttendanceRecordSerializer,
    AttendanceSessionSerializer,
    ConflictLogSerializer,
    IntegrityLogSerializer,
    OnlineScanSerializer,
    SessionAttendanceReportSerializer,
    SessionCreateSerializer,
    SessionWithQRSerializer,
    SyncBatchResponseSerializer,
    SyncBatchSerializer,
    CourseSerializer,
)
from .sync_processor import process_sync_batch


# ===========================================================================
# 1. COURSE MANAGEMENT
# ===========================================================================
@extend_schema(tags=["Courses"])
class CourseListCreateView(generics.ListCreateAPIView):
    """
    GET  – List all courses (filtered to own courses for lecturers).
    POST – Create a new course (lecturer/admin only).
    """
    serializer_class = CourseSerializer

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsLecturerOrAdmin()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        user = self.request.user
        qs = Course.objects.select_related("lecturer").prefetch_related("enrolled_students")
        if user.is_lecturer:
            return qs.filter(lecturer=user)
        if user.is_student:
            return qs.filter(enrolled_students=user)
        return qs   # admin sees all

    def perform_create(self, serializer):
        serializer.save()


@extend_schema(tags=["Courses"])
class CourseDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update, or delete a single course."""
    serializer_class = CourseSerializer
    queryset = Course.objects.select_related("lecturer").prefetch_related("enrolled_students")

    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.IsAuthenticated()]
        return [IsLecturerOrAdmin()]


@extend_schema(
    tags=["Courses"],
    request={"application/json": {"type": "object", "properties": {
        "student_ids": {"type": "array", "items": {"type": "string", "format": "uuid"}}
    }}},
    responses={200: OpenApiResponse(description="Enrolment updated.")},
)
class CourseEnrolmentView(APIView):
    """Enrol or remove students from a course (lecturer / admin only)."""
    permission_classes = [IsLecturerOrAdmin]

    def post(self, request, pk):
        try:
            course = Course.objects.get(pk=pk)
        except Course.DoesNotExist:
            return Response({"detail": "Course not found."}, status=status.HTTP_404_NOT_FOUND)

        student_ids = request.data.get("student_ids", [])
        course.enrolled_students.set(student_ids)
        return Response({"message": f"Enrolment updated. {len(student_ids)} student(s) enrolled."})


# ===========================================================================
# 2. ATTENDANCE SESSION LIFECYCLE
# ===========================================================================
@extend_schema(tags=["Sessions"])
class SessionListCreateView(generics.ListCreateAPIView):
    """
    GET  – List sessions (lecturer sees own; students see sessions for their courses).
    POST – Open a new attendance session and receive the signed QR payload.
           **Lecturer only.**
    """

    def get_serializer_class(self):
        if self.request.method == "POST":
            return SessionCreateSerializer
        return AttendanceSessionSerializer

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsLecturer()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        user = self.request.user
        qs = AttendanceSession.objects.select_related("course", "created_by")
        if user.is_lecturer:
            return qs.filter(created_by=user)
        if user.is_student:
            return qs.filter(course__enrolled_students=user)
        return qs

    def create(self, request, *args, **kwargs):
        serializer = SessionCreateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        session = serializer.save()
        out = SessionWithQRSerializer(session, context={"request": request})
        return Response(out.data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Sessions"])
class SessionDetailView(generics.RetrieveAPIView):
    """Retrieve a single attendance session with its attendance count."""
    serializer_class = AttendanceSessionSerializer
    queryset = AttendanceSession.objects.select_related("course", "created_by")
    permission_classes = [permissions.IsAuthenticated]


@extend_schema(
    tags=["Sessions"],
    responses={200: OpenApiResponse(description="Session closed.")},
)
class SessionCloseView(APIView):
    """
    Close an open session manually.  **Lecturer only.**
    Once closed, no further QR scans are accepted for this session.
    """
    permission_classes = [IsLecturer]

    def post(self, request, pk):
        try:
            session = AttendanceSession.objects.get(pk=pk, created_by=request.user)
        except AttendanceSession.DoesNotExist:
            return Response({"detail": "Session not found or not yours."}, status=status.HTTP_404_NOT_FOUND)

        if session.status != AttendanceSession.Status.OPEN:
            return Response({"detail": f"Session is already {session.status}."}, status=status.HTTP_400_BAD_REQUEST)

        session.status = AttendanceSession.Status.CLOSED
        session.closed_at = timezone.now()
        session.save(update_fields=["status", "closed_at"])
        return Response({
            "message": "Session closed.",
            "session_id": str(session.id),
            "closed_at": session.closed_at.isoformat(),
        })


@extend_schema(
    tags=["Sessions"],
    responses={200: SessionWithQRSerializer},
)
class SessionRefreshQRView(APIView):
    """
    Regenerate the QR payload for an open session.
    Useful when the current QR nears its expiry.
    **Lecturer only.**
    """
    permission_classes = [IsLecturer]

    def get(self, request, pk):
        try:
            session = AttendanceSession.objects.select_related("course").get(
                pk=pk, created_by=request.user
            )
        except AttendanceSession.DoesNotExist:
            return Response({"detail": "Session not found."}, status=status.HTTP_404_NOT_FOUND)

        if not session.is_open:
            return Response({"detail": "Session is not open."}, status=status.HTTP_400_BAD_REQUEST)

        # Extend expiry and regenerate QR
        from django.conf import settings as conf
        from datetime import timedelta
        validity = getattr(conf, "QR_CODE_VALIDITY_SECONDS", 900)
        session.expires_at = timezone.now() + timedelta(seconds=validity)
        session.save(update_fields=["expires_at"])

        out = SessionWithQRSerializer(session, context={"request": request})
        return Response(out.data)


# ===========================================================================
# 3. ONLINE QR SCAN (real-time)
# ===========================================================================
@extend_schema(
    tags=["Attendance"],
    request=OnlineScanSerializer,
    responses={201: AttendanceRecordSerializer},
)
class OnlineScanView(APIView):
    """
    Record attendance via a real-time QR scan (student is online).

    The server validates:
    1. Student role.
    2. Device UUID binding.
    3. Session is open.
    4. HMAC-SHA256 signature.
    5. QR code not expired.
    6. No duplicate for this session.
    """
    permission_classes = [IsStudent]

    def post(self, request):
        serializer = OnlineScanSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        record = serializer.save()
        out = AttendanceRecordSerializer(record, context={"request": request})
        return Response(
            {"message": "Attendance recorded.", "record": out.data},
            status=status.HTTP_201_CREATED,
        )


# ===========================================================================
# 4. BATCH SYNCHRONISATION
# ===========================================================================
@extend_schema(
    tags=["Sync"],
    request=SyncBatchSerializer,
    responses={200: SyncBatchResponseSerializer},
)
class SyncBatchView(APIView):
    """
    Accept a batch of offline-captured attendance records from a student device.

    Each record is independently re-validated server-side:
    - HMAC-SHA256 signature verification
    - Device UUID match
    - QR expiry + clock-skew tolerance
    - Duplicate detection (idempotent via idempotency_key)
    - Cross-device conflict detection

    The response includes counts of accepted, rejected, and duplicate records.
    Rejected records are logged in `IntegrityLog`; conflicts in `ConflictLog`.
    """
    permission_classes = [IsStudent]

    def post(self, request):
        serializer = SyncBatchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        device_uuid = data["device_uuid"]
        records = data["records"]

        # Device UUID consistency check
        if request.user.device_uuid and request.user.device_uuid != device_uuid:
            return Response(
                {"detail": "Sync device_uuid does not match registered device."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Create the batch record
        batch = SyncBatch.objects.create(
            submitted_by=request.user,
            device_uuid=device_uuid,
            total_records=len(records),
        )

        # Run the processing pipeline
        result = process_sync_batch(
            user=request.user,
            device_uuid=device_uuid,
            records=[dict(r) for r in records],
            batch=batch,
        )

        # Update batch summary
        batch.accepted_records = result["accepted"]
        batch.rejected_records = result["rejected"]
        batch.duplicate_records = result["duplicates"]
        batch.status = (
            SyncBatch.BatchStatus.COMPLETE
            if result["rejected"] == 0
            else SyncBatch.BatchStatus.PARTIAL
        )
        batch.save(update_fields=[
            "accepted_records", "rejected_records", "duplicate_records", "status"
        ])

        return Response({
            "batch_id": str(batch.id),
            "total_submitted": len(records),
            "accepted": result["accepted"],
            "rejected": result["rejected"],
            "duplicates": result["duplicates"],
            "conflicts_flagged": len(result["conflict_ids"]),
            "status": batch.status,
        })


@extend_schema(tags=["Sync"])
class SyncBatchListView(generics.ListAPIView):
    """List all sync batches for the authenticated student."""
    serializer_class = SyncBatchResponseSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_student:
            return SyncBatch.objects.filter(submitted_by=user)
        return SyncBatch.objects.all()


# ===========================================================================
# 5. REPORTS & ANALYTICS
# ===========================================================================
@extend_schema(tags=["Reports"])
class SessionAttendanceReportView(generics.RetrieveAPIView):
    """Full attendance report for a session, including all records."""
    serializer_class = SessionAttendanceReportSerializer
    permission_classes = [IsLecturerOrAdmin]
    queryset = AttendanceSession.objects.select_related("course").prefetch_related("records__student")


@extend_schema(
    tags=["Reports"],
    parameters=[
        OpenApiParameter("course_id", str, description="Filter by course UUID"),
        OpenApiParameter("session_id", str, description="Filter by session UUID"),
    ],
)
class AttendanceRecordListView(generics.ListAPIView):
    """
    List attendance records.
    Lecturers see records for their own sessions; students see their own records.
    """
    serializer_class = AttendanceRecordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = AttendanceRecord.objects.select_related("student", "session__course")

        if user.is_student:
            qs = qs.filter(student=user)
        elif user.is_lecturer:
            qs = qs.filter(session__created_by=user)

        course_id = self.request.query_params.get("course_id")
        session_id = self.request.query_params.get("session_id")
        if course_id:
            qs = qs.filter(session__course_id=course_id)
        if session_id:
            qs = qs.filter(session_id=session_id)
        return qs


@extend_schema(tags=["Reports"])
class CourseAttendanceSummaryView(APIView):
    """
    Returns a per-student attendance summary for a given course.
    Shows sessions attended vs total sessions.
    """
    permission_classes = [IsLecturerOrAdmin]

    def get(self, request, course_id):
        try:
            course = Course.objects.prefetch_related(
                "enrolled_students", "sessions"
            ).get(pk=course_id)
        except Course.DoesNotExist:
            return Response({"detail": "Course not found."}, status=status.HTTP_404_NOT_FOUND)

        total_sessions = course.sessions.filter(
            status=AttendanceSession.Status.CLOSED
        ).count()

        summary = []
        for student in course.enrolled_students.all():
            attended = AttendanceRecord.objects.filter(
                student=student, session__course=course
            ).count()
            summary.append({
                "student_id": str(student.id),
                "student_name": student.get_full_name(),
                "registration_number": student.registration_number,
                "sessions_attended": attended,
                "total_sessions": total_sessions,
                "attendance_rate": (
                    round(attended / total_sessions * 100, 1)
                    if total_sessions > 0 else 0.0
                ),
            })

        return Response({
            "course_id": str(course.id),
            "course_code": course.code,
            "course_title": course.title,
            "total_sessions": total_sessions,
            "student_summary": summary,
        })


# ===========================================================================
# 6. CONFLICT & INTEGRITY LOG MANAGEMENT
# ===========================================================================
@extend_schema(tags=["Reports"])
class ConflictLogListView(generics.ListAPIView):
    """List all unresolved device-conflict records (lecturer / admin)."""
    serializer_class = ConflictLogSerializer
    permission_classes = [IsLecturerOrAdmin]

    def get_queryset(self):
        user = self.request.user
        qs = ConflictLog.objects.select_related("session__course", "student")
        if user.is_lecturer:
            qs = qs.filter(session__created_by=user)
        return qs


@extend_schema(
    tags=["Reports"],
    request={"application/json": {"type": "object", "properties": {
        "resolution_note": {"type": "string"}
    }}},
    responses={200: OpenApiResponse(description="Conflict resolved.")},
)
class ConflictResolveView(APIView):
    """Mark a conflict as resolved (lecturer / admin)."""
    permission_classes = [IsLecturerOrAdmin]

    def post(self, request, pk):
        try:
            conflict = ConflictLog.objects.get(pk=pk)
        except ConflictLog.DoesNotExist:
            return Response({"detail": "Conflict not found."}, status=status.HTTP_404_NOT_FOUND)

        conflict.resolved = True
        conflict.resolved_by = request.user
        conflict.resolution_note = request.data.get("resolution_note", "")
        conflict.save(update_fields=["resolved", "resolved_by", "resolution_note"])
        return Response({"message": "Conflict resolved."})


@extend_schema(tags=["Reports"])
class IntegrityLogListView(generics.ListAPIView):
    """List integrity violation logs (admin only)."""
    serializer_class = IntegrityLogSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        return IntegrityLog.objects.select_related("session", "student").all()


# ===========================================================================
# 7. HEALTH CHECK
# ===========================================================================
@extend_schema(
    tags=["Admin"],
    responses={200: OpenApiResponse(description="System health status.")},
)
class HealthCheckView(APIView):
    """Public health-check endpoint for deployment monitoring."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from django.db import connection
        try:
            connection.ensure_connection()
            db_ok = True
        except Exception:
            db_ok = False

        return Response({
            "status": "ok" if db_ok else "degraded",
            "database": "connected" if db_ok else "error",
            "system": "Smart Attendance System v1.0",
        })
