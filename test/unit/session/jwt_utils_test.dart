// ignore_for_file: lines_longer_than_80_chars jwt tokens can'be broken

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('JwtUtils Tests', () {
    // Note: These are valid JWT format but not cryptographically signed
    // They're used only to test parsing logic, not signature verification

    // Payload: {"exp":9999999999,"sub":"user123","permissions":["read","write"],"is_admin":true}
    const validToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjk5OTk5OTk5OTksInN1YiI6InVzZXIxMjMiLCJwZXJtaXNzaW9ucyI6WyJyZWFkIiwid3JpdGUiXSwiaXNfYWRtaW4iOnRydWV9.anysignature';

    // Payload: {"exp":1,"sub":"user123"}
    const expiredToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjEsInN1YiI6InVzZXIxMjMifQ.anysignature';

    const invalidToken = 'invalid.token.format.extra';
    const malformedToken = 'not.valid';

    group('parseToken', () {
      test('parses valid token correctly', () {
        final payload = JwtUtils.parseToken(validToken);

        expect(payload, isNotNull);
        expect(payload?.expiresAt, 9999999999);
        expect(payload?.userId, 'user123');
        expect(payload?.permissions, ['read', 'write']);
        expect(payload?.isAdmin, true);
      });

      test('handles token without optional claims', () {
        const tokenWithoutOptional =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjk5OTk5OTk5OTl9.signature';
        final payload = JwtUtils.parseToken(tokenWithoutOptional);

        expect(payload, isNotNull);
        expect(payload?.expiresAt, 9999999999);
        expect(payload?.userId, isNull);
        expect(payload?.permissions, <String>[]);
        expect(payload?.isAdmin, false);
      });

      test('returns null for token with invalid structure', () {
        final payload = JwtUtils.parseToken(invalidToken);
        expect(payload, isNull);
      });

      test('returns null for malformed token', () {
        final payload = JwtUtils.parseToken(malformedToken);
        expect(payload, isNull);
      });

      test('returns null for empty string', () {
        final payload = JwtUtils.parseToken('');
        expect(payload, isNull);
      });
    });

    group('isValidJwtFormat', () {
      test('validates correct JWT format', () {
        final isValid = JwtUtils.isValidJwtFormat(validToken);
        expect(isValid, true);
      });

      test('rejects token with too many parts', () {
        final isValid = JwtUtils.isValidJwtFormat(invalidToken);
        expect(isValid, false);
      });

      test('rejects token with too few parts', () {
        final isValid = JwtUtils.isValidJwtFormat(malformedToken);
        expect(isValid, false);
      });

      test('rejects empty string', () {
        final isValid = JwtUtils.isValidJwtFormat('');
        expect(isValid, false);
      });

      test('rejects token with empty part', () {
        final isValid = JwtUtils.isValidJwtFormat('...');
        expect(isValid, false);
      });
    });

    group('JwtPayload', () {
      test('isExpired returns true for expired token', () {
        final payload = JwtUtils.parseToken(expiredToken);
        expect(payload?.isExpired, true);
      });

      test('isExpired returns false for valid token', () {
        final payload = JwtUtils.parseToken(validToken);
        expect(payload?.isExpired, false);
      });

      test('expiresWithin returns true for soon-to-expire token', () {
        final payload = JwtUtils.parseToken(expiredToken);
        expect(payload?.expiresWithin(const Duration(hours: 1)), true);
      });

      test('expiresWithin returns false for token with time remaining', () {
        final payload = JwtUtils.parseToken(validToken);
        expect(payload?.expiresWithin(const Duration(hours: 1)), false);
      });

      test('expiresWithin returns true for null expiresAt', () {
        const payload = JwtPayload();
        expect(payload.expiresWithin(const Duration(minutes: 1)), true);
      });

      test('timeRemaining returns null for null expiresAt', () {
        const payload = JwtPayload();
        expect(payload.timeRemaining, isNull);
      });

      test('timeRemaining returns Duration(zero) for expired token', () {
        final payload = JwtUtils.parseToken(expiredToken);
        expect(payload?.timeRemaining, Duration.zero);
      });

      test('timeRemaining returns positive duration for valid token', () {
        final payload = JwtUtils.parseToken(validToken);
        final remaining = payload?.timeRemaining;
        expect(remaining, isNotNull);
        expect(remaining!.inSeconds, greaterThan(0));
      });
    });
  });
}
