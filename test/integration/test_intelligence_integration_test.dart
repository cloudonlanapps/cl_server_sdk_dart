import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Intelligence Integration Tests', () {
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

    test(
      'test_intelligence_features',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        final image = await IntegrationHelper.getTestImage(
          'test_face_single.jpg',
        );

        final createResult = await store.createEntity(
          label: 'Intelligence Test Entity',
          isCollection: false,
          imagePath: image.path,
        );
        expect(createResult.isSuccess, isTrue);
        final entityId = createResult.data!.id;

        try {
          // Wait for processing
          final finalStatus = await store.waitForEntityStatus(
            entityId,
            targetStatus: 'completed',
            timeout: const Duration(seconds: 120),
          );

          expect(finalStatus.status, equals('completed'));

          // Verify entity fields
          final readResult = await store.readEntity(entityId);
          expect(readResult.isSuccess, isTrue);
          final entity = readResult.data!;

          expect(entity.intelligenceData, isNotNull);
          final intel = entity.intelligenceData!;
          expect(intel.overallStatus, equals('completed'));
          expect(intel.faceCount, greaterThan(0));
          expect(intel.inferenceStatus.clipEmbedding, equals('completed'));
          expect(intel.inferenceStatus.dinoEmbedding, equals('completed'));
          expect(intel.inferenceStatus.faceDetection, equals('completed'));

          // Verify jobs list
          final jobsResult = await store.getEntityJobs(entityId);
          expect(jobsResult.isSuccess, isTrue);
          final jobs = jobsResult.data!;
          expect(jobs, isNotEmpty);
          expect(jobs.any((j) => j.taskType == 'clip_embedding'), isTrue);
          expect(jobs.any((j) => j.taskType == 'face_detection'), isTrue);
        } finally {
          await store.deleteEntity(entityId);
        }
      },
    );

    test('test_get_m_insight_status', () async {
      // This is a global status for the intelligence service
      final status = await store.getMInsightStatus();
      expect(status, isNotNull);
      // It should be a Map or similar depending on the exact implementation in StoreManager
    });
  });
}
