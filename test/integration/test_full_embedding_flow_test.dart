import 'dart:async';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Full Embedding Flow Integration Tests', () {
    late SessionManager session;
    late StoreManager store;

    setUpAll(() async {
      session = await IntegrationHelper.createSession();
      store = session.createStoreManager();
    });

    tearDownAll(() async {
      await store.close();
      await session.close();
    });

    // Define test cases: (image_filename, expected_face_count)
    final testImages = [
      ('test_face_single.jpg', 2),
      ('test_image_1920x1080.jpg', 0),
      ('IMG20240901130125.jpg', 3),
      ('IMG20240901202523.jpg', 5),
    ];

    test('test_full_embedding_flow', () async {
      final timeout = const Duration(seconds: 300);
      final pendingVerifications = <Map<String, dynamic>>[];

      try {
        // 1. Upload all test images and start monitoring immediately
        for (final entry in testImages) {
          final filename = entry.$1;
          final expectedFaces = entry.$2;

          final imageFile = await IntegrationHelper.getTestImage(filename);
          expect(imageFile.existsSync(), isTrue);

          final createResult = await store.createEntity(
            label: 'Test Integration $filename',
            isCollection: false,
            imagePath: imageFile.path,
          );
          expect(createResult.isSuccess, isTrue);
          final entity = createResult.data!;

          // Start monitoring
          final waitFuture = store.waitForEntityStatus(
            entity.id,
            targetStatus: 'completed',
            timeout: timeout,
          );

          pendingVerifications.add({
            'entity': entity,
            'expectedFaces': expectedFaces,
            'waitFuture': waitFuture,
          });
        }

        // 2. Verify processing for each entity
        for (final item in pendingVerifications) {
          final entity = item['entity'] as Entity;
          final expectedFaces = item['expectedFaces'] as int;
          final waitFuture = item['waitFuture'] as Future<EntityStatusPayload>;

          // Await completion
          await waitFuture;

          // Verify Artifacts

          // A. Verify Face Count
          final facesResult = await store.getEntityFaces(entity.id);
          expect(facesResult.isSuccess, isTrue);
          final faces = facesResult.data!;
          expect(
            faces.length,
            equals(expectedFaces),
            reason: 'Faces mismatch for ${entity.label}',
          );

          // B. Verify CLIP Embedding
          final clipResult = await store.downloadEntityClipEmbedding(entity.id);
          expect(clipResult.isSuccess, isTrue);
          expect(clipResult.data, isNotEmpty);

          // C. Verify DINO Embedding
          final dinoResult = await store.downloadEntityDinoEmbedding(entity.id);
          expect(dinoResult.isSuccess, isTrue);
          expect(dinoResult.data, isNotEmpty);

          // D. If faces detected, verify Face Embeddings
          if (expectedFaces > 0) {
            for (final face in faces) {
              final faceEmbResult = await store.downloadFaceEmbedding(face.id);
              expect(faceEmbResult.isSuccess, isTrue);
              expect(faceEmbResult.data, isNotEmpty);
            }
          }
        }
      } finally {
        // Cleanup
        for (final item in pendingVerifications) {
          final entity = item['entity'] as Entity;
          await store.deleteEntity(entity.id);
        }
      }
    });
  });
}
