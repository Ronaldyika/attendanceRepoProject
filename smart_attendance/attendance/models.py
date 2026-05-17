"""
Attendance Models
=================
Course → AttendanceSession → AttendanceRecord
Plus:  SyncBatch, ConflictLog, IntegrityLog
"""
import uuid
from django.conf import settings
from django.db import models


# ---------------------------------------------------------------------------
# Course
# ---------------------------------------------------------------------------
class Course(models.Model):
    """Academic course. A lecturer may own multiple courses."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    code = models.CharField(max_length=20, unique=True, help_text="e.g. CPE501")
    title = models.CharField(max_length=200)
    lecturer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="courses",
        limit_choices_to={"role": "lecturer"},
    )
    enrolled_students = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        related_name="enrolled_courses",
        blank=True,
        limit_choices_to={"role": "student"},
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["code"]

    def __str__(self):
        return f"{self.code} – {self.title}"


# ---------------------------------------------------------------------------
# Attendance Session
# ---------------------------------------------------------------------------
class AttendanceSession(models.Model):
    """
    A single attendance-taking session created by a lecturer.

    session_secret
        HMAC-SHA256 key, generated on session creation, transmitted to the
        Lecturer device only.  Never stored on student devices.

    qr_payload_base
        Pre-computed base string (session_id|course_code|expiry_unix) that
        the Lecturer device uses for QR generation.  The student device uses
        the same format to verify the HMAC signature locally.
    """

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        CLOSED = "closed", "Closed"
        EXPIRED = "expired", "Expired"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name="sessions")
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="created_sessions",
    )
    session_secret = models.CharField(
        max_length=128,
        help_text="HMAC-SHA256 secret key for this session (never exposed to students).",
    )
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN)
    started_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(help_text="Auto-set to started_at + QR_CODE_VALIDITY_SECONDS.")
    closed_at = models.DateTimeField(null=True, blank=True)
    venue = models.CharField(max_length=200, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ["-started_at"]

    def __str__(self):
        return f"Session [{self.course.code}] {self.started_at:%Y-%m-%d %H:%M} ({self.status})"

    @property
    def is_open(self):
        from django.utils import timezone
        return self.status == self.Status.OPEN and timezone.now() <= self.expires_at


# ---------------------------------------------------------------------------
# Attendance Record
# ---------------------------------------------------------------------------
class AttendanceRecord(models.Model):
    """
    A single student-attendance entry for a session.

    Unique constraint
        (student, session, device_uuid) – prevents duplicate records both
        locally (SQLite) and on the server after sync.

    pending_sync
        On the mobile client this flag is True until the record reaches the
        server.  On the server it is always False.

    sync_batch
        The SyncBatch this record arrived with (null for records created
        directly online).
    """

    class ScanSource(models.TextChoices):
        ONLINE = "online", "Online (real-time)"
        OFFLINE = "offline", "Offline (synced)"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="attendance_records",
    )
    session = models.ForeignKey(
        AttendanceSession,
        on_delete=models.CASCADE,
        related_name="records",
    )
    device_uuid = models.CharField(max_length=255, db_index=True)
    scan_source = models.CharField(
        max_length=10,
        choices=ScanSource.choices,
        default=ScanSource.ONLINE,
    )

    # Timestamps
    scanned_at = models.DateTimeField(help_text="Timestamp from the student's device at scan time.")
    synced_at = models.DateTimeField(null=True, blank=True, help_text="When this record reached the server.")

    # Idempotency key:  student_device_id|session_id|timestamp_unix_ms
    idempotency_key = models.CharField(max_length=512, unique=True, db_index=True)

    # HMAC signature from the QR payload – re-validated on server
    hmac_signature = models.CharField(max_length=128, blank=True)

    pending_sync = models.BooleanField(default=False)
    sync_batch = models.ForeignKey(
        "SyncBatch",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="records",
    )

    class Meta:
        unique_together = [("student", "session", "device_uuid")]
        ordering = ["-scanned_at"]

    def __str__(self):
        return f"{self.student.get_full_name()} @ {self.session} [{self.scan_source}]"


# ---------------------------------------------------------------------------
# Sync Batch
# ---------------------------------------------------------------------------
class SyncBatch(models.Model):
    """
    Represents one batch synchronisation event from a student device.
    Records in the batch are linked via AttendanceRecord.sync_batch.
    """

    class BatchStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        PARTIAL = "partial", "Partial (some records rejected)"
        COMPLETE = "complete", "Complete"
        FAILED = "failed", "Failed"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    submitted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sync_batches",
    )
    device_uuid = models.CharField(max_length=255)
    submitted_at = models.DateTimeField(auto_now_add=True)
    total_records = models.PositiveIntegerField(default=0)
    accepted_records = models.PositiveIntegerField(default=0)
    rejected_records = models.PositiveIntegerField(default=0)
    duplicate_records = models.PositiveIntegerField(default=0)
    status = models.CharField(
        max_length=10,
        choices=BatchStatus.choices,
        default=BatchStatus.PENDING,
    )
    error_detail = models.TextField(blank=True)

    class Meta:
        ordering = ["-submitted_at"]

    def __str__(self):
        return f"SyncBatch [{self.submitted_by.email}] {self.submitted_at:%Y-%m-%d %H:%M} ({self.status})"


# ---------------------------------------------------------------------------
# Conflict Log
# ---------------------------------------------------------------------------
class ConflictLog(models.Model):
    """
    Records a conflict detected during synchronisation — same session_id
    but different device_uuid for the same student.  Requires manual review.
    """
    session = models.ForeignKey(AttendanceSession, on_delete=models.CASCADE, related_name="conflicts")
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="conflicts",
    )
    registered_device_uuid = models.CharField(max_length=255)
    submitting_device_uuid = models.CharField(max_length=255)
    idempotency_key = models.CharField(max_length=512)
    raw_payload = models.JSONField(default=dict)
    sync_batch = models.ForeignKey(SyncBatch, on_delete=models.CASCADE, related_name="conflicts")
    created_at = models.DateTimeField(auto_now_add=True)
    resolved = models.BooleanField(default=False)
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="resolved_conflicts",
    )
    resolution_note = models.TextField(blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Conflict [{self.student.email}] session {self.session_id}"


# ---------------------------------------------------------------------------
# Integrity Log
# ---------------------------------------------------------------------------
class IntegrityLog(models.Model):
    """
    Records any record flagged as a potential integrity violation during
    server-side re-validation (clock skew, expired QR, bad HMAC, etc.).
    """

    class ViolationType(models.TextChoices):
        CLOCK_SKEW = "clock_skew", "Clock Skew Exceeded"
        EXPIRED_QR = "expired_qr", "QR Code Expired"
        BAD_HMAC = "bad_hmac", "Invalid HMAC Signature"
        DEVICE_MISMATCH = "device_mismatch", "Device UUID Mismatch"
        DUPLICATE = "duplicate", "Duplicate Record"
        OTHER = "other", "Other"

    session = models.ForeignKey(
        AttendanceSession,
        on_delete=models.CASCADE,
        related_name="integrity_logs",
        null=True,
        blank=True,
    )
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="integrity_logs",
        null=True,
        blank=True,
    )
    violation_type = models.CharField(max_length=20, choices=ViolationType.choices)
    detail = models.TextField()
    raw_payload = models.JSONField(default=dict)
    sync_batch = models.ForeignKey(
        SyncBatch,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="integrity_logs",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"IntegrityLog [{self.violation_type}] {self.created_at:%Y-%m-%d %H:%M}"
