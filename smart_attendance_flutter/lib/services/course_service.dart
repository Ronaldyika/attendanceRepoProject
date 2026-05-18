import '../core/network/api_client.dart';
import '../core/network/api_result.dart';
import '../models/course_model.dart';

class CourseService {
  final _api = ApiClient();

  Future<ApiResult<List<CourseModel>>> getCourses() async {
    try {
      final resp = await _api.get('/courses/');
      final list = (resp.data as List)
          .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<CourseModel>> getCourse(String id) async {
    try {
      final resp = await _api.get('/courses/$id/');
      return ApiResult.success(CourseModel.fromJson(resp.data as Map<String, dynamic>));
    } catch (e) {
      return ApiResult.failure(e.toString());
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
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<bool>> enrolStudents({
    required String courseId,
    required List<String> studentIds,
  }) async {
    try {
      await _api.post('/courses/$courseId/enrol/', data: {'student_ids': studentIds});
      return const ApiResult.success(true);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getCourseReport(String courseId) async {
    try {
      final resp = await _api.get('/reports/courses/$courseId/');
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }
}
