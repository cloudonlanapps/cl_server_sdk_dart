import 'package:cl_server_dart_client/src/clients/auth_client.dart';
import 'package:cl_server_dart_client/src/clients/compute_client.dart';
import 'package:cl_server_dart_client/src/models/auth_models.dart';
import 'package:cl_server_dart_client/src/mqtt_monitor.dart'; // Import MQTTJobMonitor
import 'package:cl_server_dart_client/src/server_config.dart';
import 'package:cl_server_dart_client/src/session_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAuthClient extends Mock implements AuthClient {}

// MockServerConfig removed

class MockMQTTJobMonitor extends Mock implements MQTTJobMonitor {}

void main() {
  group('SessionManager', () {
    late MockAuthClient mockAuthClient;
    late ServerConfig testConfig;

    setUp(() {
      mockAuthClient = MockAuthClient();
      testConfig = const ServerConfig();
    });

    SessionManager createSession() {
      return SessionManager(
        serverConfig: testConfig,
        authClient: mockAuthClient,
      );
    }

    test('test_session_manager_default_config', () {
      final session = createSession();
      // Implementation details are private, but we can check public state
      expect(session.isAuthenticated, isFalse);
    });

    test('test_login_success', () async {
      final session = createSession();
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

      final user = await session.getCurrentUser();
      expect(user, equals(userResponse));
    });

    test('test_login_invalid_credentials', () async {
      final session = createSession();
      // Simulate auth error
      when(
        () => mockAuthClient.login('invalid', 'invalid'),
      ).thenThrow(Exception('401 Unauthorized'));

      expect(() => session.login('invalid', 'invalid'), throwsException);
      expect(session.isAuthenticated, isFalse);
    });

    test('test_logout', () async {
      final session = createSession();

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

    test('test_get_current_user_cached', () async {
      final session = createSession();
      final now = DateTime.now().toUtc();
      final userResponse = UserResponse(
        id: 1,
        username: 'cached',
        createdAt: now,
        permissions: [],
      );

      when(() => mockAuthClient.login(any(), any())).thenAnswer(
        (_) async => TokenResponse(accessToken: 'tok', tokenType: 'b'),
      );
      when(
        () => mockAuthClient.getCurrentUser(any()),
      ).thenAnswer((_) async => userResponse);

      await session.login('u', 'p');

      // Clear mock calls to verify no fetch happened next time
      clearInteractions(mockAuthClient);

      final user = await session.getCurrentUser();
      expect(user!.username, equals('cached'));
      verifyNever(() => mockAuthClient.getCurrentUser(any()));
    });

    test('test_get_current_user_fetch_from_server', () async {
      final session = createSession();

      // Login success, but user fetch fails initially (e.g. timeout)
      when(() => mockAuthClient.login(any(), any())).thenAnswer(
        (_) async => TokenResponse(accessToken: 'tok', tokenType: 'b'),
      );
      when(
        () => mockAuthClient.getCurrentUser('tok'),
      ).thenThrow(Exception('Network error'));

      await session.login('u', 'p');
      expect(session.isAuthenticated, isTrue);

      clearInteractions(mockAuthClient);

      // Now user fetch works
      final userResponse = UserResponse(
        id: 1,
        username: 'u',
        createdAt: DateTime.now(),
        permissions: [],
      );
      when(
        () => mockAuthClient.getCurrentUser('tok'),
      ).thenAnswer((_) async => userResponse);

      final user = await session.getCurrentUser();
      expect(user, equals(userResponse));
      verify(() => mockAuthClient.getCurrentUser('tok')).called(1);
    });

    test('test_get_current_user_guest_mode', () async {
      final session = createSession();
      expect(session.isAuthenticated, isFalse);
      expect(await session.getCurrentUser(), isNull);
    });

    test('test_get_token_not_authenticated', () {
      final session = createSession();
      expect(session.getToken, throwsStateError);
    });

    test('test_create_compute_client_guest_mode', () {
      final session = createSession();
      final monitor = MockMQTTJobMonitor();
      when(() => monitor.isConnected).thenReturn(false);
      when(monitor.connect).thenAnswer((_) async {});

      final client = session.createComputeClient(mqttMonitor: monitor);

      expect(client, isA<ComputeClient>());
    });

    test('test_create_compute_client_authenticated', () async {
      final session = createSession();
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

      final monitor = MockMQTTJobMonitor();
      when(() => monitor.isConnected).thenReturn(false);
      when(monitor.connect).thenAnswer((_) async {});

      final client = session.createComputeClient(mqttMonitor: monitor);
      expect(client, isA<ComputeClient>());
    });

    test('test_create_store_manager_not_authenticated', () {
      final session = createSession();
      // StoreManager requires authentication
      expect(session.createStoreManager, throwsStateError);
    });
  });
}
