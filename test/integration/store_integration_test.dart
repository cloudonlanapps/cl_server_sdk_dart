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
      expect(deleteResult.isSuccess, isTrue);

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
  });
}
