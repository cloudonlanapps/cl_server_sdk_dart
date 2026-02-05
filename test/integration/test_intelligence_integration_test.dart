import 'dart:developer';
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
            timeout: const Duration(seconds: 120),
          );

          expect(finalStatus.status, equals('completed'));

          // Verify intelligence jobs completed (matches Python SDK approach)
          final jobsListResult = await store.getEntityJobs(entityId);
          expect(jobsListResult.isSuccess, isTrue);
          final allJobs = jobsListResult.data!;
          final intelligenceJobTypes = [
            'clip_embedding',
            'face_detection',
            'dino_embedding',
          ];

          // Verify all intelligence jobs exist and are completed (matches Python SDK)
          expect(allJobs, isNotEmpty, reason: 'Should have intelligence jobs');
          for (final jobType in intelligenceJobTypes) {
            final job = allJobs.firstWhere(
              (j) => j.taskType == jobType,
              orElse: () => throw Exception('$jobType job not found'),
            );
            // Jobs should already be completed since entity status is completed
            expect(
              job.status,
              equals('completed'),
              reason: '$jobType job should be completed',
            );
          }

          // 3. Test Person Management
          final facesResult = await store.getEntityFaces(entityId);
          expect(facesResult.isSuccess, isTrue);
          final faces = facesResult.data!;
          if (faces.isNotEmpty && faces[0].knownPersonId != null) {
            final personId = faces[0].knownPersonId!;
            log('Testing person name update for $personId...');
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

    test(
      'test_consolidated_deletion_flow',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        final image = await IntegrationHelper.getTestImage(
          'test_face_single.jpg',
        );

        // 1. Create Entity and Wait for Processing
        final createResult = await store.createEntity(
          label: 'Consolidated Delete Test',
          isCollection: false,
          imagePath: image.path,
        );
        expect(createResult.isSuccess, isTrue);
        final entityId = createResult.data!.id;

        try {
          // Wait for processing to get faces
          await store.waitForEntityStatus(
            entityId,
            timeout: const Duration(seconds: 120),
          );

          // 2. Verify initial state (Faces exist)
          final intelResult = await store.getEntityIntelligence(entityId);
          expect(intelResult.isSuccess, isTrue);
          final initialFaceCount = intelResult.data?.faceCount ?? 0;
          expect(
            initialFaceCount,
            greaterThan(0),
            reason: 'Should have at least one face',
          );

          final facesResult = await store.getEntityFaces(entityId);
          expect(facesResult.isSuccess, isTrue);
          final faces = facesResult.data!;
          expect(faces.length, equals(initialFaceCount));

          final faceIdToDelete = faces[0].id;

          // 3. Delete one face
          final deleteRes = await store.deleteFace(faceIdToDelete);
          expect(deleteRes.isSuccess, isTrue, reason: deleteRes.error);

          // 4. Verify cleanup (Face gone, count decremented)
          final afterDeleteFacesResult = await store.getEntityFaces(entityId);
          expect(afterDeleteFacesResult.isSuccess, isTrue);
          expect(
            afterDeleteFacesResult.data!.any((f) => f.id == faceIdToDelete),
            isFalse,
            reason: 'Face should be removed from face list',
          );

          final afterDeleteIntelResult = await store.getEntityIntelligence(
            entityId,
          );
          expect(afterDeleteIntelResult.isSuccess, isTrue);
          expect(
            afterDeleteIntelResult.data?.faceCount,
            equals(initialFaceCount - 1),
            reason: 'Face count should be decremented',
          );

          // 5. Delete Entity (Full Cleanup)
          final entityDeleteRes = await store.deleteEntity(entityId);
          expect(entityDeleteRes.isSuccess, isTrue);

          // Verify entity gone
          final readRes = await store.readEntity(entityId);
          expect(readRes.error, contains('Not Found'));
        } finally {
          // Final cleanup
          await store.deleteEntity(entityId);
        }
      },
    );
  });
}
