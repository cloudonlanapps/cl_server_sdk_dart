import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('User Management Integration Tests', () {
    late SessionManager adminSession;

    setUpAll(() async {
      adminSession = await IntegrationHelper.createSession();
    });

    tearDownAll(() async {
      await adminSession.close();
    });

    test('test_user_crud_flow', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();
      final testUsername = 'test_crud_user_dart';
      final testPassword = 'password123';

      // 1. Create User
      final userCreate = UserCreateRequest(
        username: testUsername,
        password: testPassword,
        isAdmin: false,
        isActive: true,
        permissions: ['read:jobs'],
      );

      final createdUser = await authClient.createUser(token, userCreate);
      expect(createdUser.username, equals(testUsername));
      expect(createdUser.isAdmin, isFalse);

      try {
        // 2. Get User
        final fetchedUser = await authClient.getUser(token, createdUser.id);
        expect(fetchedUser.id, equals(createdUser.id));
        expect(fetchedUser.username, equals(testUsername));

        // 3. Update User
        final userUpdate = UserUpdateRequest(
          permissions: ['read:jobs', 'write:jobs'],
          isActive: true,
        );
        final updatedUser = await authClient.updateUser(
          token,
          createdUser.id,
          userUpdate,
        );
        expect(updatedUser.permissions, contains('write:jobs'));

        // 4. List Users
        final users = await authClient.listUsers(token);
        expect(users.any((u) => u.id == createdUser.id), isTrue);
      } finally {
        // 5. Delete User
        await authClient.deleteUser(token, createdUser.id);

        // Verify deletion
        final usersAfter = await authClient.listUsers(token);
        expect(usersAfter.any((u) => u.id == createdUser.id), isFalse);
      }
    });

    test('test_user_pagination', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();
      final prefix = 'test_pag_';
      final createdIds = <int>[];

      try {
        for (var i = 0; i < 5; i++) {
          final user = await authClient.createUser(
            token,
            UserCreateRequest(
              username: '$prefix$i',
              password: 'pass',
              isAdmin: false,
              isActive: true,
              permissions: [],
            ),
          );
          createdIds.add(user.id);
        }

        final page1 = await authClient.listUsers(token, skip: 0, limit: 3);
        expect(page1.length, equals(3));

        final page2 = await authClient.listUsers(token, skip: 3, limit: 3);
        expect(page2.length, greaterThanOrEqualTo(2));
      } finally {
        for (final id in createdIds) {
          await authClient.deleteUser(token, id);
        }
      }
    });

    test('test_update_user_password', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();
      final username = 'test_pwd_user';

      // Create user
      final user = await authClient.createUser(
        token,
        UserCreateRequest(
          username: username,
          password: 'oldpassword',
        ),
      );

      try {
        // Update password
        await authClient.updateUser(
          token,
          user.id,
          UserUpdateRequest(password: 'newpassword'),
        );

        // Try login with OLD password -> should fail
        var oldLoginFailed = false;
        try {
          final tempSession = SessionManager(
            serverConfig: IntegrationTestConfig.serverConfig,
          );
          await tempSession.login(username, 'oldpassword');
          await tempSession.close();
        } catch (e) {
          oldLoginFailed = true;
        }
        expect(oldLoginFailed, isTrue);

        // Try login with NEW password -> should succeed
        final newSession = SessionManager(
          serverConfig: IntegrationTestConfig.serverConfig,
        );
        await newSession.login(username, 'newpassword');
        expect(newSession.isAuthenticated, isTrue);
        await newSession.close();
      } finally {
        await authClient.deleteUser(token, user.id);
      }
    });

    test('test_update_user_active_status', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();

      // Create active user
      final user = await authClient.createUser(
        token,
        UserCreateRequest(
          username: 'test_active_user',
          password: 'password',
          isActive: true,
        ),
      );

      try {
        // Deactivate
        final updated1 = await authClient.updateUser(
          token,
          user.id,
          UserUpdateRequest(isActive: false),
        );
        expect(updated1.isActive, isFalse);

        // Reactivate
        final updated2 = await authClient.updateUser(
          token,
          user.id,
          UserUpdateRequest(isActive: true),
        );
        expect(updated2.isActive, isTrue);
      } finally {
        await authClient.deleteUser(token, user.id);
      }
    });
  });
}
