class SessionModel {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String createdBy;
  final String lecturerName;
  final String status;
  final String startedAt;
  final String expiresAt;
  final String? closedAt;
  final String? venue;
  final String? notes;
  final String? sessionSecret;
  final String? qrPayload;
  final int? expiryUnix;
  final int attendanceCount;

  const SessionModel({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.createdBy,
    required this.lecturerName,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    this.closedAt,
    this.venue,
    this.notes,
    this.sessionSecret,
    this.qrPayload,
    this.expiryUnix,
    this.attendanceCount = 0,
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get isExpired {
    if (expiryUnix == null) return status == 'expired';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now > expiryUnix!;
  }

  DateTime get expiresAtDateTime => DateTime.parse(expiresAt);
  DateTime get startedAtDateTime => DateTime.parse(startedAt);

  Duration get remainingTime {
    if (expiryUnix == null) return Duration.zero;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = expiryUnix! - now;
    return remaining > 0 ? Duration(seconds: remaining) : Duration.zero;
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
        id: json['id'] ?? '',
        courseId: json['course']?.toString() ?? '',
        courseCode: json['course_code'] ?? '',
        courseTitle: json['course_title'] ?? '',
        createdBy: json['created_by']?.toString() ?? '',
        lecturerName: json['lecturer_name'] ?? '',
        status: json['status'] ?? 'open',
        startedAt: json['started_at'] ?? DateTime.now().toIso8601String(),
        expiresAt: json['expires_at'] ?? DateTime.now().toIso8601String(),
        closedAt: json['closed_at'],
        venue: json['venue'],
        notes: json['notes'],
        sessionSecret: json['session_secret'],
        qrPayload: json['qr_payload'],
        expiryUnix: json['expiry_unix'],
        attendanceCount: json['attendance_count'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'course': courseId,
        'course_code': courseCode,
        'course_title': courseTitle,
        'created_by': createdBy,
        'lecturer_name': lecturerName,
        'status': status,
        'started_at': startedAt,
        'expires_at': expiresAt,
        'closed_at': closedAt,
        'venue': venue,
        'notes': notes,
        'session_secret': sessionSecret,
        'qr_payload': qrPayload,
        'expiry_unix': expiryUnix,
        'attendance_count': attendanceCount,
      };

  SessionModel copyWith({String? status, String? closedAt, int? attendanceCount, String? qrPayload, int? expiryUnix}) =>
      SessionModel(
        id: id, courseId: courseId, courseCode: courseCode,
        courseTitle: courseTitle, createdBy: createdBy, lecturerName: lecturerName,
        status: status ?? this.status,
        startedAt: startedAt, expiresAt: expiresAt,
        closedAt: closedAt ?? this.closedAt,
        venue: venue, notes: notes, sessionSecret: sessionSecret,
        qrPayload: qrPayload ?? this.qrPayload,
        expiryUnix: expiryUnix ?? this.expiryUnix,
        attendanceCount: attendanceCount ?? this.attendanceCount,
      );
}
