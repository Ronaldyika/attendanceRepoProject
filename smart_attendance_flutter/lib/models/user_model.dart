import 'dart:convert';

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? registrationNumber;
  final String role;
  final String? deviceUuid;
  final String? deviceBoundAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.registrationNumber,
    required this.role,
    this.deviceUuid,
    this.deviceBoundAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isLecturer => role == 'lecturer';
  bool get isStudent => role == 'student';
  bool get isAdmin => role == 'admin';
  bool get isDeviceBound => deviceUuid != null && deviceUuid!.isNotEmpty;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? '',
        email: json['email'] ?? '',
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        registrationNumber: json['registration_number'],
        role: json['role'] ?? 'student',
        deviceUuid: json['device_uuid'],
        deviceBoundAt: json['device_bound_at'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'registration_number': registrationNumber,
        'role': role,
        'device_uuid': deviceUuid,
        'device_bound_at': deviceBoundAt,
      };

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String jsonStr) =>
      UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  UserModel copyWith({
    String? deviceUuid,
    String? deviceBoundAt,
    String? registrationNumber,
  }) =>
      UserModel(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        registrationNumber: registrationNumber ?? this.registrationNumber,
        role: role,
        deviceUuid: deviceUuid ?? this.deviceUuid,
        deviceBoundAt: deviceBoundAt ?? this.deviceBoundAt,
      );
}
