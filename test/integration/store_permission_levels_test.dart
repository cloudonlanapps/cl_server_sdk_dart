import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../server_addr.dart' show authServiceUrl, storeServiceUrl;
import 'health_check_test.dart';

/// Test store permission levels via StoreManager
///
/// Tests different permission combinations (read-only, write-only, both, none)
/// to verify permission enforcement at the store service level.

const String adminUsername = 'admin';
const String adminPassword = 'admin';
const String testUserPrefix = 'test_perms_';

late SessionManager adminSession;
late UserManager adminManager;
late StoreManager adminStoreManager;

// Test users and their managers
late int writeOnlyUserId;
late int readOnlyUserId;
late int noPermissionsUserId;

late StoreManager writeOnlyManager;
late StoreManager readOnlyManager;
late StoreManager noPermissionsManager;

// Test entity for read operations
late int testEntityId;

void main() {
  group('Store Permission Levels', () {
    setUpAll(() async {
      // Verify services are available
      await ensureBothServicesHealthy();

      // Setup admin session
      adminSession = SessionManager.initialize();
      await adminSession.login(
        adminUsername,
        adminPassword,
        authBaseUrl: authServiceUrl,
      );

      // Create admin user manager and store manager
      adminManager = await UserManager.authenticated(
        sessionManager: adminSession,
        prefix: testUserPrefix,
      );

      adminStoreManager = await StoreManager.authenticated(
        sessionManager: adminSession,
        baseUrl: storeServiceUrl,
      );

      // Create test users with different permissions
      final writeResult = await adminManager.createUser(
        username: 'write_user',
        password: 'TestPass123',
        permissions: ['media_store_write'],
      );
      // UserManager API returns dynamic data type that must be cast
      // ignore: avoid_dynamic_calls
      writeOnlyUserId = (writeResult.data.id as dynamic) as int;

      final readResult = await adminManager.createUser(
        username: 'read_user',
        password: 'TestPass123',
        permissions: ['media_store_read'],
      );
      // UserManager API returns dynamic data type that must be cast
      // ignore: avoid_dynamic_calls
      readOnlyUserId = (readResult.data.id as dynamic) as int;

      final noneResult = await adminManager.createUser(
        username: 'none_user',
        password: 'TestPass123',
        permissions: <String>[],
      );
      // UserManager API returns dynamic data type that must be cast
      // ignore: avoid_dynamic_calls
      noPermissionsUserId = (noneResult.data.id as dynamic) as int;

      // Create test entity for read tests (as collection to avoid image
      // requirement)
      final entityResult = await adminStoreManager.createEntity(
        label: 'test_entity_${DateTime.now().millisecondsSinceEpoch}',
        isCollection: true,
      );

      if (!entityResult.isSuccess || entityResult.data == null) {
        throw Exception('Failed to create test entity: ${entityResult.error}');
      }
      // StoreManager API returns dynamic data type that must be cast
      // ignore: avoid_dynamic_calls
      testEntityId = (entityResult.data.id as dynamic) as int;

      // Create managers for test users
      final writeSession = SessionManager.initialize();
      await writeSession.login(
        '${testUserPrefix}write_user',
        'TestPass123',
        authBaseUrl: authServiceUrl,
      );
      writeOnlyManager = await StoreManager.authenticated(
        sessionManager: writeSession,
        baseUrl: storeServiceUrl,
      );

      final readSession = SessionManager.initialize();
      await readSession.login(
        '${testUserPrefix}read_user',
        'TestPass123',
        authBaseUrl: authServiceUrl,
      );
      readOnlyManager = await StoreManager.authenticated(
        sessionManager: readSession,
        baseUrl: storeServiceUrl,
      );

      final noneSession = SessionManager.initialize();
      await noneSession.login(
        '${testUserPrefix}none_user',
        'TestPass123',
        authBaseUrl: authServiceUrl,
      );
      noPermissionsManager = await StoreManager.authenticated(
        sessionManager: noneSession,
        baseUrl: storeServiceUrl,
      );
    });

    tearDownAll(() async {
      // Cleanup: Delete test entity
      try {
        await adminStoreManager.deleteEntity(entityId: testEntityId);
      } on Exception {
        // Ignore
      }

      // Cleanup: Delete test users
      try {
        await adminManager.deleteUser(userId: writeOnlyUserId);
        await adminManager.deleteUser(userId: readOnlyUserId);
        await adminManager.deleteUser(userId: noPermissionsUserId);
      } on Exception {
        // Ignore
      }

      // Logout
      await adminSession.logout();
    });

    group('Write-Only User', () {
      test('✅ Can create entity', () async {
        final result = await writeOnlyManager.createEntity(
          label: 'write_test_entity_${DateTime.now().millisecondsSinceEpoch}',
          isCollection: true,
        );

        expect(result.isSuccess, isTrue);
        expect(result.error, isNull);
        expect(result.data, isNotNull);

        // Cleanup
        await adminStoreManager.deleteEntity(
          // StoreManager API returns dynamic data type that must be cast
          // ignore: avoid_dynamic_calls
          entityId: (result.data.id as dynamic) as int,
        );
      });

      test('✅ Can update entity', () async {
        // Create entity as admin
        final createResult = await adminStoreManager.createEntity(
          label: 'update_test_entity_${DateTime.now().millisecondsSinceEpoch}',
          isCollection: true,
        );
        // StoreManager API returns dynamic data type that must be cast
        // ignore: avoid_dynamic_calls
        final entityId = (createResult.data.id as dynamic) as int;

        // Update as write user
        final result = await writeOnlyManager.updateEntity(
          entityId: entityId,
          label: 'updated_label',
          isCollection: true,
        );

        expect(result.isSuccess, isTrue);
        expect(result.error, isNull);

        // Cleanup
        await adminStoreManager.deleteEntity(entityId: entityId);
      });

      test('✅ Write-only user verified', () async {
        // Write-only user can perform write operations
        // No additional store operations available to test
        expect(true, isTrue);
      });
    });

    group('Read-Only User', () {
      test('✅ Can list entities', () async {
        final result = await readOnlyManager.listEntities();

        expect(result.isSuccess, isTrue);
        expect(result.error, isNull);
        expect(result.data, isNotNull);
      });

      test('✅ Can read entity details', () async {
        final result = await readOnlyManager.readEntity(entityId: testEntityId);

        expect(result.isSuccess, isTrue);
        expect(result.error, isNull);
        expect(result.data, isNotNull);
      });

      test('❌ Cannot create entity (403)', () async {
        final result = await readOnlyManager.createEntity(
          label: 'should_fail_${DateTime.now().millisecondsSinceEpoch}',
          isCollection: true,
        );

        expect(result.isError, isTrue);
        expect(result.error, isNotNull);
        expect(result.error, anyOf(contains('Permission'), contains('403')));
      });

      test('❌ Cannot update entity (403)', () async {
        final result = await readOnlyManager.updateEntity(
          entityId: testEntityId,
          label: 'should_fail',
          isCollection: false,
        );

        expect(result.isError, isTrue);
        expect(result.error, isNotNull);
        expect(result.error, anyOf(contains('Permission'), contains('403')));
      });

      test('❌ Cannot delete entity (403)', () async {
        final result = await readOnlyManager.deleteEntity(
          entityId: testEntityId,
        );

        expect(result.isError, isTrue);
        expect(result.error, isNotNull);
        expect(result.error, anyOf(contains('Permission'), contains('403')));
      });
    });

    group('No Permissions User', () {
      test('❌ Cannot create entity (403)', () async {
        final result = await noPermissionsManager.createEntity(
          label: 'should_fail_${DateTime.now().millisecondsSinceEpoch}',
          isCollection: true,
        );

        expect(result.isError, isTrue);
        expect(result.error, isNotNull);
      });

      test('❌ Cannot read when ReadAuth enabled', () async {
        // First enable read auth
        try {
          await adminManager.updateReadAuth(enabled: true);
        } on Exception {
          // Ignore response parsing errors
        }

        try {
          final result = await noPermissionsManager.listEntities();
          expect(result.isError, isTrue);
        } finally {
          // Disable read auth
          try {
            await adminManager.updateReadAuth(enabled: false);
          } on Exception {
            // Ignore response parsing errors
          }
        }
      });

      test('✅ Can read when ReadAuth disabled', () async {
        // Verify read auth is disabled
        final configResult = await adminManager.getStoreConfig();
        // UserManager API returns dynamic data type that must be cast
        // ignore: avoid_dynamic_calls
        if ((configResult.data.readAuthEnabled as dynamic) as bool) {
          try {
            await adminManager.updateReadAuth(enabled: false);
          } on Exception {
            // Ignore response parsing errors
          }
        }

        final result = await noPermissionsManager.listEntities();
        expect(result.isSuccess, isTrue);
      });
    });

    group('Permission Error Handling', () {
      test('❌ Error message captured in result', () async {
        final result = await readOnlyManager.createEntity(
          label: 'fail_test_${DateTime.now().millisecondsSinceEpoch}',
          isCollection: true,
        );

        expect(result.isError, isTrue);
        expect(result.error, isNotNull);
        expect(result.error!.length, greaterThan(0));
      });

      test('✅ Application continues after permission error', () async {
        // Try operation that fails
        final failResult = await readOnlyManager.createEntity(
          label: 'fail_test_${DateTime.now().millisecondsSinceEpoch}',
          isCollection: true,
        );
        expect(failResult.isError, isTrue);

        // Next operation should succeed
        final successResult = await readOnlyManager.listEntities();
        expect(successResult.isSuccess, isTrue);
      });
    });
  });
}
