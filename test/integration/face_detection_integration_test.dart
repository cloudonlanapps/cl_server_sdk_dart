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

        // Validate new schema
        final taskOutput = job.taskOutput as Map<String, dynamic>;
        expect(taskOutput.containsKey('faces'), isTrue);

        final faces = taskOutput['faces'] as List;
        expect(faces.length, greaterThan(0));

        final firstFace = faces[0] as Map<String, dynamic>;

        // Validate bbox with normalized coordinates
        expect(firstFace.containsKey('bbox'), isTrue);
        final bbox = firstFace['bbox'] as Map<String, dynamic>;
        expect(bbox['x1'], inInclusiveRange(0.0, 1.0));
        expect(bbox['y1'], inInclusiveRange(0.0, 1.0));
        expect(bbox['x2'], inInclusiveRange(0.0, 1.0));
        expect(bbox['y2'], inInclusiveRange(0.0, 1.0));

        // Validate confidence
        expect(firstFace['confidence'], inInclusiveRange(0.0, 1.0));

        // Validate landmarks
        expect(firstFace.containsKey('landmarks'), isTrue);
        final landmarks = firstFace['landmarks'] as Map<String, dynamic>;

        final requiredLandmarks = ['right_eye', 'left_eye', 'nose_tip', 'mouth_right', 'mouth_left'];
        for (final landmarkName in requiredLandmarks) {
          expect(landmarks.containsKey(landmarkName), isTrue);
          final landmark = landmarks[landmarkName] as List;
          expect(landmark.length, equals(2));
          expect(landmark[0] as double, inInclusiveRange(0.0, 1.0));
          expect(landmark[1] as double, inInclusiveRange(0.0, 1.0));
        }

        // Validate file_path
        expect(firstFace.containsKey('file_path'), isTrue);
        final filePath = firstFace['file_path'] as String;
        expect(filePath.isNotEmpty, isTrue);

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

        // Validate new schema
        final taskOutput = completedJob.taskOutput as Map<String, dynamic>;
        expect(taskOutput.containsKey('faces'), isTrue);

        final faces = taskOutput['faces'] as List;
        expect(faces.length, greaterThan(0));

        final firstFace = faces[0] as Map<String, dynamic>;

        // Validate bbox with normalized coordinates
        expect(firstFace.containsKey('bbox'), isTrue);
        final bbox = firstFace['bbox'] as Map<String, dynamic>;
        expect(bbox['x1'], inInclusiveRange(0.0, 1.0));
        expect(bbox['y1'], inInclusiveRange(0.0, 1.0));
        expect(bbox['x2'], inInclusiveRange(0.0, 1.0));
        expect(bbox['y2'], inInclusiveRange(0.0, 1.0));

        // Validate confidence
        expect(firstFace['confidence'], inInclusiveRange(0.0, 1.0));

        // Validate landmarks
        expect(firstFace.containsKey('landmarks'), isTrue);
        final landmarks = firstFace['landmarks'] as Map<String, dynamic>;

        final requiredLandmarks = ['right_eye', 'left_eye', 'nose_tip', 'mouth_right', 'mouth_left'];
        for (final landmarkName in requiredLandmarks) {
          expect(landmarks.containsKey(landmarkName), isTrue);
          final landmark = landmarks[landmarkName] as List;
          expect(landmark.length, equals(2));
          expect(landmark[0] as double, inInclusiveRange(0.0, 1.0));
          expect(landmark[1] as double, inInclusiveRange(0.0, 1.0));
        }

        // Validate file_path
        expect(firstFace.containsKey('file_path'), isTrue);
        final filePath = firstFace['file_path'] as String;
        expect(filePath.isNotEmpty, isTrue);

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
