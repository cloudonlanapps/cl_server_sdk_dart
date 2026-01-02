import 'dart:io';

import 'package:test/test.dart';

import '../auth_test_context.dart';
import '../decision_functions.dart';
import '../test_helpers.dart';

const String testImagePath = '../pysdk/tests/media/images/test_image_1920x1080.jpg';

void main() {
  group('Media Thumbnail Integration Tests', () {
    testWithAuthMode('Test media thumbnail generation with HTTP polling',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        final job = await client.mediaThumbnail.generate(
          media: File(testImagePath),
          width: 300,
          height: 200,
          wait: true,
          timeout: const Duration(seconds: 30),
        );

        expect(job.status, equals('completed'));
        expect(job.taskOutput, isNotNull);
        expect(job.taskOutput?['thumbnail_path'], isNotNull);
        expect(job.taskOutput?['width'], equals(300));
        expect(job.taskOutput?['height'], equals(200));

        await client.deleteJob(job.jobId);
      } else {
        try {
          await client.mediaThumbnail.generate(
            media: File(testImagePath),
            width: 300,
            height: 200,
            wait: true,
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });

    testWithAuthMode(
        'Test media thumbnail generation without wait (manual polling)',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        final job = await client.mediaThumbnail.generate(
          media: File(testImagePath),
          width: 150,
          height: 150,
        );

        final completedJob = await client.waitForJobCompletionWithPolling(
          job.jobId,
          timeout: const Duration(seconds: 30),
        );

        expect(completedJob.status, equals('completed'));
        expect(completedJob.taskOutput, isNotNull);

        await client.deleteJob(job.jobId);
      } else {
        try {
          await client.mediaThumbnail.generate(
            media: File(testImagePath),
            width: 150,
            height: 150,
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });
  });
}
