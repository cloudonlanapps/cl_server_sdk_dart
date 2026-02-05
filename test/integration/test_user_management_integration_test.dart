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

    test('test_create_user_success', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();
      const testUsername = 'test_new_user_dart';

      // Check if test user already exists and delete
      final users = await authClient.listUsers(token);
      final existing = users
          .where((u) => u.username == testUsername)
          .firstOrNull;
      if (existing != null) {
        await authClient.deleteUser(token, existing.id);
      }

      // Create user
      final userCreate = UserCreateRequest(
        username: testUsername,
        password: 'password123',
        permissions: ['read:jobs'],
      );

      final createdUser = await authClient.createUser(token, userCreate);

      // Verify user created
      expect(createdUser.username, equals(testUsername));
      expect(createdUser.isAdmin, isFalse);
      expect(createdUser.isActive, isTrue);
      expect(createdUser.permissions, equals(['read:jobs']));
      expect(createdUser.id, isNotNull);

      // Cleanup
      await authClient.deleteUser(token, createdUser.id);
    });

    test('test_list_users_success', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();

      // List users
      final users = await authClient.listUsers(token);

      // Verify results
      expect(users, isA<List<UserResponse>>());
      expect(users.length, greaterThan(0)); // At least admin user exists

      // Find admin user
      final adminUser = users.where((u) => u.username == 'admin').firstOrNull;
      expect(adminUser, isNotNull);
      expect(adminUser!.isAdmin, isTrue);
    });

    test('test_get_user_success', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();

      // First create a user to get
      final userCreate = UserCreateRequest(
        username: 'test_get_user_dart',
        password: 'password123',
        permissions: ['read:jobs', 'write:jobs'],
      );

      final createdUser = await authClient.createUser(token, userCreate);

      try {
        // Get the user
        final fetchedUser = await authClient.getUser(token, createdUser.id);

        // Verify
        expect(fetchedUser.id, equals(createdUser.id));
        expect(fetchedUser.username, equals('test_get_user_dart'));
        expect(fetchedUser.isAdmin, isFalse);
        expect(fetchedUser.isActive, isTrue);
        expect(fetchedUser.permissions, isA<List<String>>());
        expect(fetchedUser.permissions.length, greaterThan(0));
      } finally {
        // Cleanup
        await authClient.deleteUser(token, createdUser.id);
      }
    });

    test('test_update_user_permissions', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();

      // Create user
      final userCreate = UserCreateRequest(
        username: 'test_update_perms_dart',
        password: 'password123',
        permissions: ['read:jobs'],
      );

      final createdUser = await authClient.createUser(token, userCreate);

      try {
        // Update permissions
        final userUpdate = UserUpdateRequest(
          permissions: ['read:jobs', 'write:jobs', 'admin'],
        );

        final updatedUser = await authClient.updateUser(
          token,
          createdUser.id,
          userUpdate,
        );

        // Verify update
        expect(updatedUser.id, equals(createdUser.id));
        expect(
          updatedUser.permissions.toSet(),
          equals({'read:jobs', 'write:jobs', 'admin'}),
        );
      } finally {
        // Cleanup
        await authClient.deleteUser(token, createdUser.id);
      }
    });

    test('test_delete_user_success', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();

      // Check if test user already exists
      final users = await authClient.listUsers(token);
      final existingUser = users
          .where((u) => u.username == 'test_delete_user_dart')
          .firstOrNull;

      int userId;
      if (existingUser != null) {
        // User exists - verify/update permissions if needed
        final expectedPermissions = ['read:jobs'];
        if (existingUser.permissions != expectedPermissions) {
          final update = UserUpdateRequest(permissions: expectedPermissions);
          await authClient.updateUser(token, existingUser.id, update);
        }
        userId = existingUser.id;
      } else {
        // User doesn't exist - create it
        final userCreate = UserCreateRequest(
          username: 'test_delete_user_dart',
          password: 'password123',
          permissions: ['read:jobs'],
        );

        final createdUser = await authClient.createUser(token, userCreate);
        userId = createdUser.id;
      }

      // Delete user
      await authClient.deleteUser(token, userId);

      // Verify user no longer exists
      final usersAfter = await authClient.listUsers(token);
      final deletedUser = usersAfter.where((u) => u.id == userId).firstOrNull;
      expect(deletedUser, isNull, reason: 'User should be deleted');
    });

    test('test_list_users_with_pagination', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();
      final createdIds = <int>[];

      try {
        // Create multiple users
        for (var i = 0; i < 5; i++) {
          final userCreate = UserCreateRequest(
            username: 'test_pagination_dart_$i',
            password: 'password123',
            permissions: ['read:jobs'],
          );

          final user = await authClient.createUser(token, userCreate);
          createdIds.add(user.id);
        }

        // Test pagination
        final page1 = await authClient.listUsers(token, limit: 3);
        final page2 = await authClient.listUsers(token, skip: 3, limit: 3);

        // Verify pagination works
        expect(page1.length, equals(3));
        expect(page2.length, greaterThanOrEqualTo(2)); // At least 2 more users
      } finally {
        // Cleanup
        for (final id in createdIds) {
          await authClient.deleteUser(token, id);
        }
      }
    });

    test('test_update_user_password', () async {
      final authClient = adminSession.authClient;
      final token = adminSession.getToken();
      const username = 'test_pwd_user_dart';

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
        // ignore: avoid_catches_without_on_clauses
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
          username: 'test_active_user_dart',
          password: 'password',
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
