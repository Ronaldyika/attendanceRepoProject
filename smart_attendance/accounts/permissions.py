"""
Custom DRF Permission Classes
"""
from rest_framework.permissions import BasePermission


class IsLecturer(BasePermission):
    """Allows access only to users with the LECTURER role."""
    message = "Only lecturers may perform this action."

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_lecturer)


class IsStudent(BasePermission):
    """Allows access only to users with the STUDENT role."""
    message = "Only students may perform this action."

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_student)


class IsLecturerOrAdmin(BasePermission):
    """Allows access to lecturers and administrators."""
    message = "Only lecturers or administrators may perform this action."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and (request.user.is_lecturer or request.user.is_admin_user or request.user.is_staff)
        )


class IsAdminUser(BasePermission):
    """Allows access only to administrator-role users."""
    message = "Only administrators may perform this action."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and (request.user.is_admin_user or request.user.is_staff)
        )
