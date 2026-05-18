import 'dart:convert';
import 'package:crypto/crypto.dart';

/// QR Payload Format:  session_id|course_code|expiry_unix|hmac_sha256
class QrUtils {
  QrUtils._();

  static String computeHmac(String payloadBase, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payloadBase);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  static String buildPayloadBase(String sessionId, String courseCode, int expiryUnix) =>
      '$sessionId|$courseCode|$expiryUnix';

  static String generateQrPayload({
    required String sessionId,
    required String courseCode,
    required String secret,
    int validitySeconds = 900,
  }) {
    final expiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + validitySeconds;
    final base = buildPayloadBase(sessionId, courseCode, expiry);
    final sig = computeHmac(base, secret);
    return '$base|$sig';
  }

  static QrParseResult? parseQrPayload(String raw) {
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    final expiry = int.tryParse(parts[2]);
    if (expiry == null) return null;
    return QrParseResult(
      sessionId: parts[0],
      courseCode: parts[1],
      expiryUnix: expiry,
      signature: parts[3],
    );
  }

  static QrVerifyResult verifyQrPayload(
    String raw,
    String secret, {
    int clockSkewTolerance = 300,
  }) {
    final parsed = parseQrPayload(raw);
    if (parsed == null) return QrVerifyResult(ok: false, reason: 'invalid_format');

    final base = buildPayloadBase(parsed.sessionId, parsed.courseCode, parsed.expiryUnix);
    final expected = computeHmac(base, secret);

    if (expected != parsed.signature) {
      return QrVerifyResult(ok: false, reason: 'invalid_hmac');
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now > parsed.expiryUnix + clockSkewTolerance) {
      return QrVerifyResult(ok: false, reason: 'expired');
    }

    return QrVerifyResult(ok: true, reason: 'ok', parsed: parsed);
  }
}

class QrParseResult {
  final String sessionId;
  final String courseCode;
  final int expiryUnix;
  final String signature;

  const QrParseResult({
    required this.sessionId,
    required this.courseCode,
    required this.expiryUnix,
    required this.signature,
  });
}

class QrVerifyResult {
  final bool ok;
  final String reason;
  final QrParseResult? parsed;
  const QrVerifyResult({required this.ok, required this.reason, this.parsed});
}
