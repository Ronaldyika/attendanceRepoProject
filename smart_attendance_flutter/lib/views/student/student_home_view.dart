import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/attendance_record_model.dart';
import 'package:provider/provider.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/course_controller.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/connectivity_service.dart';
import '../../core/utils/string_utils.dart';
import '../../services/session_service.dart';
import '../shared/widgets/connectivity_banner.dart';
import '../shared/widgets/animated_stats_card.dart';
import '../shared/widgets/staggered_fade_in.dart';
import 'scan_view.dart';
import 'attendance_history_view.dart';
import 'student_courses_view.dart';
import 'student_profile_view.dart';

class StudentHomeView extends StatefulWidget {
  const StudentHomeView({super.key});

  @override
  State<StudentHomeView> createState() => _StudentHomeViewState();
}

class _StudentHomeViewState extends State<StudentHomeView>
  with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPendingOnResume();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      final attCtrl = context.read<AttendanceController>();
      final user = auth.user;
      if (user == null) return;

      attCtrl.loadRecords(user.id);
      attCtrl.initSync(
        studentId: user.id,
        deviceUuid: auth.deviceUuid ?? '',
      );
      context.read<CourseController>().loadCourses();
      SessionService().prefetchOpenSessionsForStudent();
    });
    _connectivitySub = ConnectivityService().onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    ConnectivityService().checkConnection().then((v) {
      if (mounted) setState(() => _isOnline = v);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _syncPendingOnResume() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    final user = auth.user;
    if (user == null) return;
    final attendance = context.read<AttendanceController>();

    if (await ConnectivityService().checkConnection() && mounted) {
      await attendance.syncPending(
            studentId: user.id,
            deviceUuid: auth.deviceUuid ?? '',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _StudentDashboard(),
      const ScanView(),
      const AttendanceHistoryView(),
      const StudentCoursesView(),
      const StudentProfileView(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          ConnectivityBanner(isOnline: _isOnline),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: pages[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.qr_code_scanner_outlined),
                if (!_isOnline)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.history_outlined),
                if (context.watch<AttendanceController>().pendingCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: AppTheme.warning,
                          shape: BoxShape.circle),
                      child: Text(
                        '${context.watch<AttendanceController>().pendingCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            selectedIcon: const Icon(Icons.history),
            label: 'History',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Courses',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _StudentDashboard extends StatelessWidget {
  const _StudentDashboard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final attCtrl = context.watch<AttendanceController>();
    final courses = context.watch<CourseController>().courses;

    final total = attCtrl.records.length;
    final synced = attCtrl.records.where((r) => r.syncStatus == 'synced').length;
    final pending = attCtrl.pendingCount;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 170,
          floating: false,
          pinned: true,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Welcome back, ${auth.user?.firstName ?? ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.user?.registrationNumber ?? 'Track your attendance',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (pending > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _triggerSync(context, auth, attCtrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text('Sync ($pending)',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _OfflineHeroCard(
                pendingCount: pending,
                syncedCount: synced,
                totalCount: total,
                onSync: () => _triggerSync(context, auth, attCtrl),
                isSyncing: attCtrl.syncState == SyncState.syncing,
              ),
              const SizedBox(height: 16),

              if (pending > 0) ...[
                _SyncBanner(
                  pendingCount: pending,
                  onSync: () => _triggerSync(context, auth, attCtrl),
                  isSyncing: attCtrl.syncState == SyncState.syncing,
                ),
                const SizedBox(height: 16),
              ],

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  AnimatedStatsCard(
                    title: 'Total Scans',
                    value: total,
                    icon: Icons.qr_code_2,
                    color: AppTheme.accent,
                  ),
                  AnimatedStatsCard(
                    title: 'Synced',
                    value: synced,
                    icon: Icons.cloud_done,
                    color: AppTheme.success,
                  ),
                  AnimatedStatsCard(
                    title: 'Pending Sync',
                    value: pending,
                    icon: Icons.cloud_upload_outlined,
                    color: pending > 0 ? AppTheme.warning : AppTheme.textSecondary,
                    subtitle: pending > 0 ? 'Action needed' : null,
                  ),
                  AnimatedStatsCard(
                    title: 'Courses',
                    value: courses.length,
                    icon: Icons.menu_book,
                    color: AppTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent attendance
              const Text('Recent Attendance',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              if (attCtrl.records.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.qr_code_2_outlined,
                            size: 56,
                            color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          'No attendance records yet.\nScan a QR code to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...attCtrl.records.take(5).toList().asMap().entries.map(
                      (e) => StaggeredFadeIn(
                        index: e.key,
                        child: _RecentRecordTile(record: e.value),
                      ),
                    ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _triggerSync(BuildContext context, AuthController auth,
      AttendanceController attCtrl) async {
    final result = await attCtrl.syncPending(
      studentId: auth.user!.id,
      deviceUuid: auth.deviceUuid ?? '',
    );
    if (context.mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sync complete: ${result['accepted'] ?? 0} accepted, '
              '${result['duplicates'] ?? 0} duplicates, '
              '${result['rejected'] ?? 0} rejected.'),
          backgroundColor: (result['rejected'] ?? 0) > 0
              ? AppTheme.warning
              : AppTheme.success,
        ),
      );
    } else if (context.mounted && attCtrl.syncError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(attCtrl.syncError!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

class _OfflineHeroCard extends StatelessWidget {
  final int pendingCount;
  final int syncedCount;
  final int totalCount;
  final VoidCallback onSync;
  final bool isSyncing;

  const _OfflineHeroCard({
    required this.pendingCount,
    required this.syncedCount,
    required this.totalCount,
    required this.onSync,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    final syncRatio = totalCount == 0 ? 0.0 : syncedCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_sync_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offline attendance is live',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount record${pendingCount > 1 ? 's' : ''} waiting to sync'
                          : 'Every scan is verified locally before it reaches the server.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: syncRatio.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: 'HMAC-SHA256', dark: true),
              _InfoPill(label: 'Device-bound', dark: true),
              _InfoPill(label: 'Auto-sync', dark: true),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: pendingCount > 0 ? onSync : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    )
                  : const Icon(Icons.sync_outlined, size: 18),
              label: Text(
                pendingCount > 0
                    ? (isSyncing ? 'Syncing…' : 'Sync now')
                    : 'No pending sync',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final bool dark;

  const _InfoPill({required this.label, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.2) : AppTheme.divider),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.white : AppTheme.textPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onSync;
  final bool isSyncing;

  const _SyncBanner({
    required this.pendingCount,
    required this.onSync,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined,
              color: AppTheme.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$pendingCount record${pendingCount > 1 ? 's' : ''} waiting to sync',
              style: const TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: isSyncing ? null : onSync,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Sync Now',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRecordTile extends StatelessWidget {
  final AttendanceRecordModel record;
  const _RecentRecordTile({required this.record});

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: record.syncStatus == 'rejected'
                  ? AppTheme.error.withValues(alpha: 0.1)
                  : record.pendingSync
                    ? AppTheme.warning.withValues(alpha: 0.1)
                    : AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
                record.syncStatus == 'rejected'
                  ? Icons.error_outline
                  : record.pendingSync
                    ? Icons.cloud_upload_outlined
                    : Icons.check_circle_outline,
                color: record.syncStatus == 'rejected'
                  ? AppTheme.error
                  : record.pendingSync
                    ? AppTheme.warning
                    : AppTheme.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.sessionId.truncate(8).toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary)),
                Text(
                    record.syncStatus == 'rejected'
                      ? 'Rejected by server'
                      : record.pendingSync
                        ? 'Pending sync'
                        : 'Synced',
                    style: TextStyle(
                        fontSize: 11,
                        color: record.syncStatus == 'rejected'
                          ? AppTheme.error
                          : record.pendingSync
                            ? AppTheme.warning
                            : AppTheme.success)),
              ],
            ),
          ),
          Text(
            record.scanSource == 'offline' ? '📴 Offline' : '📶 Online',
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
