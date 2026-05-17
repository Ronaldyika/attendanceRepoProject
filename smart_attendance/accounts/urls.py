"""Accounts URL Configuration"""
from django.urls import path
from .views import (
    LoginView, TokenRefreshAPIView, RegisterView,
    ProfileView, LogoutView, UserListView,
    DeviceRebindView, DeviceBindingLogListView,
)

app_name = "accounts"

urlpatterns = [
    path("login/", LoginView.as_view(), name="login"),
    path("token/refresh/", TokenRefreshAPIView.as_view(), name="token-refresh"),
    path("register/", RegisterView.as_view(), name="register"),
    path("profile/", ProfileView.as_view(), name="profile"),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("users/", UserListView.as_view(), name="user-list"),
    path("admin/rebind-device/", DeviceRebindView.as_view(), name="device-rebind"),
    path("admin/device-logs/", DeviceBindingLogListView.as_view(), name="device-logs"),
]
