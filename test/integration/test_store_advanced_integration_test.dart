import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Store Advanced Integration Tests', () {
    late SessionManager session;
    late StoreManager store;

    setUpAll(() async {
      session = await IntegrationHelper.createSession();
      store = await IntegrationHelper.createStoreManager(session);
      await IntegrationHelper.cleanupStoreEntities();
    });

    tearDownAll(() async {
      await IntegrationHelper.cleanupStoreEntities();
      await session.close();
    });

    test('test_store_advanced_features', () async {
      // 1. Test Hierarchy (Parenting)
      final collectionResult = await store.createEntity(
        label: 'Parent Collection',
        isCollection: true,
      );
      expect(
        collectionResult.isSuccess,
        isTrue,
        reason: collectionResult.error,
      );
      final parentId = collectionResult.data!.id;

      // Use unique image to avoid deduplication
      final tempDir = await Directory.systemTemp.createTemp('adv_store_test');
      final uniqueImage = File('${tempDir.path}/unique_adv.jpg');
      await IntegrationHelper.createUniqueCopy(
        await IntegrationHelper.getTestImage(),
        uniqueImage,
      );

      final childResult = await store.createEntity(
        label: 'Child Media',
        isCollection: false,
        parentId: parentId,
        imagePath: uniqueImage.path,
      );
      expect(childResult.isSuccess, isTrue, reason: childResult.error);
      final childId = childResult.data!.id;

      // Read back to verify parentId (response sometimes omits fields?)
      final readChild = await store.readEntity(childId);
      expect(readChild.isSuccess, isTrue);
      expect(readChild.data!.parentId, equals(parentId));

      // 2. Test Versioning
      // Initial version is 1
      // Update label (Version 2)
      final update1 = await store.updateEntity(
        childId,
        label: 'Child Media V2',
        isCollection: false,
        parentId: parentId,
      );
      expect(update1.isSuccess, isTrue, reason: update1.error);

      // Update description via Patch (Version 3)
      final patch1 = await store.patchEntity(
        childId,
        description: 'Version 3 description',
      );
      expect(patch1.isSuccess, isTrue);

      // Check versions
      final versionsResult = await store.getVersions(childId);
      expect(versionsResult.isSuccess, isTrue);
      // There should be at least 3 versions (create, update, patch)
      expect(versionsResult.data!.length, greaterThanOrEqualTo(3));

      // Read specific version
      final v1Result = await store.readEntity(childId, version: 1);
      expect(v1Result.isSuccess, isTrue);
      expect(v1Result.data!.label, equals('Child Media'));

      final v2Result = await store.readEntity(childId, version: 2);
      expect(v2Result.isSuccess, isTrue);
      expect(v2Result.data!.label, equals('Child Media V2'));

      // 3. Test pagination and search in listEntities
      final listResult = await store.listEntities(searchQuery: 'Parent');
      expect(listResult.isSuccess, isTrue);
      expect(
        listResult.data!.items.any((e) => e.label?.contains('Parent') ?? false),
        isTrue,
      );

      // 4. Test Error Response (404)
      final readNonExistent = await store.readEntity(999999);
      expect(readNonExistent.isError, isTrue);
      expect(readNonExistent.statusCode, equals(404));

      // 5. Test Bulk Delete via IntegrationHelper
      await IntegrationHelper.cleanupStoreEntities();

      // Verify empty
      final emptyList = await store.listEntities();
      expect(emptyList.isSuccess, isTrue);
      expect(emptyList.data!.items, isEmpty);
    });
  });
}
