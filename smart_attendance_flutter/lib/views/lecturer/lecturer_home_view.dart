import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/connectivity_service.dart';
import '../shared/widgets/connectivity_banner.dart';
import '../shared/widgets/stats_card.dart';
import 'session_list_view.dart';
import 'courses_view.dart';
import 'profile_view.dart';

class LecturerHomeView extends StatefulWidget {
  const LecturerHomeView({super.key});

  @override
  State<LecturerHomeView> createState() => _LecturerHomeViewState();
}

class _LecturerHomeViewState extends State<LecturerHomeView> {
  int _selectedIndex = 0;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseController>().loadCourses();
      context.read<SessionController>().loadSessions();
    });
    ConnectivityService().onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    ConnectivityService().checkConnection().then((v) => setState(() => _isOnline = v));
  }

  final _pages = const [
    _LecturerDashboard(),
    SessionListView(),
    LecturerCoursesView(),
    LecturerProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          ConnectivityBanner(isOnline: _isOnline),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_outlined), activeIcon: Icon(Icons.qr_code_2), label: 'Sessions'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'Courses'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _LecturerDashboard extends StatelessWidget {
  const _LecturerDashboard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final sessions = context.watch<SessionController>();
    final courses = context.watch<CourseController>();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 160,
          floating: false,
          pinned: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Hello, ${auth.user?.firstName ?? ''}! 👋',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Manage your attendance sessions',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 13)),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Stats grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  StatsCard(
                    title: 'Total Courses',
                    value: '${courses.courses.length}',
                    icon: Icons.menu_book,
                    color: AppTheme.primary,
                  ),
                  StatsCard(
                    title: 'Active Sessions',
                    value: '${sessions.openSessions.length}',
                    icon: Icons.qr_code_2,
                    color: AppTheme.accent,
                  ),
                  StatsCard(
                    title: 'Total Sessions',
                    value: '${sessions.sessions.length}',
                    icon: Icons.history,
                    color: AppTheme.warning,
                  ),
                  StatsCard(
                    title: 'Students Reached',
                    value: sessions.sessions
                        .fold<int>(0, (s, e) => s + e.attendanceCount)
                        .toString(),
                    icon: Icons.people,
                    color: AppTheme.success,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Quick actions
              const Text('Quick Actions',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.add_circle_outline,
                      label: 'New Session',
                      color: AppTheme.primary,
                      onTap: () => Navigator.pushNamed(
                          context, AppConstants.routeCreateSession),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.bar_chart,
                      label: 'Reports',
                      color: AppTheme.accent,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Recent sessions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Sessions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sessions.sessions.isEmpty)
                _EmptyState(
                  icon: Icons.qr_code_2_outlined,
                  message: 'No sessions yet.\nTap + to create one.',
                )
              else
                ...sessions.sessions.take(3).map((s) => _SessionTile(session: s)),
            ]),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionModel session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: session.isOpen
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              session.isOpen ? Icons.radio_button_on : Icons.check_circle,
              color: session.isOpen ? AppTheme.success : AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.courseCode,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                Text(session.venue?.isNotEmpty == true ? session.venue! : 'No venue',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${session.attendanceCount} students',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: session.isOpen
                      ? AppTheme.success.withOpacity(0.1)
                      : AppTheme.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.status.toUpperCase(),
                  style: TextStyle(
                    color: session.isOpen
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 56, color: AppTheme.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
