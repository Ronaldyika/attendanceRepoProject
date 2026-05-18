class CourseModel {
  final String id;
  final String code;
  final String title;
  final String lecturerId;
  final String lecturerName;
  final int enrolledCount;
  final bool isActive;
  final String? createdAt;

  const CourseModel({
    required this.id,
    required this.code,
    required this.title,
    required this.lecturerId,
    required this.lecturerName,
    this.enrolledCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) => CourseModel(
        id: json['id'] ?? '',
        code: json['code'] ?? '',
        title: json['title'] ?? '',
        lecturerId: json['lecturer']?.toString() ?? '',
        lecturerName: json['lecturer_name'] ?? '',
        enrolledCount: json['enrolled_count'] ?? 0,
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'lecturer': lecturerId,
        'lecturer_name': lecturerName,
        'enrolled_count': enrolledCount,
        'is_active': isActive,
        'created_at': createdAt,
      };
}
