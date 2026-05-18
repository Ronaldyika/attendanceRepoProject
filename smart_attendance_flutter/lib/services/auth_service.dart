import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/network/api_client.dart';
import '../core/network/api_result.dart';
import '../core/utils/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthService {
  final _api = ApiClient();

  Future<String> getDeviceUuid() async {
    String? stored = await SecureStorageService.getDeviceUuid();
    if (stored != null && stored.isNotEmpty) return stored;

    try {
      final info = DeviceInfoPlugin();
      String uuid;
      if (Platform.isAndroid) {
        final androidInfo = await info.androidInfo;
        uuid = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await info.iosInfo;
        uuid = iosInfo.identifierForVendor ?? const Uuid().v4();
      } else {
        uuid = const Uuid().v4();
      }
      await SecureStorageService.saveDeviceUuid(uuid);
      return uuid;
    } catch (_) {
      final fallback = const Uuid().v4();
      await SecureStorageService.saveDeviceUuid(fallback);
      return fallback;
    }
  }

  Future<ApiResult<Map<String, dynamic>>> login({
    required String email,
    required String password,
    required String deviceUuid,
  }) async {
    try {
      final resp = await _api.post('/auth/login/', data: {
        'email': email,
        'password': password,
        'device_uuid': deviceUuid,
      });
      final data = resp.data as Map<String, dynamic>;
      await SecureStorageService.saveTokens(
        access: data['access'],
        refresh: data['refresh'],
      );
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await SecureStorageService.saveUserData(user.toJsonString());
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(_parseError(e));
    }
  }

  Future<ApiResult<UserModel>> register({
    required String email,
    required String firstName,
    required String lastName,
    required String registrationNumber,
    required String role,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final resp = await _api.post('/auth/register/', data: {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'registration_number': registrationNumber,
        'role': role,
        'password': password,
        'password_confirm': passwordConfirm,
      });
      final user = UserModel.fromJson(
          resp.data['user'] as Map<String, dynamic>);
      return ApiResult.success(user);
    } catch (e) {
      return ApiResult.failure(_parseError(e));
    }
  }

  Future<ApiResult<UserModel>> getProfile() async {
    try {
      final resp = await _api.get('/auth/profile/');
      return ApiResult.success(UserModel.fromJson(resp.data as Map<String, dynamic>));
    } catch (e) {
      return ApiResult.failure(_parseError(e));
    }
  }

  Future<void> logout() async {
    try {
      final refresh = await SecureStorageService.getRefreshToken();
      if (refresh != null) {
        await _api.post('/auth/logout/', data: {'refresh': refresh});
      }
    } catch (_) {}
    await SecureStorageService.clearAll();
  }

  Future<UserModel?> getCachedUser() async {
    final json = await SecureStorageService.getUserData();
    if (json == null) return null;
    try {
      return UserModel.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  String _parseError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('device_uuid')) return 'This account is bound to another device.';
      if (msg.contains('401') || msg.contains('credentials')) return 'Invalid email or password.';
      if (msg.contains('400')) return 'Invalid request. Check your input.';
      if (msg.contains('connection') || msg.contains('timeout')) return 'Network error. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
