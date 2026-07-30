import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static final Map<String, String> _memory = <String, String>{};

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _write(AppConstants.kAccessToken, access);
    await _write(AppConstants.kRefreshToken, refresh);
  }

  static Future<String?> getAccessToken() => _read(AppConstants.kAccessToken);

  static Future<String?> getRefreshToken() => _read(AppConstants.kRefreshToken);

  static Future<void> saveDeviceUuid(String uuid) =>
      _write(AppConstants.kDeviceUuid, uuid);

  static Future<String?> getDeviceUuid() => _read(AppConstants.kDeviceUuid);

  static Future<void> saveUserData(String json) =>
      _write(AppConstants.kUserData, json);

  static Future<String?> getUserData() => _read(AppConstants.kUserData);

  static Future<void> saveOfflineLoginKey(String key) =>
      _write(AppConstants.kOfflineLoginKey, key);

  static Future<String?> getOfflineLoginKey() =>
      _read(AppConstants.kOfflineLoginKey);

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Ignore storage plugin issues in tests and non-platform environments.
    }
    _memory.clear();
  }

  static Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      _memory[key] = value;
    }
  }

  static Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return _memory[key];
    }
  }
}
