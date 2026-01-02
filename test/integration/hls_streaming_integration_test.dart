import 'dart:io';

import 'package:test/test.dart';

import '../auth_test_context.dart';
import '../decision_functions.dart';
import '../test_helpers.dart';

const String testVideoPath = '../pysdk/tests/media/videos/test_video.mp4';

void main() {
  group('HLS Streaming Integration Tests', () {
    testWithAuthMode('Test HLS streaming conversion with HTTP polling',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        final job = await client.hlsStreaming.generateManifest(
          video: File(testVideoPath),
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, equals('completed'));
        expect(job.taskOutput, isNotNull);
        expect(job.taskOutput?['playlist_path'], isNotNull);
        expect(job.taskOutput?['segment_count'], isNotNull);

        await client.deleteJob(job.jobId);
      } else {
        try {
          await client.hlsStreaming.generateManifest(
            video: File(testVideoPath),
            wait: true,
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });

    testWithAuthMode(
        'Test HLS streaming conversion without wait (manual polling)',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        final job = await client.hlsStreaming.generateManifest(
          video: File(testVideoPath),
        );

        final completedJob = await client.waitForJobCompletionWithPolling(
          job.jobId,
          timeout: const Duration(seconds: 60),
        );

        expect(completedJob.status, equals('completed'));
        expect(completedJob.taskOutput, isNotNull);

        await client.deleteJob(job.jobId);
      } else {
        try {
          await client.hlsStreaming.generateManifest(
            video: File(testVideoPath),
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });
  });
}
