import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import 'package:provider/provider.dart';
import '../../controllers/session_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../shared/animations/fade_slide_route.dart';
import '../shared/widgets/status_badge.dart';
import '../shared/widgets/staggered_fade_in.dart';
import 'session_detail_view.dart';

class SessionListView extends StatelessWidget {
  const SessionListView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SessionController>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Attendance Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<SessionController>().loadSessions(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppConstants.routeCreateSession),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Session', style: TextStyle(color: Colors.white)),
      ),
      body: ctrl.state == SessionState.loading
          ? const Center(child: CircularProgressIndicator())
          : ctrl.sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_outlined,
                          size: 72, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      const Text('No sessions yet',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      const Text('Create a new session to start\ntaking attendance',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 100),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: ctrl.sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final session = ctrl.sessions[i];
                    return StaggeredFadeIn(
                      index: i,
                      child: _SessionCard(
                      session: session,
                      onTap: () {
                        ctrl.setActiveSession(session);
                        Navigator.push(context, FadeSlideRoute(
                          page: SessionDetailView(session: session),
                        ));
                      },
                    ),
                    );
                  },
                ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;
  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: session.isOpen
                ? AppTheme.success.withOpacity(0.3)
                : AppTheme.divider,
            width: session.isOpen ? 1.5 : 1,
          ),
          boxShadow: session.isOpen
              ? [
                  BoxShadow(
                    color: AppTheme.success.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.courseCode,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppTheme.textPrimary)),
                      Text(session.courseTitle,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                StatusBadge(status: session.status),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(icon: Icons.people_outline, label: '${session.attendanceCount} students'),
                const SizedBox(width: 12),
                if (session.venue?.isNotEmpty == true)
                  _InfoChip(icon: Icons.location_on_outlined, label: session.venue!),
              ],
            ),
            if (session.isOpen) ...[
              const SizedBox(height: 10),
              _CountdownBar(session: session),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _CountdownBar extends StatelessWidget {
  final SessionModel session;
  const _CountdownBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SessionController>();
    final remaining = ctrl.qrSecondsRemaining;
    final total = AppConstants.qrValiditySeconds;
    final progress = remaining / total;

    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('QR expires in',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Text('$mm:$ss',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: remaining < 120 ? AppTheme.error : AppTheme.success)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.divider,
            valueColor: AlwaysStoppedAnimation(
              remaining < 120 ? AppTheme.error : AppTheme.success,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
