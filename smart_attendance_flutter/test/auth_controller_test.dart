import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_attendance/controllers/auth_controller.dart';
import 'package:smart_attendance/core/network/api_result.dart';
import 'package:smart_attendance/core/network/api_response_utils.dart';
import 'package:smart_attendance/models/user_model.dart';
import 'package:smart_attendance/services/auth_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({this.loginResult, this.profileResult, this.registerResult});

  final ApiResult<Map<String, dynamic>>? loginResult;
  final ApiResult<UserModel>? profileResult;
  final ApiResult<UserModel>? registerResult;

  int deviceUuidCalls = 0;
  int loginCalls = 0;
  int registerCalls = 0;
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
        const ApiResult.success(UserModel(
          id: 'u1',
          email: 'student@civilsalt.com',
          firstName: 'Jane',
          lastName: 'Doe',
          role: 'student',
        ));
  }

  @override
  Future<ApiResult<UserModel>> register({
    required String email,
    required String firstName,
    required String lastName,
    required String registrationNumber,
    required String role,
    required String password,
    required String passwordConfirm,
  }) async {
    registerCalls++;
    return registerResult ??
        const ApiResult.success(UserModel(
          id: 'u2',
          email: 'lecturer@civilsalt.com',
          firstName: 'Jane',
          lastName: 'Doe',
          role: 'lecturer',
        ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AuthController', () {
    test('marks the user authenticated when login succeeds', () async {
      final service = FakeAuthService();
      final controller = AuthController(service: service);

      final ok = await controller.login('student@civilsalt.com', 'password123');

      expect(ok, isTrue);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.user?.email, 'student@civilsalt.com');
      expect(service.loginCalls, 1);
      expect(service.deviceUuidCalls, 1);
    });

    test('captures the error and resets auth state when login fails', () async {
      final service = FakeAuthService(
        loginResult: const ApiResult.failure('Invalid credentials'),
      );
      final controller = AuthController(service: service);

      final ok = await controller.login('student@civilsalt.com', 'wrong-password');

      expect(ok, isFalse);
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.error, 'Invalid credentials');
      expect(controller.user, isNull);
    });

    test('explains certificate failures without falsely blaming the internet', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/auth/register/'),
        type: DioExceptionType.badCertificate,
        message: 'CERTIFICATE_VERIFY_FAILED: certificate has expired',
      );

      expect(
        parseApiError(err),
        contains('certificate'),
      );
      expect(parseApiError(err), isNot(contains('Check your internet connection')));
    });

    test('does not mislabel a server-connection issue as no internet', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/auth/login/'),
        type: DioExceptionType.connectionError,
        message: 'Connection closed before full header was received',
      );

      final text = parseApiError(err);
      expect(text, contains('server'));
      expect(text, isNot(contains('Check your internet connection')));
      expect(text, isNot(contains('No internet')));
    });

    test('describes timeouts without blaming the internet when the backend is slow', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/auth/logout/'),
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timeout',
      );

      final text = parseApiError(err);
      expect(text, contains('timed out'));
      expect(text, isNot(contains('Check your internet connection')));
      expect(text, isNot(contains('No internet')));
    });

    test('marks registration successful when the service accepts the account',
        () async {
      final service = FakeAuthService();
      final controller = AuthController(service: service);

      final ok = await controller.register(
        email: 'lecturer@civilsalt.com',
        firstName: 'Jane',
        lastName: 'Doe',
        registrationNumber: 'UBa25EP188',
        role: 'lecturer',
        password: 'password123',
        passwordConfirm: 'password123',
      );

      expect(ok, isTrue);
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.error, isNull);
      expect(service.registerCalls, 1);
    });

    test('exposes the registration service error', () async {
      final service = FakeAuthService(
        registerResult: const ApiResult.failure('Email already registered.'),
      );
      final controller = AuthController(service: service);

      final ok = await controller.register(
        email: 'lecturer@civilsalt.com',
        firstName: 'Jane',
        lastName: 'Doe',
        registrationNumber: 'UBa25EP188',
        role: 'lecturer',
        password: 'password123',
        passwordConfirm: 'password123',
      );

      expect(ok, isFalse);
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.error, 'Email already registered.');
    });
  });
}
