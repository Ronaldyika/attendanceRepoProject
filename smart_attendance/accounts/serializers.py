"""
Accounts Serializers
====================
Handles registration, profile, device binding, and JWT customisation.
"""
from django.utils import timezone
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import DeviceBindingLog, User


# ---------------------------------------------------------------------------
# JWT customisation – embed user metadata in the token payload
# ---------------------------------------------------------------------------
class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Extends the default SimpleJWT serializer to:
    1. Embed role, full_name and device_uuid in the JWT payload.
    2. Perform device binding on first login.
    3. Reject login if the supplied device_uuid differs from the bound one.
    """

    device_uuid = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
        help_text="Hardware device UUID from the mobile client (device_info_plus).",
    )

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["role"] = user.role
        token["full_name"] = user.get_full_name()
        token["email"] = user.email
        token["device_uuid"] = user.device_uuid or ""
        return token

    def validate(self, attrs):
        device_uuid = attrs.pop("device_uuid", "").strip()
        data = super().validate(attrs)
        user = self.user

        if device_uuid:
            if user.device_uuid and user.device_uuid != device_uuid:
                raise serializers.ValidationError(
                    {
                        "device_uuid": (
                            "This account is already bound to a different device. "
                            "Contact your administrator to rebind."
                        )
                    }
                )
            if not user.device_uuid:
                # First binding – record it
                old = user.device_uuid
                user.device_uuid = device_uuid
                user.device_bound_at = timezone.now()
                user.save(update_fields=["device_uuid", "device_bound_at"])
                DeviceBindingLog.objects.create(
                    user=user,
                    old_device_uuid=old,
                    new_device_uuid=device_uuid,
                )

        data["user"] = {
            "id": str(user.id),
            "email": user.email,
            "full_name": user.get_full_name(),
            "role": user.role,
            "registration_number": user.registration_number,
            "device_uuid": user.device_uuid,
            "device_bound_at": (
                user.device_bound_at.isoformat() if user.device_bound_at else None
            ),
        }
        return data


# ---------------------------------------------------------------------------
# User registration
# ---------------------------------------------------------------------------
class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            "email",
            "first_name",
            "last_name",
            "registration_number",
            "role",
            "password",
            "password_confirm",
        ]

    def validate_email(self, value):
        return value.strip().lower()

    def validate(self, attrs):
        password_confirm = attrs.pop("password_confirm", None)
        if password_confirm is None:
            raise serializers.ValidationError({"password_confirm": "This field is required."})
        if attrs.get("password") != password_confirm:
            raise serializers.ValidationError({"password_confirm": "Passwords do not match."})
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------
class UserProfileSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "first_name",
            "last_name",
            "full_name",
            "registration_number",
            "role",
            "device_uuid",
            "device_bound_at",
            "date_joined",
            "updated_at",
        ]
        read_only_fields = ["id", "email", "device_uuid", "device_bound_at", "date_joined", "updated_at"]

    def get_full_name(self, obj):
        return obj.get_full_name()


# ---------------------------------------------------------------------------
# Device rebind (admin only)
# ---------------------------------------------------------------------------
class DeviceRebindSerializer(serializers.Serializer):
    user_id = serializers.UUIDField()
    new_device_uuid = serializers.CharField(max_length=255)
    reason = serializers.CharField(max_length=500, required=False, allow_blank=True)
