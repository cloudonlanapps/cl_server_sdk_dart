import 'package:test/test.dart';

import '../auth_test_context.dart';
import '../decision_functions.dart';
import '../test_helpers.dart';

/// Integration tests for store service
///
/// These tests verify store operations across multiple auth modes:
/// - admin: Full access (all operations succeed)
/// - user-with-permission: Has media_store_read and media_store_write
/// - user-no-permission: No store permissions (read/write fail with 403)
/// - no-auth: Read succeeds (if guestMode='on'), write fails with 401
///
/// Store authentication model:
/// - Read operations: Can be public if guestMode='on'
/// - Write operations: ALWAYS require auth + media_store_write permission
/// - Admin operations: Require admin role
///
/// NOTE: Some Python SDK tests are not included here because Dart SDK
/// doesn't have those features yet:
/// - File upload (create_entity_with_file)
/// - Version history (get_versions)
/// - Admin config operations (get_config, update_read_auth)
/// These are documented in PYSDK_ADOPTION.md

void main() {
  group('Store Integration Tests', () {
    testWithAuthMode('Test listing entities with pagination',
        (AuthTestContext context) async {
      final manager = await createTestStoreManager(context);

      if (shouldSucceed(context, OperationType.storeRead)) {
        // Should succeed
        final result = await manager.listEntities(page: 1, pageSize: 20);
        expect(result.isSuccess, isTrue,
            reason: 'Expected success but got error: ${result.error}');
        expect(result.data, isNotNull);
        expect(result.data?.pagination.page, equals(1));
        expect(result.data?.pagination.pageSize, equals(20));
        expect(result.data?.items, isA<List>());
      } else {
        // Should fail
        final result = await manager.listEntities(page: 1, pageSize: 20);
        expect(result.isError, isTrue,
            reason: 'Expected error but got success');
        expect(result.error, isNotNull);
      }
    });

    testWithAuthMode('Test listing entities with search query',
        (AuthTestContext context) async {
      final manager = await createTestStoreManager(context);

      if (shouldSucceed(context, OperationType.storeRead)) {
        final result = await manager.listEntities(
          page: 1,
          pageSize: 10,
          searchQuery: 'test',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data, isNotNull);
        expect(result.data?.pagination.pageSize, equals(10));
      }
    });

    testWithAuthMode('Test creating a collection (folder) entity',
        (AuthTestContext context) async {
      final manager = await createTestStoreManager(context);

      if (shouldSucceed(context, OperationType.storeWrite)) {
        // Should succeed - create collection
        final result = await manager.createEntity(
          label: 'Test Collection',
          description: 'A test collection',
          isCollection: true,
        );
        expect(result.isSuccess, isTrue,
            reason: 'Expected success but got error: ${result.error}');
        expect(result.data, isNotNull);
        expect(result.data?.label, equals('Test Collection'));
        expect(result.data?.isCollection, isTrue);
        expect(result.data?.id, isNotNull);

        // Cleanup
        final entityId = result.data!.id! as int;
        final deleteResult = await manager.deleteEntity(entityId: entityId);
        expect(deleteResult.isSuccess, isTrue);
      } else {
        // Should fail
        final result = await manager.createEntity(
          label: 'Test Collection',
          isCollection: true,
        );
        expect(result.isError, isTrue);
        expect(result.error, isNotNull);
      }
    });

    testWithAuthMode('Test reading entity by ID',
        (AuthTestContext context) async {
      final manager = await createTestStoreManager(context);

      // First create an entity if we have write permissions
      if (shouldSucceed(context, OperationType.storeWrite)) {
        // Create entity first
        final createResult = await manager.createEntity(
          label: 'Entity to Read',
          isCollection: false,
        );
        expect(createResult.isSuccess, isTrue);
        final entityId = createResult.data!.id! as int;

        // Now test reading (should succeed if we have read permissions)
        if (shouldSucceed(context, OperationType.storeRead)) {
          final readResult = await manager.readEntity(entityId: entityId);
          expect(readResult.isSuccess, isTrue);
          expect(readResult.data?.id, equals(entityId));
          expect(readResult.data?.label, equals('Entity to Read'));
        }

        // Cleanup
        final deleteResult = await manager.deleteEntity(entityId: entityId);
        expect(deleteResult.isSuccess, isTrue);
      }
    });

    testWithAuthMode('Test full update (PUT) of an entity',
        (AuthTestContext context) async {
      final manager = await createTestStoreManager(context);

      if (shouldSucceed(context, OperationType.storeWrite)) {
        // Create entity first
        final createResult = await manager.createEntity(
          label: 'Original Label',
          description: 'Original description',
          isCollection: false,
        );
        expect(createResult.isSuccess, isTrue);
        final entityId = createResult.data!.id! as int;

        // Update entity
        final updateResult = await manager.updateEntity(
          entityId: entityId,
          label: 'Updated Label',
          description: 'Updated description',
          isCollection: false,
        );
        expect(updateResult.isSuccess, isTrue);
        expect(updateResult.data?.label, equals('Updated Label'));
        expect(updateResult.data?.description, equals('Updated description'));

        // Cleanup
        final deleteResult = await manager.deleteEntity(entityId: entityId);
        expect(deleteResult.isSuccess, isTrue);
      }
    });

    testWithAuthMode('Test partial update (PATCH) of an entity',
        (AuthTestContext context) async {
      final manager = await createTestStoreManager(context);

      if (shouldSucceed(context, OperationType.storeWrite)) {
        // Create entity first
        final createResult = await manager.createEntity(
          label: 'Original Label',
          description: 'Original description',
          isCollection: false,
        );
        expect(createResult.isSuccess, isTrue);
        final entityId = createResult.data!.id! as int;

        // Patch entity (only update label)
        final patchResult = await manager.patchEntity(
          entityId: entityId,
          label: 'Patched Label',
        );
        expect(patchResult.isSuccess, isTrue);
        expect(patchResult.data?.label, equals('Patched Label'));
        // Description should remain unchanged
        expect(patchResult.data?.description, equals('Original description'));

        // Cleanup
        final deleteResult = await manager.deleteEntity(entityId: entityId);
        expect(deleteResult.isSuccess, isTrue);
      }
    });

    testWithAuthMode('Test soft delete via PATCH',
        (AuthTestContext context) async {
      final manager = await createTestStoreManager(context);

      if (shouldSucceed(context, OperationType.storeWrite)) {
        // Create entity first
        final createResult = await manager.createEntity(
          label: 'Entity to Soft Delete',
          isCollection: false,
        );
        expect(createResult.isSuccess, isTrue);
        final entityId = createResult.data!.id! as int;

        // Soft delete
        final patchResult = await manager.patchEntity(
          entityId: entityId,
          isDeleted: true,
        );
        expect(patchResult.isSuccess, isTrue);
        expect(patchResult.data?.isDeleted, isTrue);

        // Restore (undo soft delete)
        final restoreResult = await manager.patchEntity(
          entityId: entityId,
          isDeleted: false,
        );
        expect(restoreResult.isSuccess, isTrue);
        expect(restoreResult.data?.isDeleted, isFalse);

        // Cleanup (hard delete)
        final deleteResult = await manager.deleteEntity(entityId: entityId);
        expect(deleteResult.isSuccess, isTrue);
      }
    });

    testWithAuthMode('Test hard delete of an entity',
        (AuthTestContext context) async {
      final manager = await createTestStoreManager(context);

      if (shouldSucceed(context, OperationType.storeWrite)) {
        // Create entity first
        final createResult = await manager.createEntity(
          label: 'Entity to Delete',
          isCollection: false,
        );
        expect(createResult.isSuccess, isTrue);
        final entityId = createResult.data!.id! as int;

        // Delete entity
        final deleteResult = await manager.deleteEntity(entityId: entityId);
        expect(deleteResult.isSuccess, isTrue);

        // Verify entity is gone (read should fail with 404)
        if (shouldSucceed(context, OperationType.storeRead)) {
          final readResult = await manager.readEntity(entityId: entityId);
          expect(readResult.isError, isTrue);
          expect(
            readResult.error!.contains('Not Found') ||
                readResult.error!.contains('404'),
            isTrue,
          );
        }
      }
    });
  });
}
