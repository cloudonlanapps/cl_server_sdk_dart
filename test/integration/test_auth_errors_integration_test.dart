import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:cl_server_dart_client/src/auth.dart';
import 'package:cl_server_dart_client/src/exceptions.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Auth Error Integration Tests', () {
    setUpAll(() async {
      try {
        final session = await IntegrationHelper.createSession();
        final client = session.createComputeClient();
        await client.updateGuestMode(guestMode: false);
        await client.close();
        await session.close();
      } catch (e) {
        print('Warning: Could not disable guest mode: $e');
      }
    });

    test('test_unauthenticated_request_rejected', () async {
      // Create client without authentication
      final client = ComputeClient(
        baseUrl: IntegrationTestConfig.computeUrl,
        mqttBroker: IntegrationTestConfig.mqttBroker,
        mqttPort: IntegrationTestConfig.mqttPort,
      );

      bool shouldFail =
          IntegrationTestConfig.computeAuthRequired &&
          !IntegrationTestConfig.computeGuestMode;

      if (shouldFail) {
        await expectLater(
          () => client.getJob('any-id'),
          throwsA(isA<AuthenticationError>()),
        );
      } else {
        // Should succeed or at least not fail with 401
        try {
          await client.getJob('non-existent-id');
        } on JobNotFoundError {
          // 404 is fine, means we passed 401/403
        } catch (e) {
          expect(e, isNot(isA<AuthenticationError>()));
        }
      }
      await client.close();
    });

    test('test_invalid_token_rejected', () async {
      bool shouldFail =
          IntegrationTestConfig.computeAuthRequired &&
          !IntegrationTestConfig.computeGuestMode;

      // Create client with invalid token
      final invalidAuth = JWTAuthProvider(token: 'invalid.token.here');
      final client = ComputeClient(
        baseUrl: IntegrationTestConfig.computeUrl,
        mqttBroker: IntegrationTestConfig.mqttBroker,
        mqttPort: IntegrationTestConfig.mqttPort,
        authProvider: invalidAuth,
      );

      if (shouldFail) {
        await expectLater(
          () => client.getJob('any-id'),
          throwsA(isA<AuthenticationError>()),
        );
      } else {
        try {
          await client.getJob('non-existent-id');
        } on JobNotFoundError {
          // Success
        } catch (e) {
          expect(e, isNot(isA<AuthenticationError>()));
        }
      }
      await client.close();
    });

    test('test_malformed_token_rejected', () async {
      bool shouldFail =
          IntegrationTestConfig.computeAuthRequired &&
          !IntegrationTestConfig.computeGuestMode;

      // Create client with malformed token
      final malformedAuth = JWTAuthProvider(token: 'not-a-jwt');
      final client = ComputeClient(
        baseUrl: IntegrationTestConfig.computeUrl,
        mqttBroker: IntegrationTestConfig.mqttBroker,
        mqttPort: IntegrationTestConfig.mqttPort,
        authProvider: malformedAuth,
      );

      if (shouldFail) {
        await expectLater(
          () => client.getJob('any-id'),
          throwsA(isA<AuthenticationError>()),
        );
      } else {
        try {
          await client.getJob('non-existent-id');
        } on JobNotFoundError {
          // Success
        } catch (e) {
          expect(e, isNot(isA<AuthenticationError>()));
        }
      }
      await client.close();
    });

    test('test_non_admin_user_forbidden_from_admin_endpoints', () async {
      if (!IntegrationTestConfig.isAuthEnabled) {
        print('Skipping non-admin test: admin credentials not provided');
        return;
      }

      // 1. Login as admin to create a regular user
      final adminSession = await IntegrationHelper.createSession();
      final testUsername = 'testuser_nonadmin_dart';
      final testPassword = 'testpass123';

      try {
        // Create a non-admin user
        final userCreate = UserCreateRequest(
          username: testUsername,
          password: testPassword,
          isAdmin: false,
          isActive: true,
          permissions: ['read:jobs'],
        );

        await adminSession.authClient.createUser(
          adminSession.getToken(),
          userCreate,
        );

        // 2. Login as the non-admin user
        final userSession = SessionManager(
          serverConfig: IntegrationTestConfig.serverConfig,
        );
        await userSession.login(testUsername, testPassword);

        try {
          // 3. Try to access admin-only endpoint (create user)
          final anotherUser = UserCreateRequest(
            username: 'another_user',
            password: 'pass',
            isAdmin: false,
            isActive: true,
            permissions: [],
          );

          await expectLater(
            () => userSession.authClient.createUser(
              userSession.getToken(),
              anotherUser,
            ),
            throwsA(isA<PermissionError>()),
          );

          // 4. Try to list users (admin-only)
          await expectLater(
            () => userSession.authClient.listUsers(
              userSession.getToken(),
            ),
            throwsA(isA<PermissionError>()),
          );
        } finally {
          await userSession.close();
        }

        // Cleanup: Delete the test user
        final List<UserResponse> users = await adminSession.authClient
            .listUsers(
              adminSession.getToken(),
            );
        final createdUser = users.firstWhere((u) => u.username == testUsername);
        await adminSession.authClient.deleteUser(
          adminSession.getToken(),
          createdUser.id,
        );
      } finally {
        await adminSession.close();
      }
    });

    test('test_expired_token_rejected', () {
      // This test is skipped in PySDK as it's difficult to test without
      // short-lived tokens or server clock mocking.
      // Included here for 100% test parity count.
      print(
        'Skipping test_expired_token_rejected: Requires short-lived tokens',
      );
    }, skip: 'Requires short-lived tokens');

    test('test_compute_operations_with_valid_auth_succeed', () async {
      if (!IntegrationTestConfig.isAuthEnabled) {
        print('Skipping positive auth test: auth not enabled');
        return;
      }

      final session = await IntegrationHelper.createSession();
      final client = session.createComputeClient();

      try {
        // Simple operation that requires auth
        // Since we are in auth mode, this should succeed.
        final caps = await client.getCapabilities();
        expect(caps, isNotNull);
      } finally {
        await client.close();
        await session.close();
      }
    });
  });
}
