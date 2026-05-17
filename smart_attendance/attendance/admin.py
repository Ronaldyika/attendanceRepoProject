"""Django admin registration for attendance models."""
from django.contrib import admin
from .models import (
    AttendanceRecord, AttendanceSession, ConflictLog,
    Course, IntegrityLog, SyncBatch,
)


@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    list_display = ["code", "title", "lecturer", "is_active", "created_at"]
    search_fields = ["code", "title"]
    list_filter = ["is_active"]


@admin.register(AttendanceSession)
class SessionAdmin(admin.ModelAdmin):
    list_display = ["__str__", "status", "started_at", "expires_at"]
    list_filter = ["status"]
    search_fields = ["course__code"]
    readonly_fields = ["session_secret", "started_at", "expires_at"]


@admin.register(AttendanceRecord)
class AttendanceRecordAdmin(admin.ModelAdmin):
    list_display = ["student", "session", "scan_source", "scanned_at", "synced_at"]
    list_filter = ["scan_source"]
    search_fields = ["student__email", "session__course__code"]


@admin.register(SyncBatch)
class SyncBatchAdmin(admin.ModelAdmin):
    list_display = [
        "submitted_by", "submitted_at", "total_records",
        "accepted_records", "rejected_records", "status",
    ]
    list_filter = ["status"]


@admin.register(ConflictLog)
class ConflictLogAdmin(admin.ModelAdmin):
    list_display = ["student", "session", "resolved", "created_at"]
    list_filter = ["resolved"]


@admin.register(IntegrityLog)
class IntegrityLogAdmin(admin.ModelAdmin):
    list_display = ["violation_type", "student", "session", "created_at"]
    list_filter = ["violation_type"]
