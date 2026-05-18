import 'package:flutter_test/flutter_test.dart';
import 'package:smart_attendance/core/utils/qr_utils.dart';

void main() {
  group('QrUtils', () {
    const secret = 'test_secret_key_for_unit_tests';
    const sessionId = 'test-session-id-12345';
    const courseCode = 'CPE501';

    test('generates and verifies a valid payload', () {
      final payload = QrUtils.generateQrPayload(
        sessionId: sessionId,
        courseCode: courseCode,
        secret: secret,
        validitySeconds: 900,
      );
      final result = QrUtils.verifyQrPayload(payload, secret);
      expect(result.ok, true);
      expect(result.reason, 'ok');
    });

    test('rejects tampered payload', () {
      final payload = QrUtils.generateQrPayload(
        sessionId: sessionId,
        courseCode: courseCode,
        secret: secret,
        validitySeconds: 900,
      );
      final tampered = payload.replaceAll(courseCode, 'FAKE999');
      final result = QrUtils.verifyQrPayload(tampered, secret);
      expect(result.ok, false);
      expect(result.reason, 'invalid_hmac');
    });

    test('rejects expired payload', () {
      final payload = QrUtils.generateQrPayload(
        sessionId: sessionId,
        courseCode: courseCode,
        secret: secret,
        validitySeconds: -100,
      );
      final result = QrUtils.verifyQrPayload(payload, secret, clockSkewTolerance: 0);
      expect(result.ok, false);
      expect(result.reason, 'expired');
    });

    test('rejects wrong secret', () {
      final payload = QrUtils.generateQrPayload(
        sessionId: sessionId,
        courseCode: courseCode,
        secret: secret,
        validitySeconds: 900,
      );
      final result = QrUtils.verifyQrPayload(payload, 'wrong_secret');
      expect(result.ok, false);
      expect(result.reason, 'invalid_hmac');
    });

    test('rejects invalid format', () {
      final result = QrUtils.verifyQrPayload('not|valid', secret);
      expect(result.ok, false);
      expect(result.reason, 'invalid_format');
    });

    test('parseQrPayload returns null for bad format', () {
      expect(QrUtils.parseQrPayload('bad'), null);
      expect(QrUtils.parseQrPayload('a|b|c'), null);
    });

    test('computeHmac is deterministic', () {
      final h1 = QrUtils.computeHmac('payload', secret);
      final h2 = QrUtils.computeHmac('payload', secret);
      expect(h1, h2);
    });

    test('different payloads produce different HMACs', () {
      final h1 = QrUtils.computeHmac('payload1', secret);
      final h2 = QrUtils.computeHmac('payload2', secret);
      expect(h1, isNot(h2));
    });
  });
}
