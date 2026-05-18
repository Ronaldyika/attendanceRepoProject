import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_theme.dart';
import '../../models/attendance_record_model.dart';
import '../shared/widgets/status_badge.dart';

class AttendanceHistoryView extends StatelessWidget {
  const AttendanceHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final attCtrl = context.watch<AttendanceController>();
    final auth = context.read<AuthController>();
    final records = attCtrl.records;
    final pending = attCtrl.pendingCount;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: attCtrl.syncState == SyncState.syncing
                    ? null
                    : () => attCtrl.syncPending(
                          studentId: auth.user!.id,
                          deviceUuid: auth.deviceUuid ?? '',
                        ),
                icon: attCtrl.syncState == SyncState.syncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary))
                    : const Icon(Icons.sync, size: 18),
                label: Text('Sync ($pending)'),
              ),
            ),
        ],
      ),
      body: records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 72, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('No attendance records yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Your scanned QR records will appear here',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : Column(
              children: [
                // Summary bar
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      _SummaryItem(
                        label: 'Total',
                        value: '${records.length}',
                        color: AppTheme.primary,
                      ),
                      _VertDivider(),
                      _SummaryItem(
                        label: 'Synced',
                        value: '${records.where((r) => !r.pendingSync).length}',
                        color: AppTheme.success,
                      ),
                      _VertDivider(),
                      _SummaryItem(
                        label: 'Pending',
                        value: '$pending',
                        color: pending > 0 ? AppTheme.warning : AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
                // Records list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RecordCard(record: records[i]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
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

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 32, color: AppTheme.divider);
}

class _RecordCard extends StatelessWidget {
  final AttendanceRecordModel record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    String dateStr = '';
    try {
      final dt = DateTime.parse(record.scannedAt).toLocal();
      dateStr = DateFormat('EEE, d MMM yyyy · HH:mm').format(dt);
    } catch (_) {
      dateStr = record.scannedAt;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: record.pendingSync
              ? AppTheme.warning.withOpacity(0.3)
              : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: record.pendingSync
                  ? AppTheme.warning.withOpacity(0.1)
                  : AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              record.scanSource == 'offline'
                  ? Icons.wifi_off
                  : Icons.check_circle_outline,
              color: record.pendingSync ? AppTheme.warning : AppTheme.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session · ${record.sessionId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: record.pendingSync ? 'pending' : 'synced'),
              const SizedBox(height: 4),
              Text(
                record.scanSource == 'offline' ? 'Offline' : 'Online',
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
