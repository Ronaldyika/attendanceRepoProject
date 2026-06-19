import 'dart:async';
import 'package:flutter/material.dart';
import '../models/attendance_record_model.dart';
import '../models/session_model.dart';
import '../services/attendance_service.dart';
import '../core/utils/connectivity_service.dart';

enum AttendanceScanState { idle, scanning, processing, success, duplicate, error }
enum SyncState { idle, syncing, synced, error }

class AttendanceController extends ChangeNotifier {
  final _service = AttendanceService();
  final _connectivity = ConnectivityService();

  AttendanceScanState _scanState = AttendanceScanState.idle;
  SyncState _syncState = SyncState.idle;
  List<AttendanceRecordModel> _records = [];
  String? _scanError;
  String? _syncError;
  AttendanceRecordModel? _lastScannedRecord;
  int _pendingCount = 0;
  StreamSubscription<bool>? _connectivitySub;

  AttendanceScanState get scanState => _scanState;
  SyncState get syncState => _syncState;
  List<AttendanceRecordModel> get records => _records;
  String? get scanError => _scanError;
  String? get syncError => _syncError;
  AttendanceRecordModel? get lastScannedRecord => _lastScannedRecord;
  int get pendingCount => _pendingCount;
  bool get hasPending => _pendingCount > 0;

  void initSync({required String studentId, required String deviceUuid}) {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
      if (online && _pendingCount > 0) {
        syncPending(studentId: studentId, deviceUuid: deviceUuid);
      }
    });
    _refreshPendingCount(studentId);
  }

  Future<void> loadRecords(String studentId) async {
    _records = await _service.getAllLocalRecords(studentId);
    _pendingCount = _service.getPendingCount(_records);
    notifyListeners();
  }

  Future<bool> scanQrOnline({
    required String sessionId,
    required String qrPayload,
    required String deviceUuid,
    required String studentId,
  }) async {
    _scanState = AttendanceScanState.processing;
    _scanError = null;
    notifyListeners();

    final result = await _service.recordOnlineScan(
      sessionId: sessionId,
      qrPayload: qrPayload,
      deviceUuid: deviceUuid,
      studentId: studentId,
    );

    if (result.isSuccess) {
      _lastScannedRecord = result.data;
      await loadRecords(studentId);
      _scanState = AttendanceScanState.success;
      notifyListeners();
      return true;
    } else {
      _scanError = result.error;
      _scanState = AttendanceScanState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> scanQrOffline({
    required SessionModel session,
    required String qrPayload,
    required String deviceUuid,
    required String studentId,
    String? registeredDeviceUuid,
  }) async {
    _scanState = AttendanceScanState.processing;
    _scanError = null;
    notifyListeners();

    final result = await _service.recordOfflineScan(
      session: session,
      qrPayload: qrPayload,
      deviceUuid: deviceUuid,
      studentId: studentId,
      registeredDeviceUuid: registeredDeviceUuid,
    );

    if (result.isSuccess) {
      _lastScannedRecord = result.record;
      _records.insert(0, result.record!);
      _pendingCount++;
      _scanState = AttendanceScanState.success;
      notifyListeners();
      return true;
    } else if (result.isDuplicate) {
      _scanState = AttendanceScanState.duplicate;
      _scanError = result.errorMessage;
      notifyListeners();
      return false;
    } else {
      _scanError = result.errorMessage;
      _scanState = AttendanceScanState.error;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> syncPending({
    required String studentId,
    required String deviceUuid,
  }) async {
    if (_syncState == SyncState.syncing) return null;
    _syncState = SyncState.syncing;
    _syncError = null;
    notifyListeners();

    final result = await _service.syncPendingRecords(
      deviceUuid: deviceUuid,
      studentId: studentId,
    );

    if (result.isSuccess) {
      await loadRecords(studentId);
      _syncState = SyncState.synced;
      notifyListeners();
      return result.data;
    } else {
      _syncError = result.error;
      _syncState = SyncState.error;
      notifyListeners();
      return null;
    }
  }

  Future<void> _refreshPendingCount(String studentId) async {
    final pending = await _service.getPendingRecords(studentId);
    _pendingCount = pending.length;
    notifyListeners();
  }

  void resetScanState() {
    _scanState = AttendanceScanState.idle;
    _scanError = null;
    notifyListeners();
  }

  void resetSyncState() {
    _syncState = SyncState.idle;
    _syncError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
