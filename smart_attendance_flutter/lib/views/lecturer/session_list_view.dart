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

class SessionListView extends StatefulWidget {
  const SessionListView({super.key});

  @override
  State<SessionListView> createState() => _SessionListViewState();
}

class _SessionListViewState extends State<SessionListView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SessionModel> _filteredSessions(SessionController ctrl) {
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = ctrl.sessions.where((session) {
      final matchesFilter = switch (_filter) {
        'open' => session.isOpen,
        'closed' => !session.isOpen,
        _ => true,
      };
      if (!matchesFilter) return false;

      if (query.isEmpty) return true;

      final searchable = '${session.courseCode} ${session.courseTitle} ${session.venue ?? ''}'
          .toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SessionController>();
    final filteredSessions = _filteredSessions(ctrl);

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
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                          hintText: 'Search by course, venue, or code',
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip(label: 'All', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                            const SizedBox(width: 8),
                            _FilterChip(label: 'Open', selected: _filter == 'open', onTap: () => setState(() => _filter = 'open')),
                            const SizedBox(width: 8),
                            _FilterChip(label: 'Closed', selected: _filter == 'closed', onTap: () => setState(() => _filter = 'closed')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredSessions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2_outlined,
                                  size: 72, color: AppTheme.textSecondary),
                              SizedBox(height: 16),
                              Text('No matching sessions',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              SizedBox(height: 8),
                              Text('Try another search or create a new session',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary)),
                              SizedBox(height: 100),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filteredSessions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final session = filteredSessions[i];
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
                ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                ? AppTheme.success.withValues(alpha: 0.3)
                : AppTheme.divider,
            width: session.isOpen ? 1.5 : 1,
          ),
          boxShadow: session.isOpen
              ? [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.08),
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
    const total = AppConstants.qrValiditySeconds;
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
