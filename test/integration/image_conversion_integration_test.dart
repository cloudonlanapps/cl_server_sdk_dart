import 'dart:io';

import 'package:test/test.dart';

import '../auth_test_context.dart';
import '../decision_functions.dart';
import '../test_helpers.dart';

const String testImagePath = '../pysdk/tests/media/images/test_image_1920x1080.jpg';

void main() {
  group('Image Conversion Integration Tests', () {
    testWithAuthMode('Test image conversion with HTTP polling',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        final job = await client.imageConversion.convert(
          image: File(testImagePath),
          outputFormat: 'webp',
          quality: 85,
          wait: true,
          timeout: const Duration(seconds: 30),
        );

        expect(job.status, equals('completed'));
        expect(job.taskOutput, isNotNull);
        expect(job.taskOutput?['output_path'], isNotNull);
        expect(job.taskOutput?['format'], equals('webp'));

        await client.deleteJob(job.jobId);
      } else {
        try {
          await client.imageConversion.convert(
            image: File(testImagePath),
            outputFormat: 'webp',
            wait: true,
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });

    testWithAuthMode('Test image conversion without wait (manual polling)',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        final job = await client.imageConversion.convert(
          image: File(testImagePath),
          outputFormat: 'png',
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
          await client.imageConversion.convert(
            image: File(testImagePath),
            outputFormat: 'png',
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });
  });
}
