import 'dart:convert';

import 'package:cl_server_dart_client/src/auth.dart';
import 'package:cl_server_dart_client/src/clients/auth_client.dart';
import 'package:cl_server_dart_client/src/models/auth_models.dart';
import 'package:cl_server_dart_client/src/mqtt_monitor.dart';
import 'package:cl_server_dart_client/src/server_config.dart';
import 'package:cl_server_dart_client/src/session_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAuthClient extends Mock implements AuthClient {}

class MockMQTTJobMonitor extends Mock implements MQTTJobMonitor {}

String _createJwtToken(Map<String, dynamic> payload) {
  final header = {'alg': 'ES256', 'typ': 'JWT'};
  final headerB64 = base64Url
      .encode(utf8.encode(jsonEncode(header)))
      .replaceAll('=', '');
  final payloadB64 = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  const signatureB64 = 'fake_signature';
  return '$headerB64.$payloadB64.$signatureB64';
}

ServerConfig _createTestServerConfig() {
  return const ServerConfig(
    authUrl: 'http://auth.local:8010',
    computeUrl: 'http://compute.local:8012',
    storeUrl: 'http://store.local:8011',
    mqttUrl: 'mqtt://mqtt.local:1883',
  );
}

void main() {
  group('SessionManager', () {
    late MockAuthClient mockAuthClient;

    setUp(() {
      mockAuthClient = MockAuthClient();

      // Default stubbing for close
      when(() => mockAuthClient.close()).thenAnswer((_) async {});
    });

    group('TestSessionManagerInitialization', () {
      test('test_session_manager_default_config', () {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        expect(session.serverConfig, isNotNull);
        expect(session.authClient, equals(mockAuthClient));
        expect(session.isAuthenticated, isFalse);
      });

      test('test_session_manager_custom_base_url', () {
        // Test that serverConfig is used to create the AuthClient with correct baseUrl
        const config = ServerConfig(
          authUrl: 'https://custom-auth.example.com',
          computeUrl: 'http://compute.local:8012',
          storeUrl: 'http://store.local:8011',
          mqttUrl: 'mqtt://mqtt.local:1883',
        );
        final session = SessionManager(
          serverConfig: config,
        );
        expect(
          session.authClient.baseUrl,
          equals('https://custom-auth.example.com'),
        );
      });
    });

    group('TestSessionManagerLoginLogout', () {
      test('test_login_success', () async {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        final now = DateTime.now().toUtc();
        final tokenResponse = TokenResponse(
          accessToken: 'test_token_123',
          tokenType: 'bearer',
        );
        final userResponse = UserResponse(
          id: 1,
          username: 'testuser',
          createdAt: now,
          permissions: ['read:jobs'],
        );

        when(
          () => mockAuthClient.login('testuser', 'testpass'),
        ).thenAnswer((_) async => tokenResponse);
        when(
          () => mockAuthClient.getCurrentUser('test_token_123'),
        ).thenAnswer((_) async => userResponse);

        final result = await session.login('testuser', 'testpass');

        verify(() => mockAuthClient.login('testuser', 'testpass')).called(1);
        verify(() => mockAuthClient.getCurrentUser('test_token_123')).called(1);
        expect(result, equals(tokenResponse));
        expect(session.isAuthenticated, isTrue);
        expect(session.getToken(), equals('test_token_123'));
        expect(await session.getCurrentUser(), equals(userResponse));
      });

      test('test_login_invalid_credentials', () async {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        when(
          () => mockAuthClient.login('invalid', 'invalid'),
        ).thenThrow(Exception('401 Unauthorized'));

        expect(() => session.login('invalid', 'invalid'), throwsException);
        expect(session.isAuthenticated, isFalse);
      });

      test('test_logout', () async {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );

        // Setup authenticated state via login
        when(() => mockAuthClient.login(any(), any())).thenAnswer(
          (_) async => TokenResponse(accessToken: 'tok', tokenType: 'b'),
        );
        when(() => mockAuthClient.getCurrentUser(any())).thenAnswer(
          (_) async => UserResponse(
            id: 1,
            username: 'u',
            createdAt: DateTime.now(),
            permissions: [],
          ),
        );

        await session.login('u', 'p');
        expect(session.isAuthenticated, isTrue);

        await session.logout();
        expect(session.isAuthenticated, isFalse);
        expect(session.getToken, throwsStateError);
      });

      test('test_is_authenticated', () async {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        expect(session.isAuthenticated, isFalse);

        when(() => mockAuthClient.login(any(), any())).thenAnswer(
          (_) async => TokenResponse(accessToken: 'tok', tokenType: 'b'),
        );
        when(() => mockAuthClient.getCurrentUser(any())).thenAnswer(
          (_) async => UserResponse(
            id: 1,
            username: 'u',
            createdAt: DateTime.now(),
            permissions: [],
          ),
        );

        await session.login('u', 'p');
        expect(session.isAuthenticated, isTrue);

        await session.logout();
        expect(session.isAuthenticated, isFalse);
      });
    });

    group('TestSessionManagerUserInfo', () {
      test('test_get_current_user_cached', () async {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        final userResponse = UserResponse(
          id: 1,
          username: 'testuser',
          createdAt: DateTime.now(),
          permissions: ['read:jobs'],
        );

        when(() => mockAuthClient.login(any(), any())).thenAnswer(
          (_) async => TokenResponse(accessToken: 'tok', tokenType: 'b'),
        );
        when(
          () => mockAuthClient.getCurrentUser('tok'),
        ).thenAnswer((_) async => userResponse);

        await session.login('u', 'p');

        clearInteractions(mockAuthClient);
        final user = await session.getCurrentUser();
        expect(user!.username, equals('testuser'));
        verifyNever(() => mockAuthClient.getCurrentUser(any()));
      });

      test('test_get_current_user_fetch_from_server', () async {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        final userResponse = UserResponse(
          id: 1,
          username: 'testuser',
          createdAt: DateTime.now(),
          permissions: ['read:jobs'],
        );

        // Login but user fetch fails in constructor
        when(() => mockAuthClient.login(any(), any())).thenAnswer(
          (_) async => TokenResponse(accessToken: 'tok', tokenType: 'b'),
        );
        when(
          () => mockAuthClient.getCurrentUser('tok'),
        ).thenThrow(Exception('Initial failure'));

        await session.login('u', 'p');
        clearInteractions(mockAuthClient);

        // Next fetch succeeds
        when(
          () => mockAuthClient.getCurrentUser('tok'),
        ).thenAnswer((_) async => userResponse);
        final user = await session.getCurrentUser();
        expect(user, equals(userResponse));
        verify(() => mockAuthClient.getCurrentUser('tok')).called(1);
      });

      test('test_get_current_user_guest_mode', () async {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        expect(await session.getCurrentUser(), isNull);
      });
    });

    group('TestSessionManagerTokenManagement', () {
      test('test_get_token_authenticated', () async {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        when(() => mockAuthClient.login(any(), any())).thenAnswer(
          (_) async =>
              TokenResponse(accessToken: 'test_token_123', tokenType: 'b'),
        );
        await session.login('u', 'p');
        expect(session.getToken(), equals('test_token_123'));
      });

      test('test_get_token_not_authenticated', () {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        expect(session.getToken, throwsStateError);
      });

      test('test_get_valid_token_fresh_token', () async {
        final expiry = DateTime.now().toUtc().add(const Duration(minutes: 5));
        final token = _createJwtToken({
          'sub': 'user123',
          'exp': expiry.millisecondsSinceEpoch ~/ 1000,
        });

        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        when(() => mockAuthClient.login(any(), any())).thenAnswer(
          (_) async => TokenResponse(accessToken: token, tokenType: 'b'),
        );
        await session.login('u', 'p');

        final result = await session.getValidToken();
        expect(result, equals(token));
        verifyNever(() => mockAuthClient.refreshToken(any()));
      });

      test('test_get_valid_token_with_refresh', () async {
        final oldExpiry = DateTime.now().toUtc().add(
          const Duration(seconds: 30),
        );
        final oldToken = _createJwtToken({
          'sub': 'user123',
          'exp': oldExpiry.millisecondsSinceEpoch ~/ 1000,
        });

        final newExpiry = DateTime.now().toUtc().add(const Duration(hours: 1));
        final newToken = _createJwtToken({
          'sub': 'user123',
          'exp': newExpiry.millisecondsSinceEpoch ~/ 1000,
        });

        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        when(() => mockAuthClient.login(any(), any())).thenAnswer(
          (_) async => TokenResponse(accessToken: oldToken, tokenType: 'b'),
        );
        await session.login('u', 'p');

        when(() => mockAuthClient.refreshToken(oldToken)).thenAnswer(
          (_) async => TokenResponse(accessToken: newToken, tokenType: 'b'),
        );

        final result = await session.getValidToken();
        expect(result, equals(newToken));
        expect(session.getToken(), equals(newToken));
        verify(() => mockAuthClient.refreshToken(oldToken)).called(1);
      });

      test('test_get_valid_token_not_authenticated', () {
        final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
        expect(session.getValidToken, throwsStateError);
      });
      group('TestSessionManagerComputeClient', () {
        test('test_create_compute_client_authenticated', () async {
          final expiry = DateTime.now().toUtc().add(const Duration(minutes: 5));
          final token = _createJwtToken({
            'sub': 'user123',
            'exp': expiry.millisecondsSinceEpoch ~/ 1000,
          });

          final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
          when(() => mockAuthClient.login(any(), any())).thenAnswer(
            (_) async => TokenResponse(accessToken: token, tokenType: 'b'),
          );
          await session.login('u', 'p');

          final mockMqtt = MockMQTTJobMonitor();
          when(() => mockMqtt.isConnected).thenReturn(true);

          final client = session.createComputeClient(mqttMonitor: mockMqtt);
          expect(client, isNotNull);
          expect(client.auth, isA<JWTAuthProvider>());
          expect(client.baseUrl, equals(session.serverConfig.computeUrl));
        });

        test('test_create_compute_client_guest_mode', () {
          final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
          final mockMqtt = MockMQTTJobMonitor();
          when(() => mockMqtt.isConnected).thenReturn(true);

          final client = session.createComputeClient(mqttMonitor: mockMqtt);
          expect(client, isNotNull);
          expect(client.auth, isA<NoAuthProvider>());
          expect(client.baseUrl, equals(session.serverConfig.computeUrl));
        });

        test('test_create_compute_client_uses_config', () {
          const config = ServerConfig(
            authUrl: 'http://auth.local:8010',
            computeUrl: 'https://custom-compute.example.com',
            storeUrl: 'http://store.local:8011',
            mqttUrl: 'mqtt://custom-broker:8883',
          );
          final session = SessionManager(
            serverConfig: config,
            authClient: mockAuthClient,
          );
          expect(session.serverConfig, equals(config));

          final mockMqtt = MockMQTTJobMonitor();
          when(() => mockMqtt.isConnected).thenReturn(true);
          final client = session.createComputeClient(mqttMonitor: mockMqtt);
          expect(client.baseUrl, equals('https://custom-compute.example.com'));
        });
      });

      group('TestSessionManagerContextManager', () {
        test('test_manual_close', () async {
          final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
          await session.close();
          verify(() => mockAuthClient.close()).called(1);
        });
      });

      group('TestSessionManagerIntegration', () {
        test('test_full_login_workflow', () async {
          final session = SessionManager(
          serverConfig: _createTestServerConfig(),
          authClient: mockAuthClient,
        );
          final now = DateTime.now().toUtc();

          final soonExpiry = now.add(const Duration(seconds: 30));
          final initialToken = _createJwtToken({
            'sub': 'user123',
            'exp': soonExpiry.millisecondsSinceEpoch ~/ 1000,
          });

          final farExpiry = now.add(const Duration(hours: 1));
          final refreshedToken = _createJwtToken({
            'sub': 'user123',
            'exp': farExpiry.millisecondsSinceEpoch ~/ 1000,
          });

          // Step 1: Login
          when(() => mockAuthClient.login('testuser', 'testpass')).thenAnswer(
            (_) async =>
                TokenResponse(accessToken: initialToken, tokenType: 'bearer'),
          );
          final userResponse = UserResponse(
            id: 1,
            username: 'testuser',
            createdAt: now,
            permissions: ['read:jobs'],
          );
          when(
            () => mockAuthClient.getCurrentUser(initialToken),
          ).thenAnswer((_) async => userResponse);

          await session.login('testuser', 'testpass');
          expect(session.isAuthenticated, isTrue);

          // Step 2: Get user info
          final user = await session.getCurrentUser();
          expect(user!.username, equals('testuser'));

          // Step 3: Get valid token (triggers refresh)
          when(() => mockAuthClient.refreshToken(initialToken)).thenAnswer(
            (_) async =>
                TokenResponse(accessToken: refreshedToken, tokenType: 'bearer'),
          );
          final token = await session.getValidToken();
          expect(token, equals(refreshedToken));

          // Step 4: Create compute client
          final mockMqtt = MockMQTTJobMonitor();
          when(() => mockMqtt.isConnected).thenReturn(true);
          final client = session.createComputeClient(mqttMonitor: mockMqtt);
          expect(client.auth, isA<JWTAuthProvider>());

          // Step 5: Logout
          await session.logout();
          expect(session.isAuthenticated, isFalse);
        });
      });
    });
  });
}
