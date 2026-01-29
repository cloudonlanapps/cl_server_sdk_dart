import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Store Integration Tests', () {
    // Cleanup before running tests (if possible)
    setUpAll(() async {
      await IntegrationHelper.cleanupStoreEntities();
    });

    // Cleanup after running tests
    tearDownAll(() async {
      await IntegrationHelper.cleanupStoreEntities();
    });

    test('test_store_crud_flow', () async {
      if (!IntegrationTestConfig.isAuthEnabled) {
        if (!IntegrationTestConfig.storeGuestMode) {
          // ignore: avoid_print
          print('Skipping store test: auth disabled and no guest mode');
          return;
        }
      }

      final store = await IntegrationHelper.createStoreManager();

      // 1. Create Entity
      final createResult = await store.createEntity(
        label: 'Dart Integration Test Entity',
        description: 'Created by Dart SDK integration test',
        isCollection: true,
      );
      expect(createResult.isSuccess, isTrue, reason: createResult.error);
      final entityId = createResult.data!.id;
      expect(createResult.data!.label, equals('Dart Integration Test Entity'));

      // 2. Read Entity
      final readResult = await store.readEntity(entityId);
      expect(readResult.isSuccess, isTrue);
      expect(readResult.data!.id, equals(entityId));

      // 3. Update Entity
      final updateResult = await store.updateEntity(
        entityId,
        label: 'Updated Label',
        description: 'Updated description',
        isCollection: true,
      );
      expect(updateResult.isSuccess, isTrue, reason: updateResult.error);
      expect(updateResult.data!.label, equals('Updated Label'));

      // 4. List Entities
      final listResult = await store.listEntities(pageSize: 100);
      expect(listResult.isSuccess, isTrue);
      final found = listResult.data!.items.any((e) => e.id == entityId);
      expect(found, isTrue);

      // 5. Delete Entity
      final deleteResult = await store.deleteEntity(entityId);
      expect(deleteResult.isSuccess, isTrue, reason: deleteResult.error);

      // Verify deletion (should fail or return 404 wrapped)
      final readAfterDelete = await store.readEntity(entityId);
      // Depending on API, it might return 404 error
      expect(readAfterDelete.isError, isTrue);

      await store.close();
    });

    test('test_mqtt_monitoring', () async {
      if (!IntegrationTestConfig.isAuthEnabled) return;

      final store = await IntegrationHelper.createStoreManager();

      // Create an entity to monitor
      final createResult = await store.createEntity(
        label: 'MQTT Test Entity',
        isCollection: true,
      );
      expect(createResult.isSuccess, isTrue);
      final entityId = createResult.data!.id;

      // Wait for status "completed" (or whatever status it ends up in)
      // Since we just created it and didn't upload file/process, it might stay in 'pending' or have no intelligence status?
      // Actually 'status' usually refers to intelligence pipeline.
      // Without file, no job starts.
      // So we might need to skip waiting or mock behavior?
      // But we can test that subscription works (no error).

      // We'll just verify we can subscribe without error.
      // Creating a dummy subscription
      final subId = await store.monitorEntity(entityId, (payload) {
        // ignore: avoid_print
        print('Received update: ${payload.status}');
      });
      expect(subId, isNotNull);

      store.stopMonitoring(subId);

      await store.deleteEntity(entityId);
      await store.close();
    });

    test('test_list_entities_with_search', () async {
      final store = await IntegrationHelper.createStoreManager();

      final result = await store.listEntities(
        page: 1,
        pageSize: 10,
        searchQuery: 'test',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.pagination.pageSize, equals(10));

      await store.close();
    });

    test('test_list_entities_exclude_deleted', () async {
      final store = await IntegrationHelper.createStoreManager();
      final imagePath = await IntegrationHelper.getTestImage();

      // Create an entity
      final createResult = await store.createEntity(
        label: 'Entity to Soft Delete',
        isCollection: false,
        imagePath: imagePath.path,
      );
      expect(createResult.isSuccess, isTrue);
      final entityId = createResult.data!.id;

      // Soft delete it
      final patchResult = await store.patchEntity(
        entityId,
        isDeleted: true,
      );
      expect(patchResult.isSuccess, isTrue);

      // 1. List without exclude_deleted (default False) -> Should include deleted
      final listAll = await store.listEntities(
        excludeDeleted: false,
        searchQuery: 'Entity to Soft Delete',
      );
      expect(listAll.isSuccess, isTrue);
      final foundAll = listAll.data!.items.any((i) => i.id == entityId);
      expect(
        foundAll,
        isTrue,
        reason: 'Should find soft-deleted entity when excludeDeleted=False',
      );

      // 2. List with excludeDeleted=True -> Should NOT include deleted
      final listExcluded = await store.listEntities(
        excludeDeleted: true,
        searchQuery: 'Entity to Soft Delete',
      );
      expect(listExcluded.isSuccess, isTrue);
      final foundExcluded = listExcluded.data!.items.any(
        (i) => i.id == entityId,
      );
      expect(
        foundExcluded,
        isFalse,
        reason: 'Should NOT find soft-deleted entity when excludeDeleted=True',
      );

      // Cleanup (hard delete)
      await store.deleteEntity(entityId);
      await store.close();
    });

    test('test_create_entity_with_file', () async {
      final store = await IntegrationHelper.createStoreManager();
      final imagePath = await IntegrationHelper.getTestImage();

      final result = await store.createEntity(
        label: 'Test Image',
        description: 'Test upload',
        isCollection: false,
        imagePath: imagePath.path,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.label, equals('Test Image'));
      expect(result.data!.filePath, isNotNull);
      expect(result.data!.fileSize, isNotNull);
      expect(result.data!.fileSize!, greaterThan(0));

      // Cleanup
      await store.deleteEntity(result.data!.id);
      await store.close();
    });

    test('test_patch_entity', () async {
      final store = await IntegrationHelper.createStoreManager();
      final imagePath = await IntegrationHelper.getTestImage();

      // Create entity first
      final createResult = await store.createEntity(
        label: 'Original Label',
        description: 'Original description',
        isCollection: false,
        imagePath: imagePath.path,
      );
      expect(createResult.isSuccess, isTrue);
      final entityId = createResult.data!.id;

      // Patch entity (only update label)
      final patchResult = await store.patchEntity(
        entityId,
        label: 'Patched Label',
      );
      expect(patchResult.isSuccess, isTrue);
      expect(patchResult.data!.label, equals('Patched Label'));
      // Description should remain unchanged
      expect(patchResult.data!.description, equals('Original description'));

      // Cleanup
      await store.deleteEntity(entityId);
      await store.close();
    });

    test('test_patch_entity_soft_delete', () async {
      final store = await IntegrationHelper.createStoreManager();
      final imagePath = await IntegrationHelper.getTestImage();

      // Create entity first
      final createResult = await store.createEntity(
        label: 'Entity to Soft Delete',
        isCollection: false,
        imagePath: imagePath.path,
      );
      expect(createResult.isSuccess, isTrue);
      final entityId = createResult.data!.id;

      // Soft delete
      final patchResult = await store.patchEntity(
        entityId,
        isDeleted: true,
      );
      expect(patchResult.isSuccess, isTrue);
      expect(patchResult.data!.isDeleted, isTrue);

      // Restore (undo soft delete)
      final restoreResult = await store.patchEntity(
        entityId,
        isDeleted: false,
      );
      expect(restoreResult.isSuccess, isTrue);
      expect(restoreResult.data!.isDeleted, isFalse);

      // Cleanup (hard delete)
      await store.deleteEntity(entityId);
      await store.close();
    });

    test('test_patch_entity_unset', () async {
      final store = await IntegrationHelper.createStoreManager();
      final imagePath = await IntegrationHelper.getTestImage();

      // Create entity with optional fields set
      final createResult = await store.createEntity(
        label: 'Original Label',
        description: 'Original Description',
        isCollection: false,
        imagePath: imagePath.path,
      );
      expect(createResult.isSuccess, isTrue);
      final entityId = createResult.data!.id;

      // 1. Test unsetting description (set to empty/null)
      // In Dart SDK, patchEntity takes nullable String for description.
      // Passing empty string or null should unset it depending on API behavior.
      final patchResult = await store.patchEntity(
        entityId,
        description: '', // Unset to empty
      );
      expect(patchResult.isSuccess, isTrue);
      expect(patchResult.data!.description, anyOf(isNull, isEmpty));
      expect(patchResult.data!.label, equals('Original Label'));

      // 2. Test updating label while keeping description unset
      final patchResult2 = await store.patchEntity(
        entityId,
        label: 'New Label',
        description: const Unset(),
      );
      expect(patchResult2.isSuccess, isTrue);
      expect(patchResult2.data!.label, equals('New Label'));
      // Description should still be empty (from previous patch)
      expect(patchResult2.data!.description, anyOf(isNull, isEmpty));

      // Cleanup
      await store.deleteEntity(entityId);
      await store.close();
    });

    test('test_get_versions', () async {
      final store = await IntegrationHelper.createStoreManager();
      final imagePath = await IntegrationHelper.getTestImage();

      // Create entity
      final createResult = await store.createEntity(
        label: 'Version Test Entity',
        description: 'Original',
        isCollection: false,
        imagePath: imagePath.path,
      );
      expect(createResult.isSuccess, isTrue);
      final entityId = createResult.data!.id;

      // Update entity to create a new version
      final updateResult = await store.patchEntity(
        entityId,
        description: 'Updated',
      );
      expect(updateResult.isSuccess, isTrue);

      // Get versions
      final versionsResult = await store.getVersions(entityId);
      expect(versionsResult.isSuccess, isTrue);
      expect(versionsResult.data, isNotNull);
      expect(versionsResult.data!.length, greaterThanOrEqualTo(1));

      // Cleanup
      await store.deleteEntity(entityId);
      await store.close();
    });

    test('test_admin_get_config', () async {
      final store = await IntegrationHelper.createStoreManager();

      final result = await store.getConfig();
      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.guestMode, isA<bool>());

      await store.close();
    });

    test('test_admin_update_read_auth', () async {
      final store = await IntegrationHelper.createStoreManager();

      // Get current config
      final getResult = await store.getConfig();
      expect(getResult.isSuccess, isTrue);
      final originalGuestMode = getResult.data!.guestMode;

      // Toggle guest mode
      final updateResult = await store.updateGuestMode(
        guestMode: !originalGuestMode,
      );
      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.data!.guestMode, equals(!originalGuestMode));

      // Restore original setting
      final restoreResult = await store.updateGuestMode(
        guestMode: originalGuestMode,
      );
      expect(restoreResult.isSuccess, isTrue);
      expect(restoreResult.data!.guestMode, equals(originalGuestMode));

      await store.close();
    });
  });
}
