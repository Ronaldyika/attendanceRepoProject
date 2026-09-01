import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/network/api_client.dart';
import '../core/network/api_result.dart';
import '../core/network/api_response_utils.dart';
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
        'email': email.trim().toLowerCase(),
        'password': password,
        'device_uuid': deviceUuid,
      });
      final data = asStringMap(resp.data);
      if (data == null || data['access'] == null || data['refresh'] == null) {
        return const ApiResult.failure(
            'Unexpected login response from server.');
      }
      final userJson = data['user'];
      if (userJson is! Map) {
        return const ApiResult.failure(
            'Unexpected login response from server.');
      }

      await _persistSuccessfulLogin(
        email: email,
        password: password,
        deviceUuid: deviceUuid,
        user: UserModel.fromJson(asStringMap(userJson)!),
        access: data['access'].toString(),
        refresh: data['refresh'].toString(),
      );
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(
          parseApiError(e, fallback: 'Invalid email or password.'));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> loginOffline({
    required String email,
    required String password,
    required String deviceUuid,
  }) async {
    final storedKey = await SecureStorageService.getOfflineLoginKey();
    if (storedKey == null || storedKey.isEmpty) {
      return const ApiResult.failure(
          'Offline login is not available yet. Connect once to enable it.');
    }

    final expectedKey = _buildOfflineLoginKey(email, password, deviceUuid);
    if (storedKey != expectedKey) {
      return const ApiResult.failure(
          'Offline login is not available for this account.');
    }

    final cachedUserJson = await SecureStorageService.getUserData();
    if (cachedUserJson == null || cachedUserJson.isEmpty) {
      return const ApiResult.failure(
          'No cached account found for offline login.');
    }

    final user = UserModel.fromJsonString(cachedUserJson);
    final cached = {
      'user': user.toJson(),
      'access': await SecureStorageService.getAccessToken(),
      'refresh': await SecureStorageService.getRefreshToken(),
      'offline': true,
    };

    return ApiResult.success(cached);
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
    final payload = {
      'email': email.trim().toLowerCase(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'registration_number': registrationNumber.trim(),
      'role': role,
      'password': password,
      'password_confirm': passwordConfirm,
    };

    try {
      final resp = await _api.post('/auth/register/', data: payload);
      final data = asStringMap(resp.data);
      final userJson = data?['user'];
      if (userJson is! Map) {
        return const ApiResult.failure(
          'Unexpected registration response from server.',
        );
      }
      final user = UserModel.fromJson(asStringMap(userJson)!);
      return ApiResult.success(user);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<UserModel>> getProfile() async {
    try {
      final resp = await _api.get('/auth/profile/');
      final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
      await SecureStorageService.saveUserData(user.toJsonString());
      return ApiResult.success(user);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  /// Students for enrolment — use `id` (UUID), not registration numbers.
  Future<ApiResult<List<UserModel>>> getStudents() async {
    try {
      final resp =
          await _api.get('/auth/users/', queryParams: {'role': 'student'});
      final list = extractPaginatedList(resp.data)
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure(parseApiError(e));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> checkHealth() async {
    try {
      final resp = await _api.get('/health/');
      final map = asStringMap(resp.data) ?? {};
      return ApiResult.success(map);
    } catch (e) {
      return ApiResult.failure(
          parseApiError(e, fallback: 'Server unreachable.'));
    }
  }

  Future<void> logout() async {
    try {
      final refresh = await SecureStorageService.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _api.post('/auth/logout/', data: {'refresh': refresh});
      }
    } catch (_) {}
    await SecureStorageService.clearAll();
  }

  Future<void> _persistSuccessfulLogin({
    required String email,
    required String password,
    required String deviceUuid,
    required UserModel user,
    required String access,
    required String refresh,
  }) async {
    await SecureStorageService.saveTokens(access: access, refresh: refresh);
    await SecureStorageService.saveUserData(user.toJsonString());
    await SecureStorageService.saveOfflineLoginKey(
      _buildOfflineLoginKey(email, password, deviceUuid),
    );
  }

  String _buildOfflineLoginKey(
      String email, String password, String deviceUuid) {
    final payload = '$email|$password|$deviceUuid';
    final digest = sha256.convert(utf8.encode(payload));
    return digest.toString();
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
}
