import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Face Detection Integration Tests', () {
    late SessionManager session;
    late ComputeClient client;

    setUpAll(() async {
      session = await IntegrationHelper.createSession();
      client = session.createComputeClient();
    });

    tearDownAll(() async {
      await client.close();
      await session.close();
    });

    test('test_face_detection_http_polling', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_face_single.jpg',
      );

      final job = await client.faceDetection.detect(
        image,
        wait: true,
        timeout: const Duration(seconds: 30),
      );

      expect(job.status, equals('completed'));
      expect(job.taskOutput, isNotNull);

      final faces = job.taskOutput!['faces'] as List;
      expect(faces.length, equals(2));

      final face = faces[0] as Map;
      expect(face, contains('bbox'));
      expect(face, contains('confidence'));

      await client.deleteJob(job.jobId);
    });

    test('test_face_detection_mqtt_callbacks', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_face_multiple.jpg',
      );

      final job = await client.faceDetection.detect(
        image,
        wait: true,
      );

      expect(job.status, equals('completed'));
      expect(job.taskOutput, isNotNull);

      final faces = job.taskOutput!['faces'] as List;
      expect(faces.length, greaterThan(1));

      await client.deleteJob(job.jobId);
    });

    test('test_face_detection_no_faces', () async {
      // Use a landscape image or similar
      final image = await IntegrationHelper.getTestImage(
        
      );

      final job = await client.faceDetection.detect(
        image,
        wait: true,
      );

      expect(job.status, equals('completed'));
      expect(job.taskOutput, isNotNull);

      final faces = job.taskOutput!['faces'] as List;
      expect(faces.length, equals(0));

      await client.deleteJob(job.jobId);
    });
  });
}
