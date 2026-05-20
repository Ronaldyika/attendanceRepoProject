import '../core/network/api_client.dart';
import '../core/network/api_result.dart';
import '../core/network/api_response_utils.dart';
import '../models/course_model.dart';

class CourseService {
  final _api = ApiClient();

  Future<ApiResult<List<CourseModel>>> getCourses() async {
    try {
      final resp = await _api.get('/courses/');
      final list = extractPaginatedList(resp.data)
          .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<CourseModel>> getCourse(String id) async {
    try {
      final resp = await _api.get('/courses/$id/');
      return ApiResult.success(CourseModel.fromJson(resp.data as Map<String, dynamic>));
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<CourseModel>> createCourse({
    required String code,
    required String title,
    required String lecturerId,
  }) async {
    try {
      final resp = await _api.post('/courses/', data: {
        'code': code,
        'title': title,
        'lecturer': lecturerId,
      });
      return ApiResult.success(CourseModel.fromJson(resp.data as Map<String, dynamic>));
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  /// [studentIds] must be user UUIDs from GET /auth/users/?role=student.
  Future<ApiResult<String>> enrolStudents({
    required String courseId,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) {
      return const ApiResult.failure('Select at least one student.');
    }
    try {
      final resp = await _api.post('/courses/$courseId/enrol/', data: {
        'student_ids': studentIds,
      });
      final message = (resp.data as Map<String, dynamic>?)?['message']
              ?.toString() ??
          'Enrolment updated.';
      return ApiResult.success(message);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getCourseReport(String courseId) async {
    try {
      final resp = await _api.get('/reports/courses/$courseId/');
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }
}
