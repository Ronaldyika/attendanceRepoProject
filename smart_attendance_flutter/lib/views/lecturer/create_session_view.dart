import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/string_utils.dart';
import '../../models/course_model.dart';
import '../shared/widgets/app_button.dart';
import '../shared/widgets/app_text_field.dart';
import 'session_detail_view.dart';

class CreateSessionView extends StatefulWidget {
  const CreateSessionView({super.key});

  @override
  State<CreateSessionView> createState() => _CreateSessionViewState();
}

class _CreateSessionViewState extends State<CreateSessionView> {
  final _venueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  CourseModel? _selectedCourse;
  bool _isCreating = false;

  @override
  void dispose() {
    _venueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course first.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    final session = await context.read<SessionController>().createSession(
      courseId: _selectedCourse!.id,
      venue: _venueCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isCreating = false);

    if (session != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailView(session: session),
        ),
      );
    } else {
      final err = context.read<SessionController>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to create session.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseController>().courses;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('New Attendance Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Session',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        Text('A signed QR code will be generated automatically',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Course selector
            const Text('Select Course *',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontSize: 14)),
            const SizedBox(height: 8),
            if (courses.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: AppTheme.warning, size: 18),
                    SizedBox(width: 8),
                    Text('No courses found. Create a course first.',
                        style: TextStyle(
                            color: AppTheme.warning, fontSize: 13)),
                  ],
                ),
              )
            else
              ...courses.map((course) => _CourseTile(
                    course: course,
                    isSelected: _selectedCourse?.id == course.id,
                    onTap: () =>
                        setState(() => _selectedCourse = course),
                  )),

            const SizedBox(height: 20),

            // Venue
            AppTextField(
              label: 'Venue (optional)',
              hint: 'e.g. Room 201, Lab A',
              controller: _venueCtrl,
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            const SizedBox(height: 16),

            // Notes
            AppTextField(
              label: 'Notes (optional)',
              hint: 'e.g. Week 5 – Lecture',
              controller: _notesCtrl,
              prefixIcon: const Icon(Icons.notes_outlined),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The QR code is valid for 15 minutes and signed with HMAC-SHA256. It auto-refreshes locally.',
                      style: TextStyle(
                          color: AppTheme.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            GradientButton(
              label: 'Create Session & Generate QR',
              onPressed:
                  (_isCreating || _selectedCourse == null) ? null : _createSession,
              isLoading: _isCreating,
              icon: Icons.qr_code_2,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final CourseModel course;
  final bool isSelected;
  final VoidCallback onTap;

  const _CourseTile({
    required this.course,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  course.code.truncate(2).toUpperCase(),
                  style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.code,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                          fontSize: 14)),
                  Text(course.title,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Text('${course.enrolledCount} students',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
