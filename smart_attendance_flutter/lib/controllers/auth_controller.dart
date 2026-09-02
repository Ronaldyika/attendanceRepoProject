import 'package:flutter/material.dart';
import '../core/network/api_response_utils.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthController extends ChangeNotifier {
  AuthController({AuthService? service}) : _service = service ?? AuthService();

  final AuthService _service;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;
  String? _deviceUuid;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  String? get deviceUuid => _deviceUuid;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> init() async {
    _setLoading();

    try {
      _deviceUuid = await _service.getDeviceUuid();
      final cached = await _service.getCachedUser();
      if (cached != null) {
        _user = cached;
        await refreshProfile();
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _error = 'Unable to restore your session right now.';
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    final cleanedEmail = email.trim();
    final cleanedPassword = password.trim();

    if (cleanedEmail.isEmpty || cleanedPassword.isEmpty) {
      _error = 'Please enter both your email and password.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanedEmail)) {
      _error = 'Please enter a valid email address.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    _setLoading();

    _deviceUuid ??= await _service.getDeviceUuid();
    final result = await _service.login(
      email: cleanedEmail,
      password: cleanedPassword,
      deviceUuid: _deviceUuid!,
    );

    if (result.isSuccess) {
      final payload = result.data;
      final userData = payload?['user'];
      if (userData is! Map) {
        _error = 'Unexpected login response from server.';
        _user = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      _user = UserModel.fromJson(userData.cast<String, dynamic>());
      await refreshProfile();
      _status = AuthStatus.authenticated;
      _error = null;
      notifyListeners();
      return true;
    }

    final offlineResult = await _service.loginOffline(
      email: email,
      password: password,
      deviceUuid: _deviceUuid!,
    );
    if (offlineResult.isSuccess) {
      final payload = offlineResult.data;
      final userData = payload?['user'];
      if (userData is! Map) {
        _error = 'Unable to restore your offline session.';
        _user = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      _user = UserModel.fromJson(userData.cast<String, dynamic>());
      _status = AuthStatus.authenticated;
      _error = null;
      notifyListeners();
      return true;
    }

    _error = result.error;
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String email,
    required String firstName,
    required String lastName,
    required String registrationNumber,
    required String role,
    required String password,
    required String passwordConfirm,
  }) async {
    final cleanedEmail = email.trim();
    final cleanedFirst = firstName.trim();
    final cleanedLast = lastName.trim();
    final cleanedRegNo = registrationNumber.trim();
    final cleanedRole = role.trim();
    final cleanedPassword = password.trim();
    final cleanedPasswordConfirm = passwordConfirm.trim();

    if (cleanedEmail.isEmpty ||
        cleanedFirst.isEmpty ||
        cleanedLast.isEmpty ||
        cleanedRegNo.isEmpty ||
        cleanedRole.isEmpty) {
      _error = 'Please complete all required account fields.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanedEmail)) {
      _error = 'Please enter a valid email address.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    if (cleanedPassword.length < 8) {
      _error = 'Password must be at least 8 characters long.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    if (cleanedPassword != cleanedPasswordConfirm) {
      _error = 'Passwords do not match.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    _setLoading();

    final result = await _service.register(
      email: cleanedEmail,
      firstName: cleanedFirst,
      lastName: cleanedLast,
      registrationNumber: cleanedRegNo,
      role: cleanedRole,
      password: cleanedPassword,
      passwordConfirm: cleanedPasswordConfirm,
    );

    if (result.isSuccess) {
      _error = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    }

    _error = result.error;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _error = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      final result = await _service.getProfile();
      if (result.isSuccess && result.data != null) {
        _user = result.data;
        notifyListeners();
      }
    } catch (_) {
      // Keep the cached user and let the UI continue gracefully.
    }
  }

  Future<String?> checkServerHealth() async {
    final result = await _service.checkHealth();
    if (!result.isSuccess) return result.error;
    return healthWarning(result.data);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
  }
}
