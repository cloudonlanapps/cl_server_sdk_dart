import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Full Embedding Flow Integration Tests', () {
    late SessionManager session;
    late StoreManager store;

    setUpAll(() async {
      session = await IntegrationHelper.createSession();
      store = await IntegrationHelper.createStoreManager(session);
    });

    tearDownAll(() async {
      await session.close();
    });

    const testImages = [
      ('test_face_single.jpg', 2),
      ('test_image_1920x1080.jpg', 0),
      ('IMG20240901130125.jpg', 3),
    ];

    test('test_full_embedding_flow', () async {
      final timeout = const Duration(minutes: 5);
      final createdEntities = <Map<String, dynamic>>[];

      try {
        // 1. Upload all test images
        for (final entry in testImages) {
          final filename = entry.$1;
          final expectedFaces = entry.$2;

          final sourceFile = await IntegrationHelper.getTestImage(filename);
          expect(
            sourceFile.existsSync(),
            isTrue,
            reason: 'Test image not found: $filename',
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'full_flow_unique',
          );
          final uniqueImage = File('${tempDir.path}/unique_$filename');
          await IntegrationHelper.createUniqueCopy(sourceFile, uniqueImage);

          //print('Uploading $filename...');
          final createResult = await store.createEntity(
            isCollection: false,
            label: 'Test Integration $filename',
            imagePath: uniqueImage.path,
          );

          expect(
            createResult.isSuccess,
            isTrue,
            reason:
                'Failed to create entity for $filename: ${createResult.error}',
          );
          final entity = createResult.data!;
          createdEntities.add({
            'entity': entity,
            'expectedFaces': expectedFaces,
            'filename': filename,
          });
        }

        // 2. Verify processing for each entity
        for (final data in createdEntities) {
          final entity = data['entity'] as Entity;
          final expectedFaces = data['expectedFaces'] as int;
          final filename = data['filename'] as String;

          /*print(
            'Waiting for entity ${entity.id} ($filename) to complete processing...',
          );*/

          final statusResult = await store.waitForEntityStatus(
            entity.id,
            targetStatus: 'completed',
            timeout: timeout,
          );

          expect(statusResult.status, equals('completed'));

          // Verify artifacts
          //print('Verifying artifacts for entity ${entity.id}...');

          // Face Count
          final facesResult = await store.getEntityFaces(entity.id);
          expect(facesResult.isSuccess, isTrue);
          final faces = facesResult.data!;
          expect(
            faces.length,
            equals(expectedFaces),
            reason: 'Face count mismatch for $filename',
          );

          // CLIP Embedding
          final clipResult = await store.downloadEntityClipEmbedding(entity.id);
          expect(
            clipResult.isSuccess,
            isTrue,
            reason: 'Failed to download CLIP embedding',
          );
          expect(clipResult.data!.length, greaterThan(0));

          // DINO Embedding
          final dinoResult = await store.downloadEntityDinoEmbedding(entity.id);
          expect(
            dinoResult.isSuccess,
            isTrue,
            reason: 'Failed to download DINO embedding',
          );
          expect(dinoResult.data!.length, greaterThan(0));

          // Face Embeddings
          if (expectedFaces > 0) {
            for (final face in faces) {
              final faceEmbResult = await store.downloadFaceEmbedding(face.id);
              expect(
                faceEmbResult.isSuccess,
                isTrue,
                reason: 'Failed to download face embedding ${face.id}',
              );
              expect(faceEmbResult.data!.length, greaterThan(0));
            }
          }
        }
      } finally {
        // Cleanup
        for (final data in createdEntities) {
          final entity = data['entity'] as Entity;
          await store.deleteEntity(entity.id);
        }
      }
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}
