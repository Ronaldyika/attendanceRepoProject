import 'package:flutter_test/flutter_test.dart';
import 'package:smart_attendance/controllers/auth_controller.dart';
import 'package:smart_attendance/core/network/api_result.dart';
import 'package:smart_attendance/services/auth_service.dart';

class FakeOfflineAuthService extends AuthService {
  bool shouldOfflineLogin = false;

  @override
  Future<ApiResult<Map<String, dynamic>>> login({
    required String email,
    required String password,
    required String deviceUuid,
  }) async => const ApiResult.failure('Network unavailable');

  @override
  Future<ApiResult<Map<String, dynamic>>> loginOffline({
    required String email,
    required String password,
    required String deviceUuid,
  }) async {
    if (!shouldOfflineLogin) {
      return const ApiResult.failure('Offline login not enabled');
    }
    return ApiResult.success({
      'user': {
        'id': 'u1',
        'email': email,
        'first_name': 'Jane',
        'last_name': 'Doe',
        'role': 'student',
      },
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('falls back to offline login when the server login fails', () async {
    final service = FakeOfflineAuthService()..shouldOfflineLogin = true;
    final controller = AuthController(service: service);

    final ok = await controller.login('student@nahpi.cm', 'secret');

    expect(ok, isTrue);
    expect(controller.status, AuthStatus.authenticated);
    expect(controller.user?.email, 'student@nahpi.cm');
  });
}
