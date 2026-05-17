from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, DeviceBindingLog


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ["email", "get_full_name", "role", "device_uuid", "is_active", "date_joined"]
    list_filter = ["role", "is_active", "is_staff"]
    search_fields = ["email", "first_name", "last_name", "registration_number"]
    ordering = ["email"]
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Personal Info", {"fields": ("first_name", "last_name", "registration_number")}),
        ("Role & Device", {"fields": ("role", "device_uuid", "device_bound_at")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Dates", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("email", "first_name", "last_name", "role", "password1", "password2"),
        }),
    )
    readonly_fields = ["date_joined", "device_bound_at"]


@admin.register(DeviceBindingLog)
class DeviceBindingLogAdmin(admin.ModelAdmin):
    list_display = ["user", "new_device_uuid", "ip_address", "created_at"]
    list_filter = ["created_at"]
    search_fields = ["user__email", "new_device_uuid"]
    readonly_fields = ["created_at"]
