import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
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
      final data = resp.data as Map<String, dynamic>;
      await SecureStorageService.saveTokens(
        access: data['access'],
        refresh: data['refresh'],
      );
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await SecureStorageService.saveUserData(user.toJsonString());
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure(parseApiError(e, fallback: 'Invalid email or password.'));
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
        'email': email.trim().toLowerCase(),
        'first_name': firstName,
        'last_name': lastName,
        'registration_number': registrationNumber,
        'role': role,
        'password': password,
        'password_confirm': passwordConfirm,
      });
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
      final resp = await _api.get('/auth/users/', queryParams: {'role': 'student'});
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
      return ApiResult.failure(parseApiError(e, fallback: 'Server unreachable.'));
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
