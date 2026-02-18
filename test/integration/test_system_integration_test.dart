import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Store System Integration Tests', () {
    test('test_get_audit_report', () async {
      if (!IntegrationTestConfig.isAuthEnabled) return;

      final store = await IntegrationHelper.createStoreManager();

      final result = await store.getAuditReport();
      expect(result.isSuccess, isTrue, reason: result.error);
      expect(result.data, isNotNull);

      final report = result.data!;
      expect(report.orphanedFiles, isA<List<OrphanedFileInfo>>());
      expect(report.orphanedFaces, isA<List<OrphanedFaceInfo>>());
      expect(report.orphanedVectors, isA<List<OrphanedVectorInfo>>());
      expect(report.orphanedMqtt, isA<List<OrphanedMqttInfo>>());
      expect(report.timestamp, isA<int>());

      await store.close();
    });

    test('test_clear_orphans', () async {
      if (!IntegrationTestConfig.isAuthEnabled) return;

      final store = await IntegrationHelper.createStoreManager();

      final result = await store.clearOrphans();
      expect(result.isSuccess, isTrue, reason: result.error);
      expect(result.data, isNotNull);

      final report = result.data!;
      expect(report.filesDeleted, isA<int>());
      expect(report.facesDeleted, isA<int>());
      expect(report.vectorsDeleted, isA<int>());
      expect(report.mqttCleared, isA<int>());
      expect(report.timestamp, isA<int>());

      await store.close();
    });

    test('test_entity_id_autoincrement_no_reuse', () async {
      final store = await IntegrationHelper.createStoreManager();
      final image = await IntegrationHelper.getTestImage();

      // 1. Create unique copies with different perceptual hashes if possible,
      // but here we just need two different entities.
      final temp1 = File('temp_1.jpg');
      await IntegrationHelper.createUniqueCopy(image, temp1, offset: 1);

      // 1. Create first entity
      final res1 = await store.createEntity(
        label: 'Entity One',
        isCollection: false,
        mediaPath: temp1.path,
      );
      expect(res1.isSuccess, isTrue, reason: res1.error);
      final id1 = res1.data!.id;

      // 2. Delete it (hard delete)
      final delRes = await store.deleteEntity(id1);
      expect(delRes.isSuccess, isTrue, reason: delRes.error);

      final temp2 = File('temp_2.jpg');
      await IntegrationHelper.createUniqueCopy(image, temp2, offset: 2);

      // 3. Create second entity
      final res2 = await store.createEntity(
        label: 'Entity Two',
        isCollection: false,
        mediaPath: temp2.path,
      );
      expect(res2.isSuccess, isTrue, reason: res2.error);
      final id2 = res2.data!.id;

      // 4. Verify ID is NOT reused
      expect(
        id2,
        greaterThan(id1),
        reason: 'ID reuse detected! AUTOINCREMENT might be missing.',
      );

      // Cleanup
      await store.deleteEntity(id2);
      if (temp1.existsSync()) await temp1.delete();
      if (temp2.existsSync()) await temp2.delete();
      await store.close();
    });
  });
}
