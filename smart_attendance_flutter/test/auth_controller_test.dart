import 'package:flutter_test/flutter_test.dart';
import 'package:smart_attendance/controllers/auth_controller.dart';
import 'package:smart_attendance/core/network/api_result.dart';
import 'package:smart_attendance/models/user_model.dart';
import 'package:smart_attendance/services/auth_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({this.loginResult, this.profileResult});

  final ApiResult<Map<String, dynamic>>? loginResult;
  final ApiResult<UserModel>? profileResult;

  int deviceUuidCalls = 0;
  int loginCalls = 0;
  int profileCalls = 0;

  @override
  Future<String> getDeviceUuid() async {
    deviceUuidCalls++;
    return 'fake-device-uuid';
  }

  @override
  Future<UserModel?> getCachedUser() async => null;

  @override
  Future<ApiResult<Map<String, dynamic>>> login({
    required String email,
    required String password,
    required String deviceUuid,
  }) async {
    loginCalls++;
    return loginResult ??
        ApiResult.success({
          'user': {
            'id': 'u1',
            'email': email,
            'first_name': 'Jane',
            'last_name': 'Doe',
            'role': 'student',
          },
        });
  }

  @override
  Future<ApiResult<UserModel>> getProfile() async {
    profileCalls++;
    return profileResult ??
        ApiResult.success(const UserModel(
          id: 'u1',
          email: 'student@nahpi.cm',
          firstName: 'Jane',
          lastName: 'Doe',
          role: 'student',
        ));
  }
}

void main() {
  group('AuthController', () {
    test('marks the user authenticated when login succeeds', () async {
      final service = FakeAuthService();
      final controller = AuthController(service: service);

      final ok = await controller.login('student@nahpi.cm', 'password123');

      expect(ok, isTrue);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.user?.email, 'student@nahpi.cm');
      expect(service.loginCalls, 1);
      expect(service.deviceUuidCalls, 1);
    });

    test('captures the error and resets auth state when login fails', () async {
      final service = FakeAuthService(
        loginResult: const ApiResult.failure('Invalid credentials'),
      );
      final controller = AuthController(service: service);

      final ok = await controller.login('student@nahpi.cm', 'wrong-password');

      expect(ok, isFalse);
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.error, 'Invalid credentials');
      expect(controller.user, isNull);
    });
  });
}
