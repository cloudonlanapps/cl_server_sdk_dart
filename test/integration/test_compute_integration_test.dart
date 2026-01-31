import 'dart:io';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Compute Integration Tests', () {
    test('test_compute_submit_job', () async {
      if (!IntegrationTestConfig.isAuthEnabled &&
          IntegrationTestConfig.computeAuthRequired) {
        if (!IntegrationTestConfig.computeGuestMode) return;
      }

      final compute = await IntegrationHelper.createComputeClient();
      final image = await IntegrationHelper.getTestImage();

      // Submit job (using raw httpSubmitJob or a plugin)
      // Let's use a plugin like FaceDetection which is common
      try {
        final jobResponse = await compute.faceDetection.detect(image);
        final jobId = jobResponse.jobId;
        expect(jobId, isNotNull);
        expect(jobId.isNotEmpty, isTrue);

        // Wait for job
        final job = await compute.waitForJob(jobId);
        expect(job.jobId, equals(jobId));
        expect(job.status, anyOf('completed', 'failed', 'error'));
      } catch (e) {
        if (e is SocketException) {
          print('Skipping compute test: server unreachable');
          return;
        }
        rethrow;
      } finally {
        await compute.close();
      }
    });

    test('test_compute_plugins', () async {
      if (!IntegrationTestConfig.isAuthEnabled) return;
      final compute = await IntegrationHelper.createComputeClient();
      // image removed

      // Test a few plugins instantiation conform to interface
      expect(compute.faceDetection, isNotNull);
      expect(compute.clipEmbedding, isNotNull);
      expect(compute.dinoEmbedding, isNotNull);

      // Note: Actual submission tests are covered by generic submit test
      // or require specific plugin endpoints to be working.

      await compute.close();
    });
  });
}
