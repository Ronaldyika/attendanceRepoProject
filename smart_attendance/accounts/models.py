"""
Accounts Models
===============
Custom User model with role-based access and device UUID binding.
Device binding is the foundation of the fraud-prevention mechanism.
"""
import uuid
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models


class UserManager(BaseUserManager):
    """Custom manager supporting email-based authentication."""

    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("Email address is required.")
        email = self.normalize_email(email)
        extra_fields.setdefault("is_active", True)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", User.Role.ADMIN)
        return self.create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """
    Extended user model.

    Roles
    -----
    STUDENT  – can scan QR codes; attendance is recorded against their account
    LECTURER – creates courses and attendance sessions; generates QR codes
    ADMIN    – full system access

    Device Binding
    --------------
    device_uuid is captured at first login and stored here.  All subsequent
    QR scans are rejected if the submitting device_uuid differs from this value.
    This is the primary hardware-level fraud-prevention mechanism.
    """

    class Role(models.TextChoices):
        STUDENT = "student", "Student"
        LECTURER = "lecturer", "Lecturer"
        ADMIN = "admin", "Administrator"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    registration_number = models.CharField(
        max_length=50,
        unique=True,
        null=True,
        blank=True,
        help_text="Student/Staff registration number (e.g. UBa25EP188)",
    )
    role = models.CharField(max_length=10, choices=Role.choices, default=Role.STUDENT)

    # Device binding — set on first authenticated login from the mobile app
    device_uuid = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        db_index=True,
        help_text="Unique device identifier bound to this account at first login.",
    )
    device_bound_at = models.DateTimeField(null=True, blank=True)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["first_name", "last_name"]

    class Meta:
        verbose_name = "User"
        verbose_name_plural = "Users"
        ordering = ["last_name", "first_name"]

    def __str__(self):
        return f"{self.get_full_name()} <{self.email}> [{self.role}]"

    def get_full_name(self):
        return f"{self.first_name} {self.last_name}".strip()

    @property
    def is_lecturer(self):
        return self.role == self.Role.LECTURER

    @property
    def is_student(self):
        return self.role == self.Role.STUDENT

    @property
    def is_admin_user(self):
        return self.role == self.Role.ADMIN


class DeviceBindingLog(models.Model):
    """Audit trail for every device binding or binding-change event."""

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="device_logs")
    old_device_uuid = models.CharField(max_length=255, null=True, blank=True)
    new_device_uuid = models.CharField(max_length=255)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"DeviceBinding [{self.user.email}] at {self.created_at:%Y-%m-%d %H:%M}"
