import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/string_utils.dart';
import '../../services/attendance_service.dart';
import '../shared/widgets/staggered_fade_in.dart';

class SyncHistoryView extends StatefulWidget {
  const SyncHistoryView({super.key});

  @override
  State<SyncHistoryView> createState() => _SyncHistoryViewState();
}

class _SyncHistoryViewState extends State<SyncHistoryView> {
  final _service = AttendanceService();
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getSyncHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _batches = result.data!;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Sync History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _batches.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _batches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => StaggeredFadeIn(
                          index: i,
                          child: _SyncBatchCard(batch: _batches[i]),
                        ),
                      ),
                    ),
    );
  }
}

class _SyncBatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  const _SyncBatchCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final accepted = batch['accepted'] ?? 0;
    final rejected = batch['rejected'] ?? 0;
    final duplicates = batch['duplicates'] ?? 0;
    final total = batch['total_submitted'] ?? 0;
    final status = (batch['status'] ?? 'complete').toString();
    final createdAt = batch['created_at']?.toString();
    final dateStr = createdAt != null
        ? DateFormat('MMM d, yyyy · HH:mm').format(DateTime.parse(createdAt))
        : 'Unknown time';

    final isSuccess = status == 'complete' && rejected == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess
              ? AppTheme.success.withOpacity(0.3)
              : AppTheme.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isSuccess ? AppTheme.success : AppTheme.warning)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSuccess ? Icons.cloud_done : Icons.cloud_sync,
                  color: isSuccess ? AppTheme.success : AppTheme.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                    Text('Batch ${((batch['id'] ?? '').toString()).truncate(8)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? AppTheme.success.withOpacity(0.1)
                      : AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSuccess ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetricChip(label: 'Submitted', value: '$total', color: AppTheme.primary),
              const SizedBox(width: 8),
              _MetricChip(label: 'Accepted', value: '$accepted', color: AppTheme.success),
              const SizedBox(width: 8),
              if (duplicates > 0)
                _MetricChip(label: 'Dupes', value: '$duplicates', color: AppTheme.textSecondary),
              if (rejected > 0)
                _MetricChip(label: 'Rejected', value: '$rejected', color: AppTheme.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sync_disabled,
              size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('No sync history yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Offline records will appear here\nafter they sync to the server.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
