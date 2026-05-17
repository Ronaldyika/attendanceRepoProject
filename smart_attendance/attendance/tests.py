"""
Test Suite – Smart Attendance System
=====================================
Covers: auth, device binding, course CRUD, session lifecycle,
        online scan validation, batch sync processor, fraud prevention.
"""
import time
import uuid
from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import User
from attendance.models import (
    AttendanceRecord, AttendanceSession, Course, SyncBatch,
)
from attendance.qr_utils import (
    compute_hmac, generate_qr_payload, generate_session_secret,
    verify_qr_payload,
)
from attendance.sync_processor import process_sync_batch


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def create_user(role, email=None, device_uuid=None):
    email = email or f"{role}_{uuid.uuid4().hex[:6]}@test.cm"
    user = User.objects.create_user(
        email=email, password="TestPass123",
        first_name="Test", last_name=role.capitalize(),
        role=role,
    )
    if device_uuid:
        user.device_uuid = device_uuid
        user.save()
    return user


def auth_client(user):
    client = APIClient()
    refresh = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {str(refresh.access_token)}")
    return client


# ---------------------------------------------------------------------------
# 1. QR Utility Unit Tests
# ---------------------------------------------------------------------------
class QRUtilsTest(TestCase):

    def test_hmac_deterministic(self):
        secret = "testsecret"
        base = "sess|CPE501|1700000000"
        self.assertEqual(compute_hmac(base, secret), compute_hmac(base, secret))

    def test_generate_and_verify_valid(self):
        secret = generate_session_secret()
        result = generate_qr_payload("sess-1", "CPE501", secret, validity_seconds=900)
        ok, reason = verify_qr_payload(result["payload"], secret)
        self.assertTrue(ok)
        self.assertEqual(reason, "ok")

    def test_tampered_payload_fails(self):
        secret = generate_session_secret()
        result = generate_qr_payload("sess-1", "CPE501", secret, validity_seconds=900)
        tampered = result["payload"].replace("CPE501", "CPE999")
        ok, reason = verify_qr_payload(tampered, secret)
        self.assertFalse(ok)
        self.assertEqual(reason, "invalid_hmac")

    def test_expired_payload_fails(self):
        secret = generate_session_secret()
        result = generate_qr_payload("sess-1", "CPE501", secret, validity_seconds=-10)
        ok, reason = verify_qr_payload(result["payload"], secret, clock_skew_tolerance=0)
        self.assertFalse(ok)
        self.assertEqual(reason, "expired")

    def test_wrong_secret_fails(self):
        secret = generate_session_secret()
        wrong  = generate_session_secret()
        result = generate_qr_payload("sess-1", "CPE501", secret, validity_seconds=900)
        ok, reason = verify_qr_payload(result["payload"], wrong)
        self.assertFalse(ok)
        self.assertEqual(reason, "invalid_hmac")


# ---------------------------------------------------------------------------
# 2. Auth & Device Binding Tests
# ---------------------------------------------------------------------------
class AuthTest(TestCase):

    def test_register_student(self):
        client = APIClient()
        r = client.post(reverse("accounts:register"), {
            "email": "newstudent@test.cm",
            "first_name": "John", "last_name": "Doe",
            "registration_number": "UBa25EP001",
            "role": "student",
            "password": "TestPass123",
            "password_confirm": "TestPass123",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_201_CREATED)
        self.assertIn("user", r.data)

    def test_login_returns_tokens(self):
        user = create_user("student")
        client = APIClient()
        r = client.post(reverse("accounts:login"), {
            "email": user.email, "password": "TestPass123",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertIn("access", r.data)
        self.assertIn("refresh", r.data)

    def test_device_binding_on_first_login(self):
        user = create_user("student")
        client = APIClient()
        device = "DEVICE-ABC-123"
        r = client.post(reverse("accounts:login"), {
            "email": user.email, "password": "TestPass123",
            "device_uuid": device,
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertEqual(user.device_uuid, device)

    def test_different_device_login_rejected(self):
        user = create_user("student", device_uuid="DEVICE-ORIGINAL")
        client = APIClient()
        r = client.post(reverse("accounts:login"), {
            "email": user.email, "password": "TestPass123",
            "device_uuid": "DEVICE-FAKE",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)

    def test_profile_view(self):
        user = create_user("student")
        client = auth_client(user)
        r = client.get(reverse("accounts:profile"))
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertEqual(r.data["email"], user.email)


# ---------------------------------------------------------------------------
# 3. Course Tests
# ---------------------------------------------------------------------------
class CourseTest(TestCase):

    def setUp(self):
        self.lecturer = create_user("lecturer")
        self.student = create_user("student", device_uuid="DEV-001")
        self.lc = auth_client(self.lecturer)
        self.sc = auth_client(self.student)

    def test_lecturer_creates_course(self):
        r = self.lc.post(reverse("attendance:course-list"), {
            "code": "CPE501", "title": "Advanced Networks",
            "lecturer": str(self.lecturer.id),
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r.data["code"], "CPE501")

    def test_student_cannot_create_course(self):
        r = self.sc.post(reverse("attendance:course-list"), {
            "code": "CPE502", "title": "OS Design",
            "lecturer": str(self.lecturer.id),
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_403_FORBIDDEN)

    def test_enrol_students(self):
        course = Course.objects.create(
            code="CPE503", title="Test Course", lecturer=self.lecturer
        )
        r = self.lc.post(
            reverse("attendance:course-enrol", kwargs={"pk": str(course.id)}),
            {"student_ids": [str(self.student.id)]},
            format="json",
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertIn(self.student, course.enrolled_students.all())


# ---------------------------------------------------------------------------
# 4. Session Lifecycle Tests
# ---------------------------------------------------------------------------
class SessionTest(TestCase):

    def setUp(self):
        self.lecturer = create_user("lecturer")
        self.student = create_user("student", device_uuid="DEV-001")
        self.lc = auth_client(self.lecturer)
        self.sc = auth_client(self.student)
        self.course = Course.objects.create(
            code="CPE501", title="Advanced Networks", lecturer=self.lecturer
        )
        self.course.enrolled_students.add(self.student)

    def test_create_session_returns_qr(self):
        r = self.lc.post(reverse("attendance:session-list"), {
            "course": str(self.course.id), "venue": "Room 101",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_201_CREATED)
        self.assertIn("qr_payload", r.data)
        self.assertIn("session_secret", r.data)

    def test_student_cannot_create_session(self):
        r = self.sc.post(reverse("attendance:session-list"), {
            "course": str(self.course.id),
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_403_FORBIDDEN)

    def test_close_session(self):
        session = self._open_session()
        r = self.lc.post(
            reverse("attendance:session-close", kwargs={"pk": str(session.id)})
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        session.refresh_from_db()
        self.assertEqual(session.status, AttendanceSession.Status.CLOSED)

    def _open_session(self):
        from datetime import timedelta
        from django.utils import timezone
        return AttendanceSession.objects.create(
            course=self.course,
            created_by=self.lecturer,
            session_secret=generate_session_secret(),
            expires_at=timezone.now() + timedelta(minutes=15),
            status=AttendanceSession.Status.OPEN,
        )


# ---------------------------------------------------------------------------
# 5. Online Scan Fraud-Prevention Tests
# ---------------------------------------------------------------------------
class OnlineScanTest(TestCase):

    def setUp(self):
        self.lecturer = create_user("lecturer")
        self.student = create_user("student", device_uuid="DEV-STUDENT-001")
        self.sc = auth_client(self.student)
        self.course = Course.objects.create(
            code="CPE501", title="Networks", lecturer=self.lecturer
        )
        self.course.enrolled_students.add(self.student)
        from datetime import timedelta
        from django.utils import timezone
        self.session = AttendanceSession.objects.create(
            course=self.course,
            created_by=self.lecturer,
            session_secret=generate_session_secret(),
            expires_at=timezone.now() + timedelta(minutes=15),
            status=AttendanceSession.Status.OPEN,
        )

    def _valid_payload(self):
        return generate_qr_payload(
            str(self.session.id), self.course.code,
            self.session.session_secret, validity_seconds=900
        )["payload"]

    def test_valid_scan_succeeds(self):
        from django.utils import timezone
        r = self.sc.post(reverse("attendance:online-scan"), {
            "session_id": str(self.session.id),
            "qr_payload": self._valid_payload(),
            "device_uuid": "DEV-STUDENT-001",
            "scanned_at": timezone.now().isoformat(),
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_201_CREATED)

    def test_wrong_device_rejected(self):
        from django.utils import timezone
        r = self.sc.post(reverse("attendance:online-scan"), {
            "session_id": str(self.session.id),
            "qr_payload": self._valid_payload(),
            "device_uuid": "FAKE-DEVICE-999",
            "scanned_at": timezone.now().isoformat(),
        }, format="json")
        self.assertIn(r.status_code, [400, 403])

    def test_tampered_qr_rejected(self):
        from django.utils import timezone
        tampered = self._valid_payload().replace(self.course.code, "FAKE")
        r = self.sc.post(reverse("attendance:online-scan"), {
            "session_id": str(self.session.id),
            "qr_payload": tampered,
            "device_uuid": "DEV-STUDENT-001",
            "scanned_at": timezone.now().isoformat(),
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)

    def test_duplicate_scan_rejected(self):
        from django.utils import timezone
        payload = {
            "session_id": str(self.session.id),
            "qr_payload": self._valid_payload(),
            "device_uuid": "DEV-STUDENT-001",
            "scanned_at": timezone.now().isoformat(),
        }
        r1 = self.sc.post(reverse("attendance:online-scan"), payload, format="json")
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        r2 = self.sc.post(reverse("attendance:online-scan"), payload, format="json")
        self.assertEqual(r2.status_code, status.HTTP_400_BAD_REQUEST)


# ---------------------------------------------------------------------------
# 6. Sync Batch Tests
# ---------------------------------------------------------------------------
class SyncBatchTest(TestCase):

    def setUp(self):
        self.lecturer = create_user("lecturer")
        self.student = create_user("student", device_uuid="DEV-SYNC-001")
        self.sc = auth_client(self.student)
        self.course = Course.objects.create(
            code="CPE501", title="Networks", lecturer=self.lecturer
        )
        from datetime import timedelta
        from django.utils import timezone
        self.session = AttendanceSession.objects.create(
            course=self.course,
            created_by=self.lecturer,
            session_secret=generate_session_secret(),
            expires_at=timezone.now() + timedelta(minutes=15),
            status=AttendanceSession.Status.OPEN,
        )

    def _make_record(self, device_uuid="DEV-SYNC-001"):
        from django.utils import timezone
        scanned_at = timezone.now()
        idem = f"{device_uuid}|{self.session.id}|{int(scanned_at.timestamp()*1000)}"
        payload = generate_qr_payload(
            str(self.session.id), self.course.code,
            self.session.session_secret, validity_seconds=900
        )
        return {
            "session_id": str(self.session.id),
            "device_uuid": device_uuid,
            "scanned_at": scanned_at.isoformat(),
            "idempotency_key": idem,
            "hmac_signature": payload["hmac"],
            "qr_payload": payload["payload"],
        }

    def test_valid_batch_accepted(self):
        r = self.sc.post(reverse("attendance:sync-batch"), {
            "device_uuid": "DEV-SYNC-001",
            "records": [self._make_record()],
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertEqual(r.data["accepted"], 1)
        self.assertEqual(r.data["rejected"], 0)

    def test_idempotent_sync(self):
        record = self._make_record()
        payload = {"device_uuid": "DEV-SYNC-001", "records": [record]}
        r1 = self.sc.post(reverse("attendance:sync-batch"), payload, format="json")
        r2 = self.sc.post(reverse("attendance:sync-batch"), payload, format="json")
        self.assertEqual(r2.status_code, status.HTTP_200_OK)
        self.assertEqual(r2.data["duplicates"], 1)
        self.assertEqual(r2.data["accepted"], 0)

    def test_wrong_device_batch_rejected(self):
        r = self.sc.post(reverse("attendance:sync-batch"), {
            "device_uuid": "WRONG-DEVICE",
            "records": [self._make_record("WRONG-DEVICE")],
        }, format="json")
        self.assertIn(r.status_code, [200, 403])
        if r.status_code == 200:
            self.assertEqual(r.data["rejected"], 1)


# ---------------------------------------------------------------------------
# 7. Health check
# ---------------------------------------------------------------------------
class HealthCheckTest(TestCase):
    def test_health_endpoint(self):
        client = APIClient()
        r = client.get(reverse("attendance:health"))
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertIn("status", r.data)
