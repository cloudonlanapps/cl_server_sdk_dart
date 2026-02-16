/* import 'dart:io';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import 'integration_test_utils.dart';

void main() {
  group('Store Multimedia Integration Tests', () {
    late SessionManager session;
    late StoreManager store;
    int? collectionId;
    int? entityId;
    File? testImage;

    setUpAll(() async {
      session = await IntegrationHelper.createSession();
      store = await IntegrationHelper.createStoreManager(session);
      testImage = await IntegrationHelper.getTestImage();
    });

    tearDownAll(() async {
      if (entityId != null) {
        try {
          await store.deleteEntity(entityId!);
        } catch (_) {}
      }
      if (collectionId != null) {
        try {
          await store.deleteEntity(collectionId!);
        } catch (_) {}
      }
      await session.close();
    });

    test('Create collection, upload image, filter, and download', () async {
      // 1. Create Collection
      final collectionRes = await store.createEntity(
        isCollection: true,
        label: 'Dart Integration Test Collection',
        description: 'Testing multimedia features from Dart',
      );
      expect(collectionRes.isSuccess, isTrue);
      collectionId = collectionRes.data!.id;
      expect(collectionId, isNotNull);

      // 2. Upload Image
      final entityRes = await store.createEntity(
        isCollection: false,
        label: 'Dart Test Image',
        description: 'A test image file',
        parentId: collectionId,
        imagePath: testImage!.path,
      );
      expect(entityRes.isSuccess, isTrue);
      entityId = entityRes.data!.id;
      final mimeType = entityRes.data!.mimeType;
      expect(mimeType, isNotNull);

      // 3. List with Filter
      final listRes = await store.listEntities(
        mimeType: mimeType,
        pageSize: 10,
      );
      expect(listRes.isSuccess, isTrue);
      final found = listRes.data!.items.any((item) => item.id == entityId);
      expect(
        found,
        isTrue,
        reason: 'Entity $entityId not found with mimeType filter $mimeType',
      );

      // 4. Download Media
      final mediaRes = await store.downloadMedia(entityId!);
      expect(mediaRes.isSuccess, isTrue);
      expect(mediaRes.data, isNotNull);
      expect(mediaRes.data!.length, greaterThan(0));

      // 5. Get Stream URL
      final streamUrl = store.getStreamUrl(entityId!);
      expect(streamUrl, contains('/entities/$entityId/stream/adaptive.m3u8'));

      // 6. Download Preview (might fail if not ready, but ensure call works)
      final previewRes = await store.downloadPreview(entityId!);
      // We don't assert success here as generation is async, but we check if it throws
      if (previewRes.isSuccess) {
        expect(previewRes.data!.length, greaterThan(0));
      }
    });
  });
}
 */
