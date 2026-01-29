import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Auth Integration Tests', () {
    test('test_login_success', () async {
      if (!IntegrationTestConfig.isAuthEnabled) {
        // ignore: avoid_print
        print('Skipping auth test: credentials not provided');
        return;
      }

      final session = SessionManager(
        serverConfig: IntegrationTestConfig.serverConfig,
      );
      await session.login(
        IntegrationTestConfig.username!,
        IntegrationTestConfig.password!,
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.getToken(), isNotNull);

      final user = await session.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.username, equals(IntegrationTestConfig.username));

      await session.logout();
      expect(session.isAuthenticated, isFalse);
    });

    test('test_login_failure', () async {
      final session = SessionManager(
        serverConfig: IntegrationTestConfig.serverConfig,
      );

      expect(
        () => session.login('invalid_user', 'invalid_pass'),
        throwsException,
      ); // Should throw AuthenticationError or generic exception
    });

    test('test_create_clients_authenticated', () async {
      if (!IntegrationTestConfig.isAuthEnabled) return;

      final session = await IntegrationHelper.createSession();

      final compute = session.createComputeClient();
      expect(compute, isNotNull);

      final store = session.createStoreManager();
      expect(store, isNotNull);

      // Verify basic connectivity
      final status = await store.getMInsightStatus(); // Some simple call
      expect(status.isSuccess, isTrue);

      await session.close();
    });
  });
}
