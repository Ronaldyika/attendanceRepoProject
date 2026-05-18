import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../core/network/api_client.dart';
import '../core/network/api_result.dart';
import '../core/utils/qr_utils.dart';
import '../models/attendance_record_model.dart';
import '../models/session_model.dart';

class AttendanceService {
  final _api = ApiClient();
  final _db = DatabaseHelper();

  // ── Online scan ───────────────────────────────────────────────────────────
  Future<ApiResult<AttendanceRecordModel>> recordOnlineScan({
    required String sessionId,
    required String qrPayload,
    required String deviceUuid,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final resp = await _api.post('/attendance/scan/', data: {
        'session_id': sessionId,
        'qr_payload': qrPayload,
        'device_uuid': deviceUuid,
        'scanned_at': now,
      });
      final record = AttendanceRecordModel.fromJson(
          resp.data['record'] as Map<String, dynamic>);
      return ApiResult.success(record);
    } catch (e) {
      return ApiResult.failure(_parseError(e));
    }
  }

  // ── Offline scan (store locally) ─────────────────────────────────────────
  Future<AttendanceScanResult> recordOfflineScan({
    required SessionModel session,
    required String qrPayload,
    required String deviceUuid,
    required String studentId,
  }) async {
    // 1. Verify HMAC & expiry
    if (session.sessionSecret == null) {
      return AttendanceScanResult.failure('Session secret not available offline.');
    }
    final verify = QrUtils.verifyQrPayload(
      qrPayload,
      session.sessionSecret!,
      clockSkewTolerance: 300,
    );
    if (!verify.ok) {
      return AttendanceScanResult.failure(
        verify.reason == 'expired'
            ? 'QR code has expired. Ask your lecturer to refresh it.'
            : verify.reason == 'invalid_hmac'
                ? 'Invalid QR code. This code may have been tampered with.'
                : 'Invalid QR code format.',
      );
    }

    // 2. Duplicate check (local)
    final existing = await _db.query(
      'attendance_records',
      where: 'student_id = ? AND session_id = ? AND device_uuid = ?',
      whereArgs: [studentId, session.id, deviceUuid],
    );
    if (existing.isNotEmpty) {
      return AttendanceScanResult.duplicate();
    }

    // 3. Write to SQLite
    final now = DateTime.now();
    final idemKey =
        '$deviceUuid|${session.id}|${now.millisecondsSinceEpoch}';
    final id = const Uuid().v4();

    final record = AttendanceRecordModel(
      id: id,
      studentId: studentId,
      sessionId: session.id,
      deviceUuid: deviceUuid,
      scanSource: 'offline',
      scannedAt: now.toIso8601String(),
      idempotencyKey: idemKey,
      hmacSignature: verify.parsed?.signature,
      qrPayload: qrPayload,
      pendingSync: true,
    );

    try {
      await _db.insert(
        'attendance_records',
        record.toDb(),
        conflict: ConflictAlgorithm.abort,
      );
      return AttendanceScanResult.success(record);
    } on Exception {
      return AttendanceScanResult.duplicate();
    }
  }

  // ── Batch sync ────────────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> syncPendingRecords({
    required String deviceUuid,
    required String studentId,
  }) async {
    final pending = await getPendingRecords(studentId);
    if (pending.isEmpty) return const ApiResult.success({'accepted': 0, 'message': 'Nothing to sync.'});

    try {
      final resp = await _api.post('/sync/', data: {
        'device_uuid': deviceUuid,
        'records': pending.map((r) => r.toSyncPayload()).toList(),
      });
      final result = resp.data as Map<String, dynamic>;
      // Mark all as synced
      final now = DateTime.now().toIso8601String();
      for (final r in pending) {
        await _db.update(
          'attendance_records',
          {'pending_sync': 0, 'synced_at': now},
          where: 'id = ?',
          whereArgs: [r.id],
        );
      }
      return ApiResult.success(result);
    } catch (e) {
      return ApiResult.failure(_parseError(e));
    }
  }

  Future<List<AttendanceRecordModel>> getPendingRecords(String studentId) async {
    final rows = await _db.query(
      'attendance_records',
      where: 'student_id = ? AND pending_sync = 1',
      whereArgs: [studentId],
    );
    return rows.map(AttendanceRecordModel.fromDb).toList();
  }

  Future<List<AttendanceRecordModel>> getAllLocalRecords(String studentId) async {
    final rows = await _db.query(
      'attendance_records',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'scanned_at DESC',
    );
    return rows.map(AttendanceRecordModel.fromDb).toList();
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getOnlineRecords() async {
    try {
      final resp = await _api.get('/attendance/records/');
      final list = (resp.data as Map<String, dynamic>)['results'] as List? ??
          resp.data as List;
      return ApiResult.success(list.cast<Map<String, dynamic>>());
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  int getPendingCount(List<AttendanceRecordModel> records) =>
      records.where((r) => r.pendingSync).length;

  String _parseError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already') || msg.contains('duplicate')) {
      return 'Attendance already recorded for this session.';
    }
    if (msg.contains('closed') || msg.contains('expired')) {
      return 'This session is no longer active.';
    }
    if (msg.contains('device')) {
      return 'Device verification failed. Contact your administrator.';
    }
    if (msg.contains('hmac') || msg.contains('invalid')) {
      return 'Invalid QR code. Please scan the code displayed by your lecturer.';
    }
    return 'Failed to record attendance. Please try again.';
  }
}

class AttendanceScanResult {
  final bool isSuccess;
  final bool isDuplicate;
  final String? errorMessage;
  final AttendanceRecordModel? record;

  const AttendanceScanResult._({
    required this.isSuccess,
    required this.isDuplicate,
    this.errorMessage,
    this.record,
  });

  factory AttendanceScanResult.success(AttendanceRecordModel record) =>
      AttendanceScanResult._(isSuccess: true, isDuplicate: false, record: record);

  factory AttendanceScanResult.duplicate() =>
      AttendanceScanResult._(isSuccess: false, isDuplicate: true,
          errorMessage: 'You have already registered attendance for this session.');

  factory AttendanceScanResult.failure(String message) =>
      AttendanceScanResult._(isSuccess: false, isDuplicate: false, errorMessage: message);
}
