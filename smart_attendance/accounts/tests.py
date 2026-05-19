"""
Accounts API tests – auth endpoints and admin operations.
"""
import uuid

from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User


def create_user(role, email=None, device_uuid=None, **extra):
    email = email or f"{role}_{uuid.uuid4().hex[:6]}@test.cm"
    user = User.objects.create_user(
        email=email,
        password="TestPass123",
        first_name="Test",
        last_name=role.capitalize(),
        role=role,
        **extra,
    )
    if device_uuid:
        user.device_uuid = device_uuid
        user.save(update_fields=["device_uuid"])
    return user


def auth_client(user):
    client = APIClient()
    refresh = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {str(refresh.access_token)}")
    return client, refresh


class RegistrationTest(TestCase):
    def test_valid_registration(self):
        r = APIClient().post(reverse("accounts:register"), {
            "email": "newstudent@test.cm",
            "first_name": "John",
            "last_name": "Doe",
            "registration_number": "UBa25EP001",
            "role": "student",
            "password": "TestPass123",
            "password_confirm": "TestPass123",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_201_CREATED)
        self.assertIn("user", r.data)

    def test_invalid_email_returns_400_not_500(self):
        r = APIClient().post(reverse("accounts:register"), {
            "email": "bad@@email.com",
            "first_name": "A",
            "last_name": "B",
            "registration_number": "UBa25EP002",
            "role": "student",
            "password": "TestPass123",
            "password_confirm": "TestPass123",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("email", r.data)

    def test_missing_password_confirm_returns_400(self):
        r = APIClient().post(reverse("accounts:register"), {
            "email": f"missing_{uuid.uuid4().hex[:6]}@test.cm",
            "first_name": "A",
            "last_name": "B",
            "registration_number": "UBa25EP003",
            "role": "student",
            "password": "TestPass123",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)

    def test_password_mismatch_returns_400(self):
        r = APIClient().post(reverse("accounts:register"), {
            "email": f"mismatch_{uuid.uuid4().hex[:6]}@test.cm",
            "first_name": "A",
            "last_name": "B",
            "registration_number": "UBa25EP004",
            "role": "student",
            "password": "TestPass123",
            "password_confirm": "OtherPass123",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)


class AuthFlowTest(TestCase):
    def test_login_returns_tokens(self):
        user = create_user("student")
        r = APIClient().post(reverse("accounts:login"), {
            "email": user.email,
            "password": "TestPass123",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertIn("access", r.data)

    def test_device_binding_on_first_login(self):
        user = create_user("student")
        device = "DEVICE-ABC-123"
        r = APIClient().post(reverse("accounts:login"), {
            "email": user.email,
            "password": "TestPass123",
            "device_uuid": device,
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertEqual(user.device_uuid, device)

    def test_different_device_login_rejected(self):
        user = create_user("student", device_uuid="DEVICE-ORIGINAL")
        r = APIClient().post(reverse("accounts:login"), {
            "email": user.email,
            "password": "TestPass123",
            "device_uuid": "DEVICE-FAKE",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)

    def test_token_refresh(self):
        user = create_user("student")
        login = APIClient().post(reverse("accounts:login"), {
            "email": user.email,
            "password": "TestPass123",
        }, format="json")
        r = APIClient().post(reverse("accounts:token-refresh"), {
            "refresh": login.data["refresh"],
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertIn("access", r.data)

    def test_logout_requires_refresh_token(self):
        user = create_user("student")
        client, _ = auth_client(user)
        r = client.post(reverse("accounts:logout"), {}, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)

    def test_logout_blacklists_token(self):
        user = create_user("student")
        client, refresh = auth_client(user)
        r = client.post(reverse("accounts:logout"), {"refresh": str(refresh)}, format="json")
        self.assertEqual(r.status_code, status.HTTP_205_RESET_CONTENT)

    def test_profile_get_and_patch(self):
        user = create_user("student")
        client, _ = auth_client(user)
        r = client.get(reverse("accounts:profile"))
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        r = client.patch(reverse("accounts:profile"), {"first_name": "Updated"}, format="json")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertEqual(user.first_name, "Updated")


class AdminEndpointsTest(TestCase):
    def setUp(self):
        self.admin = create_user("admin", is_staff=True)
        self.lecturer = create_user("lecturer")
        self.student = create_user("student", device_uuid="DEV-001")
        self.ac = auth_client(self.admin)[0]
        self.lc = auth_client(self.lecturer)[0]

    def test_user_list_as_admin(self):
        r = self.ac.get(reverse("accounts:user-list"))
        self.assertEqual(r.status_code, status.HTTP_200_OK)

    def test_user_list_as_lecturer(self):
        r = self.lc.get(reverse("accounts:user-list"))
        self.assertEqual(r.status_code, status.HTTP_200_OK)

    def test_device_logs_admin_only(self):
        r = self.ac.get(reverse("accounts:device-logs"))
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        r = self.lc.get(reverse("accounts:device-logs"))
        self.assertEqual(r.status_code, status.HTTP_403_FORBIDDEN)

    def test_device_rebind(self):
        r = self.ac.post(reverse("accounts:device-rebind"), {
            "user_id": str(self.student.id),
            "new_device_uuid": "DEV-NEW-999",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.student.refresh_from_db()
        self.assertEqual(self.student.device_uuid, "DEV-NEW-999")

    def test_device_rebind_invalid_user_id(self):
        r = self.ac.post(reverse("accounts:device-rebind"), {
            "user_id": "not-a-uuid",
            "new_device_uuid": "DEV-NEW",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)

    def test_device_rebind_missing_user(self):
        r = self.ac.post(reverse("accounts:device-rebind"), {
            "user_id": "00000000-0000-0000-0000-000000000001",
            "new_device_uuid": "DEV-NEW",
        }, format="json")
        self.assertEqual(r.status_code, status.HTTP_404_NOT_FOUND)
