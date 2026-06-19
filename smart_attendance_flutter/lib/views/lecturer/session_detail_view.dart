import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../controllers/session_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../models/session_model.dart';
import '../../core/utils/qr_utils.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/status_badge.dart';

class SessionDetailView extends StatefulWidget {
  final SessionModel session;
  const SessionDetailView({super.key, required this.session});

  @override
  State<SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<SessionDetailView>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  String? _currentQrPayload;
  Timer? _localQrTimer;
  int _localSecondsRemaining = 0;
  bool _isClosing = false;
  bool _isRefreshing = false;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initQr();
    _loadReport();
  }

  void _initQr() {
    final session = widget.session;
    if (session.sessionSecret != null && session.isOpen) {
      _regenerateLocalQr(session);
      _startLocalTimer(session);
    } else {
      _currentQrPayload = session.qrPayload;
    }
  }

  void _regenerateLocalQr(SessionModel session) {
    if (session.sessionSecret == null) return;
    _currentQrPayload = QrUtils.generateQrPayload(
      sessionId: session.id,
      courseCode: session.courseCode,
      secret: session.sessionSecret!,
      validitySeconds: AppConstants.qrValiditySeconds,
    );
    setState(() => _localSecondsRemaining = AppConstants.qrValiditySeconds);
  }

  void _startLocalTimer(SessionModel session) {
    _localQrTimer?.cancel();
    _localQrTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _localSecondsRemaining =
            (_localSecondsRemaining - 1).clamp(0, AppConstants.qrValiditySeconds);
      });
      if (_localSecondsRemaining <= 0) {
        _regenerateLocalQr(session);
        _localSecondsRemaining = AppConstants.qrValiditySeconds;
      }
    });
  }

  Future<void> _loadReport() async {
    final ctrl = context.read<SessionController>();
    final data = await ctrl.getSessionReport(widget.session.id);
    if (mounted) setState(() => _report = data);
  }

  Future<void> _closeSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Close Session'),
        content: const Text(
            'Are you sure you want to close this session? Students will no longer be able to scan the QR code.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Close Session'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isClosing = true);
    final ok =
        await context.read<SessionController>().closeSession(widget.session.id);
    if (!mounted) return;
    setState(() => _isClosing = false);
    if (ok) {
      _localQrTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session closed successfully.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to close session.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _refreshQr() async {
    setState(() => _isRefreshing = true);
    await context.read<SessionController>().refreshQr(widget.session.id);
    if (!mounted) return;
    final updated = context
        .read<SessionController>()
        .sessions
        .firstWhere((s) => s.id == widget.session.id,
            orElse: () => widget.session);
    _regenerateLocalQr(updated);
    setState(() => _isRefreshing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code refreshed.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _localQrTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final mm = (_localSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final ss = (_localSecondsRemaining % 60).toString().padLeft(2, '0');
    final progress =
        _localSecondsRemaining / AppConstants.qrValiditySeconds;
    final nearExpiry =
        _localSecondsRemaining <= (AppConstants.qrValiditySeconds <= 10 ? 2 : 120);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(session.courseCode),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              if (_currentQrPayload != null) {
                Clipboard.setData(
                    ClipboardData(text: _currentQrPayload!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR payload copied.')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Status header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: session.isOpen
                    ? AppTheme.primaryGradient
                    : const LinearGradient(
                        colors: [Color(0xFF6B7280), Color(0xFF4B5563)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.class_outlined,
                      color: Colors.white, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.courseTitle,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        if (session.venue?.isNotEmpty == true)
                          Text('📍 ${session.venue}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusBadge(status: session.status),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── QR Code area ───────────────────────────────────────────
            if (session.isOpen && _currentQrPayload != null) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primary.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    Text('Scan to Mark Attendance',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: nearExpiry
                                  ? AppTheme.error.withOpacity(0.4)
                                  : AppTheme.primary.withOpacity(0.2),
                              width: 2),
                        ),
                        child: QrImageView(
                          data: _currentQrPayload!,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Countdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Expires in',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                        Text('$mm:$ss',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: nearExpiry
                                    ? AppTheme.error
                                    : AppTheme.success)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: AppTheme.divider,
                        valueColor: AlwaysStoppedAnimation(
                          nearExpiry ? AppTheme.error : AppTheme.success,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (nearExpiry)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.error.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_outlined,
                                color: AppTheme.error, size: 16),
                            SizedBox(width: 6),
                            Text('QR code expiring soon',
                                style: TextStyle(
                                    color: AppTheme.error, fontSize: 12)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Refresh QR Code',
                      onPressed: _isRefreshing ? null : _refreshQr,
                      isLoading: _isRefreshing,
                      icon: Icons.refresh,
                      outlined: true,
                      width: 200,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Attendance stats ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatItem(
                        value: '${_report?['attendance_count'] ?? session.attendanceCount}',
                        label: 'Checked In',
                        color: AppTheme.success,
                      ),
                      _StatDivider(),
                      _StatItem(
                        value: session.isOpen ? 'Open' : 'Closed',
                        label: 'Status',
                        color: session.isOpen
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Attendance list ────────────────────────────────────────
            if (_report != null &&
                (_report!['records'] as List?)?.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Present Students',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    ...(_report!['records'] as List)
                        .take(10)
                        .map((r) => _AttendeeRow(record: r)),
                    if ((_report!['records'] as List).length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            '+${(_report!['records'] as List).length - 10} more students',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Close button ───────────────────────────────────────────
            if (session.isOpen)
              AppButton(
                label: 'Close Session',
                onPressed: _isClosing ? null : _closeSession,
                isLoading: _isClosing,
                backgroundColor: AppTheme.error,
                icon: Icons.stop_circle_outlined,
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatItem(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 36, color: AppTheme.divider, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _AttendeeRow extends StatelessWidget {
  final Map<String, dynamic> record;
  const _AttendeeRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final studentName = (record['student_name'] as String?)?.trim();
    final displayName = (studentName != null && studentName.isNotEmpty)
        ? studentName
        : (record['student_id'] as String?) ?? 'Student';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';
    final source = (record['scan_source'] as String?) ?? 'online';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryLight,
            child: Text(
              initial,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(displayName,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: source == 'offline'
                  ? AppTheme.warning.withOpacity(0.1)
                  : AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              source == 'offline' ? 'Offline' : 'Online',
              style: TextStyle(
                  fontSize: 10,
                  color: source == 'offline'
                      ? AppTheme.warning
                      : AppTheme.success,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
