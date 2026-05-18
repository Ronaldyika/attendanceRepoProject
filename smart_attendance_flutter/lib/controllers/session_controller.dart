import 'dart:async';
import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';

enum SessionState { idle, loading, loaded, creating, error }

class SessionController extends ChangeNotifier {
  final _service = SessionService();

  SessionState _state = SessionState.idle;
  List<SessionModel> _sessions = [];
  SessionModel? _activeSession;
  String? _error;
  Timer? _qrRefreshTimer;
  int _qrSecondsRemaining = 0;

  SessionState get state => _state;
  List<SessionModel> get sessions => _sessions;
  SessionModel? get activeSession => _activeSession;
  String? get error => _error;
  int get qrSecondsRemaining => _qrSecondsRemaining;
  bool get hasActiveSession => _activeSession != null && _activeSession!.isOpen;

  List<SessionModel> get openSessions =>
      _sessions.where((s) => s.status == 'open').toList();
  List<SessionModel> get closedSessions =>
      _sessions.where((s) => s.status != 'open').toList();

  Future<void> loadSessions() async {
    _state = SessionState.loading;
    notifyListeners();

    final result = await _service.getSessions();
    if (result.isSuccess) {
      _sessions = result.data!;
      _sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      _state = SessionState.loaded;
    } else {
      _error = result.error;
      _state = SessionState.error;
    }
    notifyListeners();
  }

  Future<SessionModel?> createSession({
    required String courseId,
    String? venue,
    String? notes,
  }) async {
    _state = SessionState.creating;
    _error = null;
    notifyListeners();

    final result = await _service.createSession(
      courseId: courseId,
      venue: venue,
      notes: notes,
    );

    if (result.isSuccess) {
      _activeSession = result.data!;
      _sessions.insert(0, _activeSession!);
      _state = SessionState.loaded;
      _startQrTimer();
      notifyListeners();
      return _activeSession;
    } else {
      _error = result.error;
      _state = SessionState.error;
      notifyListeners();
      return null;
    }
  }

  Future<bool> closeSession(String sessionId) async {
    final result = await _service.closeSession(sessionId);
    if (result.isSuccess) {
      _qrRefreshTimer?.cancel();
      final idx = _sessions.indexWhere((s) => s.id == sessionId);
      if (idx != -1) {
        _sessions[idx] = _sessions[idx].copyWith(
          status: 'closed',
          closedAt: DateTime.now().toIso8601String(),
        );
      }
      if (_activeSession?.id == sessionId) {
        _activeSession = _activeSession!.copyWith(status: 'closed');
      }
      notifyListeners();
      return true;
    }
    _error = result.error;
    notifyListeners();
    return false;
  }

  Future<void> refreshQr(String sessionId) async {
    final result = await _service.refreshQr(sessionId);
    if (result.isSuccess) {
      _activeSession = result.data!;
      final idx = _sessions.indexWhere((s) => s.id == sessionId);
      if (idx != -1) _sessions[idx] = _activeSession!;
      _startQrTimer();
      notifyListeners();
    }
  }

  void setActiveSession(SessionModel session) {
    _activeSession = session;
    _startQrTimer();
    notifyListeners();
  }

  void _startQrTimer() {
    _qrRefreshTimer?.cancel();
    if (_activeSession?.expiryUnix == null) return;

    _updateQrCountdown();
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateQrCountdown();
      if (_qrSecondsRemaining <= 0) {
        _qrRefreshTimer?.cancel();
        notifyListeners();
      }
    });
  }

  void _updateQrCountdown() {
    if (_activeSession?.expiryUnix == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = _activeSession!.expiryUnix! - now;
    _qrSecondsRemaining = remaining > 0 ? remaining : 0;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getSessionReport(String sessionId) async {
    final result = await _service.getSessionReport(sessionId);
    return result.isSuccess ? result.data : null;
  }

  void incrementAttendanceCount(String sessionId) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      _sessions[idx] = _sessions[idx].copyWith(
        attendanceCount: _sessions[idx].attendanceCount + 1,
      );
      if (_activeSession?.id == sessionId) {
        _activeSession = _sessions[idx];
      }
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    super.dispose();
  }
}
