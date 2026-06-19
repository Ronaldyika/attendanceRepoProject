import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/course_controller.dart';
import '../../core/constants/app_theme.dart';
import '../../models/course_model.dart';
import '../../services/course_service.dart';
import '../shared/animations/fade_slide_route.dart';
import '../shared/widgets/staggered_fade_in.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseController>().courses;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Attendance Reports')),
      body: courses.isEmpty
          ? const Center(
              child: Text('Create a course first to view reports.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => StaggeredFadeIn(
                index: i,
                child: _CourseReportTile(course: courses[i]),
              ),
            ),
    );
  }
}

class _CourseReportTile extends StatelessWidget {
  final CourseModel course;
  const _CourseReportTile({required this.course});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        FadeSlideRoute(page: CourseReportDetailView(course: course)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bar_chart, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.code,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(course.title,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class CourseReportDetailView extends StatefulWidget {
  final CourseModel course;
  const CourseReportDetailView({super.key, required this.course});

  @override
  State<CourseReportDetailView> createState() => _CourseReportDetailViewState();
}

class _CourseReportDetailViewState extends State<CourseReportDetailView> {
  final _service = CourseService();
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.getCourseReport(widget.course.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _report = result.data;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = (_report?['students'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text('${widget.course.code} Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.course.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _SummaryStat(
                                  label: 'Sessions',
                                  value:
                                      '${_report?['total_sessions'] ?? 0}',
                                ),
                                _SummaryStat(
                                  label: 'Students',
                                  value: '${students.length}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Student Attendance',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ...students.asMap().entries.map((e) {
                        final s = e.value as Map<String, dynamic>;
                        final rate =
                            (s['attendance_rate'] as num?)?.toDouble() ?? 0;
                        return StaggeredFadeIn(
                          index: e.key,
                          child: _StudentRateTile(
                            name: s['student_name'] ?? 'Student',
                            attended: s['sessions_attended'] ?? 0,
                            total: s['total_sessions'] ?? 0,
                            rate: rate,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label, value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }
}

class _StudentRateTile extends StatelessWidget {
  final String name;
  final int attended, total;
  final double rate;

  const _StudentRateTile({
    required this.name,
    required this.attended,
    required this.total,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final color = rate >= 75
        ? AppTheme.success
        : rate >= 50
            ? AppTheme.warning
            : AppTheme.error;

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
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Text(name[0].toUpperCase(),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text('$attended / $total sessions',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${rate.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: color)),
              SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(value: rate / 100)),
            ],
          ),
        ],
      ),
    );
  }
}
