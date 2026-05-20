import '../core/network/api_client.dart';
import '../core/network/api_result.dart';
import '../core/network/api_response_utils.dart';
import '../core/database/database_helper.dart';
import '../models/session_model.dart';

class SessionService {
  final _api = ApiClient();
  final _db = DatabaseHelper();

  Future<ApiResult<SessionModel>> createSession({
    required String courseId,
    String? venue,
    String? notes,
  }) async {
    try {
      final resp = await _api.post('/sessions/', data: {
        'course': courseId,
        if (venue != null && venue.isNotEmpty) 'venue': venue,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      final session = SessionModel.fromJson(resp.data as Map<String, dynamic>);
      await _cacheSession(session);
      return ApiResult.success(session);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<List<SessionModel>>> getSessions() async {
    try {
      final resp = await _api.get('/sessions/');
      final list = extractPaginatedList(resp.data)
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final s in list) {
        await _cacheSession(s);
      }
      return ApiResult.success(list);
    } catch (e) {
      final cached = await _getLocalSessions();
      if (cached.isNotEmpty) return ApiResult.success(cached);
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<bool>> closeSession(String sessionId) async {
    try {
      await _api.post('/sessions/$sessionId/close/');
      await _db.update(
        'attendance_sessions',
        {'status': 'closed', 'closed_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      return const ApiResult.success(true);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<SessionModel>> refreshQr(String sessionId) async {
    try {
      final resp = await _api.get('/sessions/$sessionId/qr/');
      final session = SessionModel.fromJson(resp.data as Map<String, dynamic>);
      await _cacheSession(session);
      return ApiResult.success(session);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getSessionReport(String sessionId) async {
    try {
      final resp = await _api.get('/reports/sessions/$sessionId/');
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<void> _cacheSession(SessionModel session) async {
    await _db.insert('attendance_sessions', {
      'id': session.id,
      'course_id': session.courseId,
      'course_code': session.courseCode,
      'course_title': session.courseTitle,
      'created_by': session.createdBy,
      'lecturer_name': session.lecturerName,
      'status': session.status,
      'started_at': session.startedAt,
      'expires_at': session.expiresAt,
      'closed_at': session.closedAt,
      'venue': session.venue,
      'notes': session.notes,
      'session_secret': session.sessionSecret,
      'qr_payload': session.qrPayload,
      'expiry_unix': session.expiryUnix,
      'attendance_count': session.attendanceCount,
      'synced_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<SessionModel>> _getLocalSessions() async {
    final rows = await _db.query(
      'attendance_sessions',
      orderBy: 'started_at DESC',
    );
    return rows.map((r) => SessionModel.fromJson({
          'id': r['id'],
          'course': r['course_id'],
          'course_code': r['course_code'],
          'course_title': r['course_title'],
          'created_by': r['created_by'],
          'lecturer_name': r['lecturer_name'],
          'status': r['status'],
          'started_at': r['started_at'],
          'expires_at': r['expires_at'],
          'closed_at': r['closed_at'],
          'venue': r['venue'],
          'notes': r['notes'],
          'session_secret': r['session_secret'],
          'qr_payload': r['qr_payload'],
          'expiry_unix': r['expiry_unix'],
          'attendance_count': r['attendance_count'] ?? 0,
        })).toList();
  }

  Future<SessionModel?> getLocalSession(String sessionId) async {
    final rows = await _db.query(
      'attendance_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return SessionModel.fromJson({
      'id': r['id'], 'course': r['course_id'],
      'course_code': r['course_code'], 'course_title': r['course_title'],
      'created_by': r['created_by'], 'lecturer_name': r['lecturer_name'],
      'status': r['status'], 'started_at': r['started_at'],
      'expires_at': r['expires_at'], 'closed_at': r['closed_at'],
      'venue': r['venue'], 'notes': r['notes'],
      'session_secret': r['session_secret'], 'qr_payload': r['qr_payload'],
      'expiry_unix': r['expiry_unix'], 'attendance_count': r['attendance_count'] ?? 0,
    });
  }
}
