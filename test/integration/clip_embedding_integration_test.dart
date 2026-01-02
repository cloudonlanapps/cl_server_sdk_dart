import 'dart:io';

import 'package:test/test.dart';

import '../auth_test_context.dart';
import '../decision_functions.dart';
import '../test_helpers.dart';

/// Integration tests for clip_embedding plugin
///
/// These tests require a running server, worker, and MQTT broker.
/// Tests run in multiple auth modes: admin, user-with-permission,
/// user-no-permission, no-auth.

const String testImagePath = '../pysdk/tests/media/images/test_image_800x600.png';

void main() {
  group('CLIP Embedding Integration Tests', () {
    testWithAuthMode('Test CLIP embedding with HTTP polling (wait=true)',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        // Should succeed - run normal assertions
        final job = await client.clipEmbedding.embedImage(
          image: File(testImagePath),
          wait: true,
          timeout: const Duration(seconds: 30),
        );

        // Verify completion
        expect(job.status, equals('completed'));
        expect(job.taskOutput, isNotNull);

        // Verify embedding exists
        expect(job.taskOutput?['embedding'], isNotNull);

        // Cleanup
        await client.deleteJob(job.jobId);
      } else {
        // Should fail - expect auth error
        try {
          await client.clipEmbedding.embedImage(
            image: File(testImagePath),
            wait: true,
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          // Expected error
          expect(e, isNotNull);
        }
      }
    });

    testWithAuthMode('Test CLIP embedding without wait (manual polling)',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        // Should succeed - submit job without waiting
        final job = await client.clipEmbedding.embedImage(
          image: File(testImagePath),
        );

        // Wait for completion manually using polling
        final completedJob = await client.waitForJobCompletionWithPolling(
          job.jobId,
          timeout: const Duration(seconds: 30),
        );

        // Verify job completed
        expect(completedJob.status, equals('completed'));
        expect(completedJob.taskOutput, isNotNull);

        // Cleanup
        await client.deleteJob(job.jobId);
      } else {
        // Should fail - expect auth error
        try {
          await client.clipEmbedding.embedImage(
            image: File(testImagePath),
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          // Expected error
          expect(e, isNotNull);
        }
      }
    });
  });
}
