class AttendanceRecordModel {
  final String id;
  final String studentId;
  final String sessionId;
  final String deviceUuid;
  final String scanSource;
  final String scannedAt;
  final String? syncedAt;
  final String idempotencyKey;
  final String? hmacSignature;
  final String? qrPayload;
  final bool pendingSync;

  const AttendanceRecordModel({
    required this.id,
    required this.studentId,
    required this.sessionId,
    required this.deviceUuid,
    required this.scanSource,
    required this.scannedAt,
    this.syncedAt,
    required this.idempotencyKey,
    this.hmacSignature,
    this.qrPayload,
    this.pendingSync = true,
  });

  bool get isSynced => !pendingSync && syncedAt != null;

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) =>
      AttendanceRecordModel(
        id: json['id'] ?? '',
        studentId: json['student']?.toString() ?? '',
        sessionId: json['session']?.toString() ?? '',
        deviceUuid: json['device_uuid'] ?? '',
        scanSource: json['scan_source'] ?? 'offline',
        scannedAt: json['scanned_at'] ?? DateTime.now().toIso8601String(),
        syncedAt: json['synced_at'],
        idempotencyKey: json['idempotency_key'] ?? '',
        hmacSignature: json['hmac_signature'],
        qrPayload: json['qr_payload'],
        pendingSync: json['pending_sync'] == 1 || json['pending_sync'] == true,
      );

  factory AttendanceRecordModel.fromDb(Map<String, dynamic> row) =>
      AttendanceRecordModel(
        id: row['id'],
        studentId: row['student_id'],
        sessionId: row['session_id'],
        deviceUuid: row['device_uuid'],
        scanSource: row['scan_source'],
        scannedAt: row['scanned_at'],
        syncedAt: row['synced_at'],
        idempotencyKey: row['idempotency_key'],
        hmacSignature: row['hmac_signature'],
        qrPayload: row['qr_payload'],
        pendingSync: row['pending_sync'] == 1,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'student_id': studentId,
        'session_id': sessionId,
        'device_uuid': deviceUuid,
        'scan_source': scanSource,
        'scanned_at': scannedAt,
        'synced_at': syncedAt,
        'idempotency_key': idempotencyKey,
        'hmac_signature': hmacSignature,
        'qr_payload': qrPayload,
        'pending_sync': pendingSync ? 1 : 0,
      };

  Map<String, dynamic> toSyncPayload() => {
        'session_id': sessionId,
        'device_uuid': deviceUuid,
        'scanned_at': scannedAt,
        'idempotency_key': idempotencyKey,
        'hmac_signature': hmacSignature ?? '',
        'qr_payload': qrPayload ?? '',
      };
}
