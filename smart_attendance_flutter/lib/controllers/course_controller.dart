import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/course_service.dart';

enum CourseState { idle, loading, loaded, error }

class CourseController extends ChangeNotifier {
  final _service = CourseService();
  final _authService = AuthService();

  CourseState _state = CourseState.idle;
  List<CourseModel> _courses = [];
  String? _error;

  CourseState get state => _state;
  List<CourseModel> get courses => _courses;
  String? get error => _error;

  Future<void> loadCourses() async {
    _state = CourseState.loading;
    notifyListeners();
    final result = await _service.getCourses();
    if (result.isSuccess) {
      _courses = result.data!;
      _state = CourseState.loaded;
    } else {
      _error = result.error;
      _state = CourseState.error;
    }
    notifyListeners();
  }

  Future<CourseModel?> createCourse({
    required String code,
    required String title,
    required String lecturerId,
  }) async {
    final result = await _service.createCourse(
      code: code, title: title, lecturerId: lecturerId,
    );
    if (result.isSuccess) {
      _courses.insert(0, result.data!);
      notifyListeners();
      return result.data;
    }
    _error = result.error;
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> getCourseReport(String courseId) async {
    final result = await _service.getCourseReport(courseId);
    return result.isSuccess ? result.data : null;
  }

  Future<List<UserModel>> loadStudents() async {
    final result = await _authService.getStudents();
    if (result.isSuccess) return result.data!;
    _error = result.error;
    notifyListeners();
    return [];
  }

  Future<String?> enrolStudents({
    required String courseId,
    required List<String> studentIds,
  }) async {
    final result = await _service.enrolStudents(
      courseId: courseId,
      studentIds: studentIds,
    );
    if (result.isSuccess) {
      await loadCourses();
      return result.data;
    }
    _error = result.error;
    notifyListeners();
    return null;
  }

  void clearError() { _error = null; notifyListeners(); }
}
