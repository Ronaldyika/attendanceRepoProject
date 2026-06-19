// ============================================================
// Smart Attendance System – Flutter Application
// ============================================================
// Design and Implementation of an Offline-Capable Smart
// Attendance System Using QR Codes and Secure Synchronisation
//
// Author  : Buhnyuy Ronald Yika (UBa25EP188)
// Degree  : Master of Engineering – Computer Engineering
// School  : NAHPI, University of Bamenda, Cameroon
// Year    : 2025
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/attendance_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/course_controller.dart';
import 'controllers/session_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/utils/connectivity_service.dart';
import 'views/auth/login_view.dart';
import 'views/auth/register_view.dart';
import 'views/auth/splash_view.dart';
import 'views/lecturer/create_session_view.dart';
import 'views/lecturer/lecturer_home_view.dart';
import 'views/lecturer/reports_view.dart';
import 'views/shared/animations/fade_slide_route.dart';
import 'views/student/student_home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialise core services
  ApiClient().init();
  await ConnectivityService().init();

  runApp(const SmartAttendanceApp());
}

class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => SessionController()),
        ChangeNotifierProvider(create: (_) => CourseController()),
        ChangeNotifierProvider(create: (_) => AttendanceController()),
      ],
      child: MaterialApp(
        title: 'Smart Attendance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppConstants.routeSplash,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppConstants.routeCreateSession:
              return FadeSlideRoute(page: const CreateSessionView());
            case AppConstants.routeReports:
              return FadeSlideRoute(page: const ReportsView());
            default:
              return null;
          }
        },
        routes: {
          AppConstants.routeSplash: (_) => const SplashView(),
          AppConstants.routeLogin: (_) => const LoginView(),
          AppConstants.routeRegister: (_) => const RegisterView(),
          AppConstants.routeLecturerHome: (_) => const LecturerHomeView(),
          AppConstants.routeStudentHome: (_) => const StudentHomeView(),
          AppConstants.routeCreateSession: (_) => const CreateSessionView(),
        },
      ),
    );
  }
}
