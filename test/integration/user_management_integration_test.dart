import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../auth_test_context.dart';
import '../decision_functions.dart';
import '../test_helpers.dart';

/// Integration tests for user management operations
///
/// These tests verify admin user CRUD operations:
/// - Create user
/// - List users
/// - Get user
/// - Update user
/// - Delete user
///
/// NOTE: These tests test admin operations. They run in all auth modes
/// but expect different outcomes based on whether the user has admin
/// permissions:
/// - Admin mode: Operations succeed
/// - Non-admin modes: Operations fail with 403 Forbidden
/// - No-auth mode: Operations fail with 401 Unauthorized

void main() {
  group('User Management Integration Tests', () {
    testWithAuthMode(
        'Test that create_user succeeds for admin, fails for non-admin',
        (AuthTestContext context) async {
      if (shouldSucceed(context, OperationType.admin)) {
        final manager = await createTestUserManager(context);

        // Should succeed - admin user
        final result = await manager.createUser(
          username: 'test_new_user',
          password: 'password123',
          isAdmin: false,
          permissions: ['read:jobs'],
        );

        expect(result.isSuccess, isTrue,
            reason: 'Expected success but got error: ${result.error}');
        expect(result.data?.username, contains('test_new_user'));
        expect(result.data?.isAdmin, isFalse);
        expect(result.data?.isActive, isTrue);
        expect(result.data?.id, isNotNull);

        // Cleanup
        final userId = result.data!.id! as int;
        await manager.deleteUser(userId: userId);
      } else {
        // Should fail - non-admin user
        try {
          final manager = await createTestUserManager(context);
          final result = await manager.createUser(
            username: 'test_new_user',
            password: 'password123',
            isAdmin: false,
          );
          expect(result.isError, isTrue,
              reason: 'Expected error for non-admin');
        } catch (e) {
          // No-auth mode will throw ArgumentError before creating manager
          expect(context.mode, equals(AuthMode.noAuth));
        }
      }
    });

    testWithAuthMode(
        'Test that list_users succeeds for admin, fails for non-admin',
        (AuthTestContext context) async {
      if (shouldSucceed(context, OperationType.admin)) {
        final manager = await createTestUserManager(context);

        // Should succeed - admin user
        final result = await manager.listUsers(
          options: UserListOptions(showAll: true),
        );

        expect(result.isSuccess, isTrue);
        expect(result.data, isA<List>());
        // At least admin exists
        expect((result.data as List).length > 0, isTrue);

        // Find admin user
        final users = (result.data as List).cast<User>();
        final adminUser = users.where((u) => u.username == 'admin').firstOrNull;
        expect(adminUser, isNotNull);
        expect(adminUser?.isAdmin, isTrue);
      } else {
        // Should fail - non-admin user
        try {
          final manager = await createTestUserManager(context);
          final result = await manager.listUsers();
          expect(result.isError, isTrue,
              reason: 'Expected error for non-admin');
        } catch (e) {
          // No-auth mode will throw ArgumentError before creating manager
          expect(context.mode, equals(AuthMode.noAuth));
        }
      }
    });

    testWithAuthMode(
        'Test that get_user succeeds for admin, fails for non-admin',
        (AuthTestContext context) async {
      if (shouldSucceed(context, OperationType.admin)) {
        final manager = await createTestUserManager(context);

        // Create a user to get
        final createResult = await manager.createUser(
          username: 'test_get_user',
          password: 'password123',
          isAdmin: false,
          permissions: ['read:jobs', 'write:jobs'],
        );

        expect(createResult.isSuccess, isTrue);
        final userId = createResult.data!.id! as int;

        // Get the user
        final getResult = await manager.getUser(userId: userId);

        expect(getResult.isSuccess, isTrue);
        expect(getResult.data?.id, equals(userId));
        expect(getResult.data?.username, contains('test_get_user'));
        expect(getResult.data?.isAdmin, isFalse);
        expect(getResult.data?.isActive, isTrue);

        // Cleanup
        await manager.deleteUser(userId: userId);
      } else {
        // Should fail - non-admin user
        try {
          final manager = await createTestUserManager(context);
          final result = await manager.getUser(userId: 1); // Fake ID
          expect(result.isError, isTrue,
              reason: 'Expected error for non-admin');
        } catch (e) {
          // No-auth mode will throw ArgumentError before creating manager
          expect(context.mode, equals(AuthMode.noAuth));
        }
      }
    });

    testWithAuthMode(
        'Test that update_user permissions succeeds for admin, '
        'fails for non-admin',
        (AuthTestContext context) async {
      if (shouldSucceed(context, OperationType.admin)) {
        final manager = await createTestUserManager(context);

        // Create user
        final createResult = await manager.createUser(
          username: 'test_update_user',
          password: 'password123',
          isAdmin: false,
          permissions: ['read:jobs'],
        );

        expect(createResult.isSuccess, isTrue);
        final userId = createResult.data!.id! as int;

        // Update permissions
        final updateResult = await manager.updateUser(
          userId: userId,
          permissions: ['read:jobs', 'write:jobs', 'admin'],
        );

        expect(updateResult.isSuccess, isTrue);
        expect(updateResult.data?.id, equals(userId));

        // Cleanup
        await manager.deleteUser(userId: userId);
      } else {
        // Should fail - non-admin user
        try {
          final manager = await createTestUserManager(context);
          final result = await manager.updateUser(
            userId: 1,
            permissions: ['read:jobs'],
          );
          expect(result.isError, isTrue,
              reason: 'Expected error for non-admin');
        } catch (e) {
          // No-auth mode will throw ArgumentError before creating manager
          expect(context.mode, equals(AuthMode.noAuth));
        }
      }
    });

    testWithAuthMode(
        'Test that updating user password succeeds for admin, '
        'fails for non-admin',
        (AuthTestContext context) async {
      if (shouldSucceed(context, OperationType.admin)) {
        final manager = await createTestUserManager(context);

        // Create user
        final createResult = await manager.createUser(
          username: 'test_password_user',
          password: 'oldpassword123',
          isAdmin: false,
          permissions: ['read:jobs'],
        );

        expect(createResult.isSuccess, isTrue);
        final userId = createResult.data!.id! as int;

        // Update password
        final updateResult = await manager.updateUser(
          userId: userId,
          password: 'newpassword456',
        );

        expect(updateResult.isSuccess, isTrue);

        // Try to login with new password
        final config = await createTestServerConfig();
        final userSession = SessionManager.initialize(config);

        // Need to get the prefixed username
        final getUserResult = await manager.getUser(userId: userId);
        final prefixedUsername = getUserResult.data!.username! as String;

        await userSession.login(prefixedUsername, 'newpassword456');

        // Verify login succeeded
        expect(userSession.isLoggedIn, isTrue);

        // Cleanup
        await userSession.logout();
        await manager.deleteUser(userId: userId);
      } else {
        // Should fail - non-admin user
        try {
          final manager = await createTestUserManager(context);
          final result = await manager.updateUser(
            userId: 1,
            password: 'newpassword',
          );
          expect(result.isError, isTrue,
              reason: 'Expected error for non-admin');
        } catch (e) {
          // No-auth mode will throw ArgumentError before creating manager
          expect(context.mode, equals(AuthMode.noAuth));
        }
      }
    });

    testWithAuthMode(
        'Test that deactivating/activating users succeeds for admin, '
        'fails for non-admin',
        (AuthTestContext context) async {
      if (shouldSucceed(context, OperationType.admin)) {
        final manager = await createTestUserManager(context);

        // Create active user
        final createResult = await manager.createUser(
          username: 'test_active_user',
          password: 'password123',
          isAdmin: false,
          permissions: ['read:jobs'],
        );

        expect(createResult.isSuccess, isTrue);
        final userId = createResult.data!.id! as int;

        // Deactivate user
        final updateResult = await manager.updateUser(
          userId: userId,
          isActive: false,
        );

        expect(updateResult.isSuccess, isTrue);
        expect(updateResult.data?.isActive, isFalse);

        // Cleanup
        await manager.deleteUser(userId: userId);
      } else {
        // Should fail - non-admin user
        try {
          final manager = await createTestUserManager(context);
          final result = await manager.updateUser(
            userId: 1,
            isActive: false,
          );
          expect(result.isError, isTrue,
              reason: 'Expected error for non-admin');
        } catch (e) {
          // No-auth mode will throw ArgumentError before creating manager
          expect(context.mode, equals(AuthMode.noAuth));
        }
      }
    });

    testWithAuthMode(
        'Test that delete_user succeeds for admin, fails for non-admin',
        (AuthTestContext context) async {
      if (shouldSucceed(context, OperationType.admin)) {
        final manager = await createTestUserManager(context);

        // Create user to delete
        final createResult = await manager.createUser(
          username: 'test_delete_user',
          password: 'password123',
          isAdmin: false,
          permissions: ['read:jobs'],
        );

        expect(createResult.isSuccess, isTrue);
        final userId = createResult.data!.id! as int;

        // Delete user
        final deleteResult = await manager.deleteUser(userId: userId);
        expect(deleteResult.isSuccess, isTrue);

        // Verify user no longer exists
        final listResult = await manager.listUsers(
          options: UserListOptions(showAll: true),
        );
        expect(listResult.isSuccess, isTrue);

        final users = (listResult.data as List).cast<User>();
        final deletedUser = users.where((u) => u.id == userId).firstOrNull;
        expect(deletedUser, isNull, reason: 'User should be deleted');
      } else {
        // Should fail - non-admin user
        try {
          final manager = await createTestUserManager(context);
          final result = await manager.deleteUser(userId: 1);
          expect(result.isError, isTrue,
              reason: 'Expected error for non-admin');
        } catch (e) {
          // No-auth mode will throw ArgumentError before creating manager
          expect(context.mode, equals(AuthMode.noAuth));
        }
      }
    });

    testWithAuthMode(
        'Test that list_users pagination succeeds for admin, '
        'fails for non-admin',
        (AuthTestContext context) async {
      if (shouldSucceed(context, OperationType.admin)) {
        final manager = await createTestUserManager(context);

        // Create multiple users
        final createdUserIds = <int>[];
        for (var i = 0; i < 5; i++) {
          final result = await manager.createUser(
            username: 'test_pagination_$i',
            password: 'password123',
            isAdmin: false,
            permissions: ['read:jobs'],
          );
          expect(result.isSuccess, isTrue);
          createdUserIds.add(result.data!.id! as int);
        }

        // Test pagination
        final page1 = await manager.listUsers(
          options: UserListOptions(skip: 0, limit: 3, showAll: true),
        );

        final page2 = await manager.listUsers(
          options: UserListOptions(skip: 3, limit: 3, showAll: true),
        );

        // Verify pagination works
        expect(page1.isSuccess, isTrue);
        expect(page2.isSuccess, isTrue);
        expect((page1.data as List).length, equals(3));
        // At least 2 more users
        expect((page2.data as List).length >= 2, isTrue);

        // Cleanup
        for (final userId in createdUserIds) {
          await manager.deleteUser(userId: userId);
        }
      } else {
        // Should fail - non-admin user
        try {
          final manager = await createTestUserManager(context);
          final result = await manager.listUsers(
            options: UserListOptions(skip: 0, limit: 3),
          );
          expect(result.isError, isTrue,
              reason: 'Expected error for non-admin');
        } catch (e) {
          // No-auth mode will throw ArgumentError before creating manager
          expect(context.mode, equals(AuthMode.noAuth));
        }
      }
    });
  });
}
