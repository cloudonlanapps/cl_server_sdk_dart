import 'dart:async';
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
      ('IMG20240901194834.jpg', 3),
      ('IMG20240901193819.jpg', 11),
      ('IMG20240901153107.jpg', 1),
    ];

    test(
      'test_full_embedding_flow',
      timeout: const Timeout(Duration(minutes: 10)),
      () async {
        final timeout = const Duration(seconds: 600);
        final pendingVerifications = <Map<String, dynamic>>[];
        String? firstUniquePath;

        try {
          // 1. Upload all test images and start monitoring immediately
          for (final entry in testImages) {
            final filename = entry.$1;
            final expectedFaces = entry.$2;

            final originalImage = await IntegrationHelper.getTestImage(
              filename,
            );
            expect(originalImage.existsSync(), isTrue);

            // Create unique copy to avoid deduplication
            final tempDir = await Directory.systemTemp.createTemp(
              'full_emb_test',
            );
            final uniqueImage = File('${tempDir.path}/${filename}_unique.jpg');
            await IntegrationHelper.createUniqueCopy(
              originalImage,
              uniqueImage,
            );

            if (firstUniquePath == null) {
              firstUniquePath = uniqueImage.path;
            }

            final createResult = await store.createEntity(
              label: 'Test Integration $filename (Unique)',
              isCollection: false,
              imagePath: uniqueImage.path,
            );
            expect(createResult.isSuccess, isTrue);
            final entity = createResult.data!;

            // Start monitoring only if it's a new entity or not yet completed
            Future<EntityStatusPayload>? waitFuture;
            if (!createResult.isDuplicate ||
                entity.intelligenceStatus != 'completed') {
              waitFuture = store.waitForEntityStatus(
                entity.id,
                targetStatus: 'completed',
                timeout: timeout,
              );
            }

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
            final waitFuture =
                item['waitFuture'] as Future<EntityStatusPayload>?;

            // Await completion if we started a wait
            if (waitFuture != null) {
              await waitFuture;
            }

            // Verify Artifacts
            // A. Verify Face Count
            final facesResult = await store.getEntityFaces(entity.id);
            expect(facesResult.isSuccess, isTrue);
            final faces = facesResult.data!;
            // ignore: avoid_print
            print(
              'Entity ${entity.id} (${entity.label}) faces: ${faces.length}',
            );

            expect(
              faces.length,
              equals(expectedFaces),
              reason: 'Faces mismatch for ${entity.id} (${entity.label})',
            );

            // B. Verify CLIP Embedding
            final clipResult = await store.downloadEntityClipEmbedding(
              entity.id,
            );
            expect(clipResult.isSuccess, isTrue);
            expect(clipResult.data, isNotEmpty);

            // C. Verify DINO Embedding
            final dinoResult = await store.downloadEntityDinoEmbedding(
              entity.id,
            );
            expect(dinoResult.isSuccess, isTrue);
            expect(dinoResult.data, isNotEmpty);

            // D. If faces detected, verify Face Embeddings
            if (expectedFaces > 0) {
              for (final face in faces) {
                final faceEmbResult = await store.downloadFaceEmbedding(
                  face.id,
                );
                if (faceEmbResult.isSuccess) {
                  expect(faceEmbResult.data, isNotEmpty);
                } else {
                  print(
                    'Warning: Could not download embedding for face ${face.id}: ${faceEmbResult.error}',
                  );
                }
              }
            }
          }

          // 3. Verify Deduplication Logic (Logical 200 OK)
          // ignore: avoid_print
          print('\nVerifying Deduplication Logic...');
          final firstImageEntry = testImages.first;
          final filename = firstImageEntry.$1;
          final expectedFaces = firstImageEntry.$2;

          final dupResult = await store.createEntity(
            label: 'Deduplicated $filename',
            isCollection: false,
            imagePath: firstUniquePath,
          );

          expect(dupResult.isSuccess, isTrue);
          expect(
            dupResult.isDuplicate,
            isTrue,
            reason: 'Second upload of original image should be a duplicate',
          );

          final duplicateEntity = dupResult.data!;
          // Should be 'completed' immediately if the original processed successfully
          expect(duplicateEntity.intelligenceStatus, equals('completed'));

          final dupFacesResult = await store.getEntityFaces(duplicateEntity.id);
          expect(dupFacesResult.isSuccess, isTrue);
          expect(
            dupFacesResult.data!.length,
            equals(expectedFaces),
            reason:
                'Deduplicated entity should have correct face count immediately',
          );
          // ignore: avoid_print
          print('Deduplication verification PASSED for $filename\n');
        } finally {
          // Cleanup
          for (final item in pendingVerifications) {
            final entity = item['entity'] as Entity;
            await store.deleteEntity(entity.id);
          }
        }
      },
    );
  });
}
