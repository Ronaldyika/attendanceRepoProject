import 'package:flutter/material.dart';
import '../core/network/api_response_utils.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthController extends ChangeNotifier {
  final _service = AuthService();

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
    _status = AuthStatus.loading;
    notifyListeners();
    _deviceUuid = await _service.getDeviceUuid();
    final cached = await _service.getCachedUser();
    if (cached != null) {
      _user = cached;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    _deviceUuid ??= await _service.getDeviceUuid();
    final result = await _service.login(
      email: email,
      password: password,
      deviceUuid: _deviceUuid!,
    );

    if (result.isSuccess) {
      final userData = result.data!['user'] as Map<String, dynamic>;
      _user = UserModel.fromJson(userData);
      await refreshProfile();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } else {
      _error = result.error;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
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
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    final result = await _service.register(
      email: email,
      firstName: firstName,
      lastName: lastName,
      registrationNumber: registrationNumber,
      role: role,
      password: password,
      passwordConfirm: passwordConfirm,
    );

    if (result.isSuccess) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } else {
      _error = result.error;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final result = await _service.getProfile();
    if (result.isSuccess) {
      _user = result.data;
      notifyListeners();
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
}
