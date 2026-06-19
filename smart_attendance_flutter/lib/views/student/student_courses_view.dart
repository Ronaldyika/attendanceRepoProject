import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/course_controller.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/string_utils.dart';
import '../../models/course_model.dart';
import '../shared/widgets/shimmer_placeholder.dart';
import '../shared/widgets/staggered_fade_in.dart';

class StudentCoursesView extends StatelessWidget {
  const StudentCoursesView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CourseController>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('My Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<CourseController>().loadCourses(),
          ),
        ],
      ),
      body: ctrl.state == CourseState.loading
          ? const ShimmerListPlaceholder(itemCount: 5)
          : ctrl.courses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.menu_book_outlined,
                              size: 56, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 20),
                        const Text('No enrolled courses',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        const Text(
                          'Ask your lecturer to enrol you in a course.\nCourses appear here once enrolled.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: ctrl.courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => StaggeredFadeIn(
                    index: i,
                    child: _StudentCourseCard(course: ctrl.courses[i]),
                  ),
                ),
    );
  }
}

class _StudentCourseCard extends StatelessWidget {
  final CourseModel course;
  const _StudentCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.9),
                  AppTheme.accent.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                course.code.truncate(3).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.code,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.verified_user_outlined,
              color: AppTheme.success, size: 20),
        ],
      ),
    );
  }
}
