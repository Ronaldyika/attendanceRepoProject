import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/string_utils.dart';
import '../shared/animations/fade_slide_route.dart';
import 'sync_history_view.dart';

class StudentProfileView extends StatelessWidget {
  const StudentProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final attCtrl = context.watch<AttendanceController>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar + name
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      user?.firstName.safeInitial('S') ?? 'S',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.fullName ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Text(user?.email ?? '',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      user?.registrationNumber ?? 'No Reg. Number',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick stats
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    value: '${attCtrl.records.length}',
                    label: 'Total Scans',
                    icon: Icons.qr_code_2,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    value: '${attCtrl.pendingCount}',
                    label: 'Pending Sync',
                    icon: Icons.cloud_upload_outlined,
                    color: attCtrl.pendingCount > 0
                        ? AppTheme.warning
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info tiles
            _InfoTile(
              icon: Icons.devices,
              label: 'Device Binding',
              value: user?.isDeviceBound == true ? 'Bound ✓' : 'Not bound',
              valueColor: user?.isDeviceBound == true
                  ? AppTheme.success
                  : AppTheme.warning,
            ),
            _InfoTile(
              icon: Icons.fingerprint,
              label: 'Device UUID',
              value: auth.deviceUuid != null && auth.deviceUuid!.isNotEmpty
                  ? '${auth.deviceUuid!.truncate(16, '...')}'
                  : 'Unavailable',
            ),
            _InfoTile(
              icon: Icons.shield_outlined,
              label: 'Fraud Protection',
              value: 'HMAC-SHA256 + Device Binding',
              valueColor: AppTheme.success,
            ),
            const SizedBox(height: 8),

            // Sync now
            if (attCtrl.pendingCount > 0) ...[
              GestureDetector(
                onTap: attCtrl.syncState == SyncState.syncing
                    ? null
                    : () async {
                        final result = await attCtrl.syncPending(
                          studentId: auth.user!.id,
                          deviceUuid: auth.deviceUuid ?? '',
                        );
                        if (context.mounted && result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Synced ${result['accepted'] ?? 0} records.'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, color: AppTheme.warning),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Sync Pending Records',
                            style: TextStyle(
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                      if (attCtrl.syncState == SyncState.syncing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.warning))
                      else
                        const Icon(Icons.chevron_right,
                            color: AppTheme.warning),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            _InfoTile(
              icon: Icons.history,
              label: 'Sync History',
              value: 'View batch upload log',
              valueColor: AppTheme.primary,
              onTap: () => Navigator.push(
                context,
                FadeSlideRoute(page: const SyncHistoryView()),
              ),
            ),
            const SizedBox(height: 8),

            // Logout
            GestureDetector(
              onTap: () async {
                await context.read<AuthController>().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppConstants.routeLogin, (_) => false);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.error.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: AppTheme.error),
                    SizedBox(width: 12),
                    Text('Logout',
                        style: TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Spacer(),
                    Icon(Icons.chevron_right,
                        color: AppTheme.error),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatBox({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  final VoidCallback? onTap;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? AppTheme.textPrimary)),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary, size: 18),
        ],
      ),
      ),
    );
  }
}
