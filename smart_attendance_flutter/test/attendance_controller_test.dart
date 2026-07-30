import 'package:flutter_test/flutter_test.dart';
import 'package:smart_attendance/controllers/attendance_controller.dart';
import 'package:smart_attendance/core/network/api_result.dart';
import 'package:smart_attendance/models/attendance_record_model.dart';
import 'package:smart_attendance/services/attendance_service.dart';
import 'package:smart_attendance/core/utils/connectivity_service.dart';

class FakeAttendanceService extends AttendanceService {
  final List<AttendanceRecordModel> pendingRecords;
  int syncCalls = 0;

  FakeAttendanceService({required this.pendingRecords});

  @override
  Future<List<AttendanceRecordModel>> getPendingRecords(String studentId) async => pendingRecords;

  @override
  Future<List<AttendanceRecordModel>> getAllLocalRecords(String studentId) async => pendingRecords;

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPendingRecords({
    required String deviceUuid,
    required String studentId,
  }) async {
    syncCalls++;
    return const ApiResult.success({'accepted': 1, 'message': 'ok'});
  }
}

class FakeConnectivityService extends ConnectivityService {
  FakeConnectivityService() : super.testable(connectivity: null);

  bool _online = true;

  @override
  Future<bool> checkConnection() async => _online;

  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();

  set online(bool value) => _online = value;
}

void main() {
  group('AttendanceController offline sync', () {
    test('starts syncing automatically when the app is online and pending records exist', () async {
      final service = FakeAttendanceService(
        pendingRecords: [
          const AttendanceRecordModel(
            id: 'r1',
            studentId: 's1',
            sessionId: 'session-1',
            deviceUuid: 'device-1',
            scanSource: 'offline',
            scannedAt: '2026-07-30T10:00:00.000Z',
            idempotencyKey: 'device-1|session-1|1',
            pendingSync: true,
          ),
        ],
      );
      final connectivity = FakeConnectivityService();
      final controller = AttendanceController(
        service: service,
        connectivity: connectivity,
      );

      await controller.initSync(studentId: 's1', deviceUuid: 'device-1');

      expect(service.syncCalls, 1);
      controller.dispose();
    });
  });
}
