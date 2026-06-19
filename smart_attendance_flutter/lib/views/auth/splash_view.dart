import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';

import '../shared/widgets/floating_orbs_background.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 1800), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    await auth.init();
    if (!mounted) return;

    if (auth.isAuthenticated && auth.user != null) {
      final route = auth.user!.isLecturer
          ? AppConstants.routeLecturerHome
          : AppConstants.routeStudentHome;
      Navigator.pushReplacementNamed(context, route);
    } else {
      Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const FloatingOrbsBackground(
              colors: [Colors.white, Color(0xFF80CBC4), Color(0xFFB2DFDB)],
            ),
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.qr_code_scanner,
                              color: Colors.white, size: 52),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Smart Attendance',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Text('Offline-Capable · HMAC-SHA256 Secure',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 8),
                      Text('NAHPI · University of Bamenda',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11)),
                      const SizedBox(height: 60),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.7),
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Loading...',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
