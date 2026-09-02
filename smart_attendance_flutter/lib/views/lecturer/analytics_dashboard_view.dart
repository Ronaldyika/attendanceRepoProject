import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/session_controller.dart';
import '../../core/constants/app_theme.dart';
import '../../models/session_model.dart';

class AnalyticsDashboardView extends StatelessWidget {
  const AnalyticsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionController>().sessions;
    final data = sessions.isEmpty ? _demoSessions() : sessions;

    final totalAttendance = data.fold<int>(0, (sum, item) => sum + item.attendanceCount);
    final averageAttendance = data.isEmpty ? 0.0 : totalAttendance / data.length;
    final highestSession = data.isEmpty
        ? 0
        : data.reduce((a, b) => a.attendanceCount >= b.attendanceCount ? a : b).attendanceCount;
    final complianceRate = data.isEmpty
        ? 94.0
        : ((totalAttendance / (data.length * 26.0)) * 100).clamp(0.0, 100.0);

    final pieData = [
      _ChartSlice('Compliant', complianceRate, AppTheme.success),
      _ChartSlice('At risk', (100 - complianceRate).clamp(0.0, 100.0), AppTheme.warning),
      _ChartSlice('Low activity', (100 - complianceRate).clamp(0.0, 100.0) * 0.35, AppTheme.primary),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Analytics & Compliance'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => context.read<SessionController>().loadSessions(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Civilsalt Operations Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Avg. attendance',
                          value: averageAttendance.toStringAsFixed(1),
                          suffix: ' / session',
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: 'Compliance',
                          value: complianceRate.toStringAsFixed(1),
                          suffix: '%',
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetricTile(
                    label: 'Peak session',
                    value: '$highestSession',
                    suffix: ' marked present',
                    color: AppTheme.warning,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Attendance trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 220,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) return const SizedBox();
                          final label = data[index].courseCode;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label.length > 6 ? label.substring(0, 6) : label,
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barTouchData: BarTouchData(enabled: false),
                  barGroups: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final session = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: session.attendanceCount.toDouble(),
                          color: index.isEven ? AppTheme.primary : AppTheme.accent,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Performance mix',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 28,
                        sections: pieData.asMap().entries.map((entry) {
                          final index = entry.key;
                          final slice = entry.value;
                          return PieChartSectionData(
                            value: slice.value,
                            title: '',
                            color: slice.color,
                            radius: index == 0 ? 28 : 24,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: pieData.map((slice) {
                        final label = slice.label;
                        final percent = slice.value.toStringAsFixed(1);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: slice.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$label $percent%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Management compliance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...data.map((session) {
              final rate = session.attendanceCount > 0
                  ? ((session.attendanceCount / (session.attendanceCount + 8)) * 100).clamp(0.0, 100.0)
                  : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${session.courseCode} · ${session.courseTitle}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${rate.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: rate / 100,
                        backgroundColor: AppTheme.divider,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${session.attendanceCount} present / target 25',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<SessionModel> _demoSessions() {
    return const [
      SessionModel(
        id: 'demo-1',
        courseId: 'c1',
        courseCode: 'CIV-101',
        courseTitle: 'Workforce Attendance',
        createdBy: 'admin',
        lecturerName: 'Manager',
        status: 'closed',
        startedAt: '2026-08-13T09:00:00.000',
        expiresAt: '2026-08-13T10:00:00.000',
        attendanceCount: 22,
      ),
      SessionModel(
        id: 'demo-2',
        courseId: 'c2',
        courseCode: 'OPS-204',
        courseTitle: 'Shift Coordination',
        createdBy: 'admin',
        lecturerName: 'Manager',
        status: 'closed',
        startedAt: '2026-08-15T09:00:00.000',
        expiresAt: '2026-08-15T10:00:00.000',
        attendanceCount: 18,
      ),
      SessionModel(
        id: 'demo-3',
        courseId: 'c3',
        courseCode: 'HR-110',
        courseTitle: 'Compliance Check-in',
        createdBy: 'admin',
        lecturerName: 'Manager',
        status: 'open',
        startedAt: '2026-08-20T09:00:00.000',
        expiresAt: '2026-08-20T10:00:00.000',
        attendanceCount: 28,
      ),
    ];
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color color;
  final bool fullWidth;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  suffix,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _ChartSlice {
  final String label;
  final double value;
  final Color color;

  const _ChartSlice(this.label, this.value, this.color);
}
