import 'dart:async';
import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Timeout Fix Verification Tests', () {
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

    test('test_concurrent_uploads_with_timeout_fix', () async {
      // Use a few images to avoid overwhelming the server but enough to test concurrency
      final testImages = [
        'test_face_single.jpg',
        'test_image_1920x1080.jpg',
        'IMG20240901130125.jpg',
      ];

      final tempDir = await Directory.systemTemp.createTemp('timeout_test');
      final createdEntities = <Entity>[];

      try {
        final uploadTasks = <Future<StoreOperationResult<Entity>>>[];

        for (final imageName in testImages) {
          final sourceFile = await IntegrationHelper.getTestImage(imageName);
          final uniqueFile = File('${tempDir.path}/unique_$imageName');

          await IntegrationHelper.createUniqueCopy(sourceFile, uniqueFile);

          //log('Uploading $imageName (unique copy)...');
          uploadTasks.add(
            store.createEntity(
              label: 'Test Timeout Fix $imageName',
              isCollection: false,
              mediaPath: uniqueFile.path,
            ),
          );
        }

        // Execute concurrent uploads
        final results = await Future.wait(uploadTasks);

        for (var i = 0; i < results.length; i++) {
          final result = results[i];
          final imageName = testImages[i];

          expect(
            result.isSuccess,
            isTrue,
            reason: 'Upload failed for $imageName: ${result.error}',
          );
          expect(result.data, isNotNull);

          createdEntities.add(result.data!);
          //log('Created entity ${result.data!.id} for $imageName');
        }

        /*log(
          'Successfully uploaded ${createdEntities.length} images concurrently.',
        );*/
      } finally {
        await tempDir.delete(recursive: true);

        // Cleanup created entities
        for (final entity in createdEntities) {
          await store.deleteEntity(entity.id);
        }
      }
    }); // Default timeout is usually enough, but we rely on the client's internal timeout + test timeout
  }, timeout: const Timeout(Duration(minutes: 5)));
}
