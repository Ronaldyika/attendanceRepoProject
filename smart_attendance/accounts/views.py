"""
Accounts Views
==============
Registration, profile management, device binding, and admin user operations.
"""
from django.utils import timezone
from drf_spectacular.utils import OpenApiExample, OpenApiResponse, extend_schema, extend_schema_view
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .models import DeviceBindingLog, User
from .permissions import IsAdminUser, IsLecturerOrAdmin
from .serializers import (
    CustomTokenObtainPairSerializer,
    DeviceRebindSerializer,
    UserProfileSerializer,
    UserRegistrationSerializer,
)


# ---------------------------------------------------------------------------
# Auth – Login
# ---------------------------------------------------------------------------
@extend_schema(tags=["Auth"])
class LoginView(TokenObtainPairView):
    """
    Obtain a JWT access + refresh token pair.

    Supply `device_uuid` (from Flutter's `device_info_plus`) to trigger
    device binding on first login.  Subsequent logins with a different
    device_uuid are **rejected** as a fraud-prevention measure.
    """
    serializer_class = CustomTokenObtainPairSerializer


# ---------------------------------------------------------------------------
# Auth – Refresh
# ---------------------------------------------------------------------------
@extend_schema(tags=["Auth"])
class TokenRefreshAPIView(TokenRefreshView):
    """Refresh an expired access token using a valid refresh token."""


# ---------------------------------------------------------------------------
# Auth – Register
# ---------------------------------------------------------------------------
@extend_schema(
    tags=["Auth"],
    request=UserRegistrationSerializer,
    responses={201: UserProfileSerializer},
    examples=[
        OpenApiExample(
            "Student registration",
            value={
                "email": "student@nahpi.cm",
                "first_name": "Ronald",
                "last_name": "Buhnyuy",
                "registration_number": "UBa25EP188",
                "role": "student",
                "password": "SecurePass123",
                "password_confirm": "SecurePass123",
            },
            request_only=True,
        )
    ],
)
class RegisterView(generics.CreateAPIView):
    """Register a new user (student or lecturer)."""
    queryset = User.objects.all()
    serializer_class = UserRegistrationSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        profile = UserProfileSerializer(user)
        return Response(
            {"message": "Registration successful.", "user": profile.data},
            status=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# Auth – Profile (self)
# ---------------------------------------------------------------------------
@extend_schema(tags=["Auth"])
class ProfileView(generics.RetrieveUpdateAPIView):
    """Retrieve or update the authenticated user's profile."""
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


# ---------------------------------------------------------------------------
# Auth – Logout (blacklist refresh token)
# ---------------------------------------------------------------------------
@extend_schema(
    tags=["Auth"],
    request={"application/json": {"type": "object", "properties": {"refresh": {"type": "string"}}}},
    responses={205: OpenApiResponse(description="Logged out successfully.")},
)
class LogoutView(APIView):
    """
    Blacklist the supplied refresh token, effectively logging the user out.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        from rest_framework_simplejwt.tokens import RefreshToken
        from rest_framework_simplejwt.exceptions import TokenError

        try:
            token = RefreshToken(request.data.get("refresh"))
            token.blacklist()
        except TokenError:
            return Response({"detail": "Token is invalid or expired."}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"detail": "Logout successful."}, status=status.HTTP_205_RESET_CONTENT)


# ---------------------------------------------------------------------------
# Admin – List all users
# ---------------------------------------------------------------------------
@extend_schema(tags=["Admin"])
class UserListView(generics.ListAPIView):
    """List all registered users (admin / lecturer only)."""
    serializer_class = UserProfileSerializer
    permission_classes = [IsLecturerOrAdmin]

    def get_queryset(self):
        qs = User.objects.all()
        role = self.request.query_params.get("role")
        if role:
            qs = qs.filter(role=role)
        return qs


# ---------------------------------------------------------------------------
# Admin – Device rebind
# ---------------------------------------------------------------------------
@extend_schema(
    tags=["Admin"],
    request=DeviceRebindSerializer,
    responses={200: OpenApiResponse(description="Device rebound successfully.")},
)
class DeviceRebindView(APIView):
    """
    Rebind a user's account to a new device UUID.

    **Admin only.**  Use this when a student loses or replaces their device.
    An audit entry is written to `DeviceBindingLog`.
    """
    permission_classes = [IsAdminUser]

    def post(self, request):
        serializer = DeviceRebindSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            user = User.objects.get(id=data["user_id"])
        except User.DoesNotExist:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        old_uuid = user.device_uuid
        user.device_uuid = data["new_device_uuid"]
        user.device_bound_at = timezone.now()
        user.save(update_fields=["device_uuid", "device_bound_at"])

        DeviceBindingLog.objects.create(
            user=user,
            old_device_uuid=old_uuid,
            new_device_uuid=data["new_device_uuid"],
            ip_address=request.META.get("REMOTE_ADDR"),
            user_agent=request.META.get("HTTP_USER_AGENT", ""),
        )

        return Response(
            {
                "message": f"Device rebound for {user.get_full_name()}.",
                "user_id": str(user.id),
                "new_device_uuid": data["new_device_uuid"],
            }
        )


# ---------------------------------------------------------------------------
# Admin – Device binding audit log
# ---------------------------------------------------------------------------
@extend_schema(tags=["Admin"])
class DeviceBindingLogListView(generics.ListAPIView):
    """Retrieve the full device-binding audit log (admin only)."""
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        return DeviceBindingLog.objects.select_related("user").all()

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        data = [
            {
                "id": log.id,
                "user": log.user.get_full_name(),
                "user_id": str(log.user.id),
                "old_device_uuid": log.old_device_uuid,
                "new_device_uuid": log.new_device_uuid,
                "ip_address": log.ip_address,
                "created_at": log.created_at.isoformat(),
            }
            for log in qs
        ]
        return Response(data)
