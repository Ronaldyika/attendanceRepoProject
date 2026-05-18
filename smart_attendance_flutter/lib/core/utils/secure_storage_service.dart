import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: AppConstants.kAccessToken, value: access);
    await _storage.write(key: AppConstants.kRefreshToken, value: refresh);
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.kAccessToken);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.kRefreshToken);

  static Future<void> saveDeviceUuid(String uuid) =>
      _storage.write(key: AppConstants.kDeviceUuid, value: uuid);

  static Future<String?> getDeviceUuid() =>
      _storage.read(key: AppConstants.kDeviceUuid);

  static Future<void> saveUserData(String json) =>
      _storage.write(key: AppConstants.kUserData, value: json);

  static Future<String?> getUserData() =>
      _storage.read(key: AppConstants.kUserData);

  static Future<void> clearAll() => _storage.deleteAll();
}
