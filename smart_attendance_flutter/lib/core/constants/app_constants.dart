// ============================================================
// App Constants
// Author: Buhnyuy Ronald Yika (UBa25EP188)
// ============================================================

class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'https://qrscanner-5qk4.onrender.com/api/v1';
  static const String authBase = '$baseUrl/auth';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // QR
  /// QR validity/refresh interval (lecturer QR regenerates on this cadence).
  static const int qrValiditySeconds = 10;
  static const int clockSkewToleranceSeconds = 5;

  // Local DB
  static const String dbName = 'smart_attendance.db';
  static const int dbVersion = 1;

  // Secure storage keys
  static const String kAccessToken = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kDeviceUuid = 'device_uuid';
  static const String kUserData = 'user_data';

  // Sync
  static const int syncPendingAlertHours = 6;
  static const Duration syncRetryInterval = Duration(minutes: 2);

  // Route names
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeLecturerHome = '/lecturer/home';
  static const String routeStudentHome = '/student/home';
  static const String routeCreateSession = '/lecturer/create-session';
  static const String routeSessionDetail = '/lecturer/session-detail';
  static const String routeScanQR = '/student/scan';
  static const String routeAttendanceHistory = '/student/history';
  static const String routeProfile = '/profile';
  static const String routeCourses = '/courses';
  static const String routeReports = '/reports';
}
