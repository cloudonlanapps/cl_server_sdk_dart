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

          // Verify intelligence jobs completed (matches Python SDK approach)
          final jobsListResult = await store.getEntityJobs(entityId);
          expect(jobsListResult.isSuccess, isTrue);
          final allJobs = jobsListResult.data!;
          final intelligenceJobTypes = ['clip_embedding', 'face_detection', 'dino_embedding'];

          // Verify all intelligence jobs exist and are completed (matches Python SDK)
          expect(allJobs, isNotEmpty, reason: 'Should have intelligence jobs');
          for (final jobType in intelligenceJobTypes) {
            final job = allJobs.firstWhere(
              (j) => j.taskType == jobType,
              orElse: () => throw Exception('$jobType job not found'),
            );
            // Jobs should already be completed since entity status is completed
            expect(job.status, equals('completed'),
              reason: '$jobType job should be completed');
          }

          // 3. Test Person Management
          final facesResult = await store.getEntityFaces(entityId);
          expect(facesResult.isSuccess, isTrue);
          final faces = facesResult.data!;
          if (faces.isNotEmpty && faces[0].knownPersonId != null) {
            final personId = faces[0].knownPersonId!;
            print('Testing person name update for $personId...');
            final newName =
                'Test Person Update ${DateTime.now().millisecondsSinceEpoch}';
            final updateRes = await store.updateKnownPersonName(
              personId,
              newName,
            );
            expect(updateRes.isSuccess, isTrue);
            expect(updateRes.data!.name, equals(newName));

            // Verify update persisted
            final personRes = await store.getKnownPerson(personId);
            expect(personRes.isSuccess, isTrue);
            expect(personRes.data!.name, equals(newName));
          }
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

    test('test_delete_face', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_face_single.jpg',
      );

      final createResult = await store.createEntity(
        label: 'Face Delete Test',
        isCollection: false,
        imagePath: image.path,
      );
      expect(createResult.isSuccess, isTrue);
      final entityId = createResult.data!.id;

      try {
        // Wait for processing to get faces
        await store.waitForEntityStatus(
          entityId,
          targetStatus: 'completed',
          timeout: const Duration(seconds: 120),
        );

        final facesResult = await store.getEntityFaces(entityId);
        expect(facesResult.isSuccess, isTrue);
        final faces = facesResult.data!;
        expect(faces, isNotEmpty);
        final faceId = faces[0].id;

        // Delete face
        final deleteRes = await store.deleteFace(faceId);
        if (!deleteRes.isSuccess &&
            deleteRes.error!.contains('Face service not available')) {
          print(
            'Skipping face deletion verification: Face service not available',
          );
          return;
        }
        expect(deleteRes.isSuccess, isTrue, reason: deleteRes.error);

        // Verify face is gone
        final afterDeleteFaces = await store.getEntityFaces(entityId);
        expect(afterDeleteFaces.isSuccess, isTrue);
        expect(afterDeleteFaces.data!.any((f) => f.id == faceId), isFalse);
      } finally {
        await store.deleteEntity(entityId);
      }
    });
  });
}
