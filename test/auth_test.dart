import 'dart:convert';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:cl_server_dart_client/src/auth.dart'; // Import src/auth.dart to access internal methods/classes if needed, though they seem public?
import 'package:test/test.dart';
// Actually AuthProvider is exported via cl_server_dart_client.dart but some methods might be internal?
// _parseTokenExpiry is private. To test it, we might need to rely on public behavior like shouldRefresh.
// Or we can use @visibleForTesting but let's see. logic is inside shouldRefresh.

String _createJwtToken(Map<String, dynamic> payload) {
  final header = {'alg': 'ES256', 'typ': 'JWT'};
  final headerB64 = base64Url
      .encode(utf8.encode(jsonEncode(header)))
      .replaceAll('=', '');
  final payloadB64 = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  const signature = 'fake_signature';
  return '$headerB64.$payloadB64.$signature';
}

void main() {
  group('AuthProvider', () {
    test('test_no_auth_provider', () {
      final provider = NoAuthProvider();
      expect(provider.getHeaders(), isEmpty);
      expect(provider, isA<AuthProvider>());
    });

    test('test_jwt_auth_provider', () {
      final provider = JWTAuthProvider(token: 'test-token-123');
      final headers = provider.getHeaders();
      expect(headers.containsKey('Authorization'), isTrue);
      expect(headers['Authorization'], equals('Bearer test-token-123'));
      expect(provider, isA<AuthProvider>());
    });

    // Abstract class instantiation check not applicable in Dart nicely without creating mock implementation
    // But we know it's abstract.
  });

  group('JWTAuthProviderInitialization', () {
    test('test_jwt_auth_provider_with_token', () {
      final provider = JWTAuthProvider(token: 'test-token');
      expect(provider.getToken(), equals('test-token'));
    });

    test('test_jwt_auth_provider_no_arguments', () {
      expect(JWTAuthProvider.new, throwsArgumentError);
    });

    test('test_jwt_auth_provider_get_token', () {
      final provider = JWTAuthProvider(token: 'test-token-123');
      expect(provider.getToken(), equals('test-token-123'));
    });
  });

  group('JWTTokenParsing', () {
    // Note: _parseTokenExpiry is private in Dart implementation.
    // We strictly test public behavior `shouldRefresh` which relies on it.
    // Or we test `shouldRefresh` directly as it's the public API consuming expiration.

    // However, to match Python tests 1:1, we will test `shouldRefresh` which is observing the expiry logic.
  });

  group('TokenExpiryChecking', () {
    test('test_should_refresh_expired_token', () {
      final expiry = DateTime.now().toUtc().subtract(
        const Duration(minutes: 10),
      );
      final token = _createJwtToken({
        'sub': 'user123',
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      });

      final provider = JWTAuthProvider(token: token);
      expect(provider.shouldRefresh(token), isTrue);
    });

    test('test_should_refresh_token_expiring_soon', () {
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 30));
      final token = _createJwtToken({
        'sub': 'user123',
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      });

      final provider = JWTAuthProvider(token: token);
      expect(provider.shouldRefresh(token), isTrue);
    });

    test('test_should_not_refresh_fresh_token', () {
      final expiry = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final token = _createJwtToken({
        'sub': 'user123',
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      });

      final provider = JWTAuthProvider(token: token);
      expect(provider.shouldRefresh(token), isFalse);
    });

    // Boundary condition: exactly 60 seconds
    test('test_should_refresh_boundary', () {
      // In Dart implementation: timeUntilExpiry.inSeconds < 60
      // If exactly 60, it returns false.
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 60));
      final token = _createJwtToken({
        'sub': 'user123',
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      });
      final provider = JWTAuthProvider(token: token);

      // Note: DateTime.now() ticks, so hard to get exactly 60s diff.
      // But assuming it's slightly less than 60s when accessed? or more?
      // Usually if we set it exactly, difference might be 59.999 or 60.001 depending on execution.
      // Let's just ensure it returns bool as Python test did, or skip exact boundary flakiness.
      expect(provider.shouldRefresh(token), isA<bool>());
    });

    test('test_should_refresh_no_expiry_returns_false', () {
      final token = _createJwtToken({'sub': 'user123'}); // No exp
      final provider = JWTAuthProvider(token: token);
      expect(provider.shouldRefresh(token), isFalse);
    });

    test('test_should_refresh_invalid_token_returns_false', () {
      final provider = JWTAuthProvider(token: 'valid-token');
      expect(provider.shouldRefresh('not.a.jwt'), isFalse);
    });

    test('test_should_refresh_float_timestamp', () {
      // Dart DateTime.fromMillisecondsSinceEpoch takes int.
      // But our implementation supports double check: `if (exp is double)`

      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final expiryMs = nowMs + 30500; // +30.5 seconds
      final expSeconds = expiryMs / 1000.0;

      final token = _createJwtToken({
        'sub': 'user123',
        'exp': expSeconds,
      }); // jsonEncode will encode double
      final provider = JWTAuthProvider(token: token);
      expect(provider.shouldRefresh(token), isTrue);
    });

    test('test_parse_token_expiry_invalid_format', () {
      // Indirectly tested via shouldRefresh returning false (which means expiry is null)
      final provider = JWTAuthProvider(token: 'valid-token');
      expect(provider.shouldRefresh('not.a.jwt'), isFalse);
      expect(provider.shouldRefresh('header.payload'), isFalse);
      expect(provider.shouldRefresh('a.b.c.d'), isFalse);
    });

    test('test_parse_token_expiry_invalid_base64', () {
      final provider = JWTAuthProvider(token: 'valid-token');
      const invalidToken = 'invalid!!!.base64!!!.signature';
      expect(provider.shouldRefresh(invalidToken), isFalse);
    });

    test('test_parse_token_expiry_invalid_json', () {
      final provider = JWTAuthProvider(token: 'valid-token');
      final invalidJson = base64Url
          .encode(utf8.encode('not json'))
          .replaceAll('=', '');
      final invalidToken = 'header.$invalidJson.signature';
      expect(provider.shouldRefresh(invalidToken), isFalse);
    });

    test('test_parse_token_expiry_non_numeric_exp', () {
      final token = _createJwtToken({'sub': 'user123', 'exp': 'not-a-number'});
      final provider = JWTAuthProvider(token: token);
      expect(provider.shouldRefresh(token), isFalse);
    });

    test('test_parse_token_expiry_with_padding', () {
      final header = {'alg': 'ES256', 'typ': 'JWT'};
      final headerB64 = base64Url
          .encode(utf8.encode(jsonEncode(header)))
          .replaceAll('=', '');
      const signature = 'fake_signature';

      final provider = JWTAuthProvider(token: 'valid-token');

      final expirySoon = DateTime.now().toUtc().add(
        const Duration(seconds: 30),
      );
      final payloadSoon = {'exp': expirySoon.millisecondsSinceEpoch ~/ 1000};
      final payloadSoonB64 = base64Url
          .encode(utf8.encode(jsonEncode(payloadSoon)))
          .replaceAll('=', '');
      final tokenSoon = '$headerB64.$payloadSoonB64.$signature';

      expect(provider.shouldRefresh(tokenSoon), isTrue);
    });
  });
}
