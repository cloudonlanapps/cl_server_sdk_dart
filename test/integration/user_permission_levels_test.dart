import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';
import 'health_check_test.dart';

/// Test admin user operations via UserManager
///
/// Tests admin-level operations that should succeed with full permissions.
/// Verifies user creation, permission management, and
/// store configuration access.

const String adminUsername = 'admin';
const String adminPassword = 'admin';
const String testUserPrefix = 'test_perms_';

late SessionManager sessionManager;
late UserManager userManager;
int? createdTestUserId;

void main() {
  group('User Permission Levels - Admin Operations', () {
    setUpAll(() async {
      // Verify services are available
      await ensureAuthServiceHealthy();

      // Initialize session manager
      sessionManager = SessionManager.initialize(createTestServerConfig());

      // Login as admin
      await sessionManager.login(
        adminUsername,
        adminPassword,
      );

      // Create user manager
      userManager = await UserManager.authenticated(
        sessionManager: sessionManager,
        prefix: testUserPrefix,
      );
    });

    tearDownAll(() async {
      // Cleanup: Delete test user if created
      if (createdTestUserId != null) {
        try {
          await userManager.deleteUser(userId: createdTestUserId!);
        } on Exception catch (_) {
          /* Ignore cleanup errors*/
        }
      }

      // Logout
      await sessionManager.logout();
    });

    test('✅ Admin can create a user with permissions', () async {
      final result = await userManager.createUser(
        username: 'testuser1',
        password: 'TestPass123',
        permissions: ['media_store_read'],
      );

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect((result.data as User).username, contains(testUserPrefix));

      createdTestUserId = (result.data as User).id;
    });

    test('✅ Admin can get user details', () async {
      // First create a user
      final createResult = await userManager.createUser(
        username: 'testuser2',
        password: 'TestPass123',
      );
      expect(createResult.isSuccess, isTrue);
      final testUserId = (createResult.data as User).id;

      // Then get user details
      final result = await userManager.getUser(userId: testUserId);

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect((result.data as User).id, equals(testUserId));

      // Cleanup
      await userManager.deleteUser(userId: testUserId);
    });

    test('✅ Admin can list users (all users)', () async {
      final result = await userManager.listUsers(
        options: UserListOptions(
          showAll: true,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, isA<List<User>>());
      expect((result.data as List<User>).length, greaterThan(0));
    });

    test('✅ Admin can list utility-created users only', () async {
      // Create a test user first
      final createResult = await userManager.createUser(
        username: 'utilityuser1',
        password: 'TestPass123',
      );
      expect(createResult.isSuccess, isTrue);
      final testUserId = (createResult.data as User).id;

      // List utility-created users only
      final result = await userManager.listUsers(
        options: UserListOptions(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.data, isNotNull);

      // Cleanup
      await userManager.deleteUser(userId: testUserId);
    });

    test('✅ Admin can update user permissions', () async {
      // Create a test user
      final createResult = await userManager.createUser(
        username: 'updateuser1',
        password: 'TestPass123',
        permissions: [],
      );
      expect(createResult.isSuccess, isTrue);
      final testUserId = (createResult.data as User).id;

      // Update permissions
      final result = await userManager.updateUser(
        userId: testUserId,
        permissions: ['media_store_write'],
      );

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.data, isNotNull);

      // Cleanup
      await userManager.deleteUser(userId: testUserId);
    });

    test('✅ Admin can get user permissions', () async {
      // Create a test user with permissions
      final createResult = await userManager.createUser(
        username: 'permuser1',
        password: 'TestPass123',
        permissions: ['media_store_read', 'media_store_write'],
      );
      expect(createResult.isSuccess, isTrue);
      final testUserId = (createResult.data as User).id;

      // Get user permissions
      final result = await userManager.getUserPermissions(userId: testUserId);

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, isA<List<String>>());

      // Cleanup
      await userManager.deleteUser(userId: testUserId);
    });

    test('✅ Admin can delete a user', () async {
      // Create a test user
      final createResult = await userManager.createUser(
        username: 'deleteuser1',
        password: 'TestPass123',
      );
      expect(createResult.isSuccess, isTrue);
      final testUserId = (createResult.data as User).id;

      // Delete user
      final result = await userManager.deleteUser(userId: testUserId);

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
    });

    test('✅ Admin can get store configuration', () async {
      final result = await userManager.getStoreConfig();

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
    });

    test('✅ Admin can update read authentication', () async {
      // Get current config
      final currentResult = await userManager.getStoreConfig();
      expect(currentResult.isSuccess, isTrue);
      final wasEnabled = (currentResult.data as StoreConfig).readAuthEnabled;

      try {
        // Update read auth - may fail due to API response format issues
        final result = await userManager.updateReadAuth(enabled: !wasEnabled);
        expect(result.isSuccess, isTrue);

        // Even if the response parsing fails, the action was likely performed
        // Verify by checking config directly
        final verifyResult = await userManager.getStoreConfig();
        expect(verifyResult.isSuccess, isTrue);
        // Updated value should be different from original
        // (unless update failed silently)
        expect(
          (verifyResult.data as StoreConfig).readAuthEnabled,
          !wasEnabled,
        );
      } finally {
        // Restore original setting
        try {
          await userManager.updateReadAuth(enabled: wasEnabled);
        } on Exception catch (_) {
          // Ignore restore errors
        }
      }
    });

    test('❌ Error handling: Invalid user ID returns error', () async {
      final result = await userManager.getUser(userId: 999999);

      expect(result.isError, isTrue);
      expect(result.error, isNotNull);
      expect(result.data, isNull);
    });
  });
}
