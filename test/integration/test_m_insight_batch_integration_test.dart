import 'dart:io';
import 'dart:math';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('MInsight Batch Integration Tests', () {
    late SessionManager session;
    late StoreManager store;

    setUpAll(() async {
      session = await IntegrationHelper.createSession();
      store = await IntegrationHelper.createStoreManager(session);
    });

    tearDownAll(() async {
      await session.close();
    });

    test(
      'test_m_insight_batch_upload_and_queue',
      () async {
        // 1. Verify MInsight worker is online
        final statusResult = await store.getMInsightStatus();
        expect(
          statusResult.isSuccess,
          isTrue,
          reason: 'Failed to get MInsight status: ${statusResult.error}',
        );

        final status = statusResult.data;
        expect(status, isNotNull);
        final workerStatus = status!['status'];
        expect(
          ['running', 'idle'],
          contains(workerStatus),
          reason: 'MInsight worker not online. Status: $workerStatus',
        );

        // 2. Upload batch of unique images
        const numImages = 10; // Reduced from 30 for CI/test efficiency
        print('Uploading $numImages unique images...');

        final sourceImage = await IntegrationHelper.getTestImage();
        final entityIds = <int>[];

        for (var i = 0; i < numImages; i++) {
          final tempDir = await Directory.systemTemp.createTemp('batch_upload');
          final uniquePath = File('${tempDir.path}/batch_$i.jpg');
          await IntegrationHelper.createUniqueCopy(
            sourceImage,
            uniquePath,
            offset: i,
          );

          final res = await store.createEntity(
            label: 'Batch_Test_$i',
            isCollection: false,
            imagePath: uniquePath.path,
          );

          expect(
            res.isSuccess,
            isTrue,
            reason: 'Upload failed for index $i: ${res.error}',
          );
          entityIds.add(res.data!.id);
        }

        print(
          'Successfully uploaded ${entityIds.length} images. Waiting for queuing...',
        );

        // 3. Poll for intelligence status
        final timeout = Duration(seconds: max(60, numImages * 5));
        final startTime = DateTime.now();
        final pendingIds = Set<int>.from(entityIds);

        while (pendingIds.isNotEmpty &&
            DateTime.now().difference(startTime) < timeout) {
          for (final id in List<int>.from(pendingIds)) {
            final res = await store.getEntityIntelligence(id);
            if (res.isSuccess && res.data != null) {
              final overallStatus = res.data!.overallStatus;
              if ([
                'queued',
                'processing',
                'completed',
              ].contains(overallStatus)) {
                pendingIds.remove(id);
              }
            }
          }

          if (pendingIds.isNotEmpty) {
            print(
              '  ${pendingIds.length} images still not picked up by MInsight...',
            );
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        }

        // Final check
        if (pendingIds.isNotEmpty) {
          fail(
            'Timed out waiting for ${pendingIds.length} images to be queued by MInsight.',
          );
        }

        print('All images successfully queued by MInsight!');

        // 4. Cleanup
        print('Cleaning up batch entities...');
        for (final id in entityIds) {
          await store.deleteEntity(id);
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
