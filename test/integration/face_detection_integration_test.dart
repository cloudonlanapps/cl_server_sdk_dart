import 'dart:io';

import 'package:test/test.dart';

import '../auth_test_context.dart';
import '../decision_functions.dart';
import '../test_helpers.dart';

const String testImagePath = '../pysdk/tests/media/images/test_face_single.jpg';

void main() {
  group('Face Detection Integration Tests', () {
    testWithAuthMode('Test face detection with HTTP polling',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        final job = await client.faceDetection.detect(
          image: File(testImagePath),
          wait: true,
          timeout: const Duration(seconds: 30),
        );

        expect(job.status, equals('completed'));
        expect(job.taskOutput, isNotNull);

        await client.deleteJob(job.jobId);
      } else {
        try {
          await client.faceDetection.detect(
            image: File(testImagePath),
            wait: true,
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });

    testWithAuthMode('Test face detection without wait (manual polling)',
        (AuthTestContext context) async {
      final client = await createTestComputeClient(context);

      if (shouldSucceed(context, OperationType.plugin)) {
        final job = await client.faceDetection.detect(
          image: File(testImagePath),
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
          await client.faceDetection.detect(
            image: File(testImagePath),
          );
          fail('Expected error but operation succeeded');
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });
  });
}
