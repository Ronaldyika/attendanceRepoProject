"""Attendance URL Configuration"""
from django.urls import path
from .views import (
    CourseListCreateView, CourseDetailView, CourseEnrolmentView,
    SessionListCreateView, SessionDetailView, SessionCloseView, SessionRefreshQRView,
    OnlineScanView,
    SyncBatchView, SyncBatchListView,
    SessionAttendanceReportView, AttendanceRecordListView, CourseAttendanceSummaryView,
    ConflictLogListView, ConflictResolveView, IntegrityLogListView,
    HealthCheckView,
)

app_name = "attendance"

urlpatterns = [
    # Health
    path("health/", HealthCheckView.as_view(), name="health"),

    # Courses
    path("courses/", CourseListCreateView.as_view(), name="course-list"),
    path("courses/<uuid:pk>/", CourseDetailView.as_view(), name="course-detail"),
    path("courses/<uuid:pk>/enrol/", CourseEnrolmentView.as_view(), name="course-enrol"),

    # Sessions
    path("sessions/", SessionListCreateView.as_view(), name="session-list"),
    path("sessions/<uuid:pk>/", SessionDetailView.as_view(), name="session-detail"),
    path("sessions/<uuid:pk>/close/", SessionCloseView.as_view(), name="session-close"),
    path("sessions/<uuid:pk>/qr/", SessionRefreshQRView.as_view(), name="session-qr"),

    # Attendance
    path("attendance/scan/", OnlineScanView.as_view(), name="online-scan"),
    path("attendance/records/", AttendanceRecordListView.as_view(), name="record-list"),

    # Sync
    path("sync/", SyncBatchView.as_view(), name="sync-batch"),
    path("sync/history/", SyncBatchListView.as_view(), name="sync-history"),

    # Reports
    path("reports/sessions/<uuid:pk>/", SessionAttendanceReportView.as_view(), name="session-report"),
    path("reports/courses/<uuid:course_id>/", CourseAttendanceSummaryView.as_view(), name="course-summary"),

    # Logs
    path("logs/conflicts/", ConflictLogListView.as_view(), name="conflict-list"),
    path("logs/conflicts/<int:pk>/resolve/", ConflictResolveView.as_view(), name="conflict-resolve"),
    path("logs/integrity/", IntegrityLogListView.as_view(), name="integrity-list"),
]
