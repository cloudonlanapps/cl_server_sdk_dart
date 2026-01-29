import 'dart:async';
import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('M-Insight Batch Integration Tests', () {
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

    test(
      'test_m_insight_batch_upload_and_queue',
      () async {
        // 1. Verify M-Insight worker is online
        final statusResult = await store.getMInsightStatus();
        expect(statusResult.isSuccess, isTrue, reason: statusResult.error);

        final status = statusResult.data;
        expect(status, isNotNull);
        expect(['running', 'idle'], contains(status!['status']));

        // 2. Upload images in parallel
        const numImages = 10; // Reduced from 30 for faster test performance
        print('Uploading $numImages unique images...');

        final testImage = await IntegrationHelper.getTestImage();
        final tempDir = await Directory.systemTemp.createTemp('batch_test');

        try {
          final uploadTasks = <Future<StoreOperationResult<Entity>>>[];

          for (var i = 0; i < numImages; i++) {
            final uniqueFile = File('${tempDir.path}/batch_$i.jpg');
            await IntegrationHelper.createUniqueCopy(
              testImage,
              uniqueFile,
              offset: i,
            );

            uploadTasks.add(
              store.createEntity(
                label: 'Batch_Test_$i',
                isCollection: false,
                imagePath: uniqueFile.path,
              ),
            );
          }

          final results = await Future.wait(uploadTasks);
          final entityIds = <int>[];

          for (final r in results) {
            expect(r.isSuccess, isTrue, reason: 'Upload failed: ${r.error}');
            entityIds.add(r.data!.id);
          }

          print('Successfully uploaded ${entityIds.length} images.');

          // 3. Poll for intelligenceStatus
          const timeout = Duration(seconds: 120);
          final startTime = DateTime.now();
          final pendingIds = entityIds.toSet();

          print('Waiting for M-Insight to queue images...');

          while (pendingIds.isNotEmpty &&
              DateTime.now().difference(startTime) < timeout) {
            final listResult = await store.listEntities(pageSize: 100);
            expect(listResult.isSuccess, isTrue);

            for (final item in listResult.data!.items) {
              if (pendingIds.contains(item.id)) {
                final status = item.intelligenceStatus;
                if (['queued', 'processing', 'completed'].contains(status)) {
                  pendingIds.remove(item.id);
                }
              }
            }

            if (pendingIds.isNotEmpty) {
              print(
                '  ${pendingIds.length} images still not picked up by M-Insight...',
              );
              await Future<void>.delayed(const Duration(seconds: 2));
            }
          }

          expect(
            pendingIds,
            isEmpty,
            reason:
                'Timed out waiting for images to be queued by M-Insight. Pending: $pendingIds',
          );
          print('All images successfully queued by M-Insight!');
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
