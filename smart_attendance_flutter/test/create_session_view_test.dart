import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_attendance/controllers/course_controller.dart';
import 'package:smart_attendance/controllers/session_controller.dart';
import 'package:smart_attendance/models/course_model.dart';
import 'package:smart_attendance/views/lecturer/create_session_view.dart';

class FakeCourseController extends CourseController {
  bool loadCoursesCalled = false;

  @override
  Future<void> loadCourses() async {
    loadCoursesCalled = true;
  }

  @override
  List<CourseModel> get courses => const [];
}

class FakeSessionController extends SessionController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CreateSessionView loads courses when it opens', (tester) async {
    final courseController = FakeCourseController();
    final sessionController = FakeSessionController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CourseController>.value(value: courseController),
          ChangeNotifierProvider<SessionController>.value(value: sessionController),
        ],
        child: const MaterialApp(
          home: CreateSessionView(),
        ),
      ),
    );

    await tester.pump();

    expect(courseController.loadCoursesCalled, isTrue,
        reason: 'The session form should fetch available courses on first open.');
  });
}
