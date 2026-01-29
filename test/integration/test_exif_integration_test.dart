import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('EXIF Integration Tests', () {
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

    test('test_exif_extraction_rich', () async {
      final image = await IntegrationHelper.getTestImage('test_exif_rich.jpg');

      final job = await client.exif.extract(
        image,
        wait: true,
        timeout: const Duration(seconds: 20),
      );

      expect(job.status, equals('completed'));
      expect(job.taskOutput, isNotNull);

      // Verify some standard EXIF fields
      final output = job.taskOutput!;
      expect(
        output,
        anyOf(
          contains('make'), // Lowercase keys in normalized data
          contains('model'),
          (Map<String, dynamic> m) =>
              m['raw_metadata'] != null &&
              (m['raw_metadata'] as Map).isNotEmpty,
        ),
      );

      await client.deleteJob(job.jobId);
    });

    test('test_exif_no_metadata', () async {
      // Create a dummy file without EXIF
      final tempFile = File('no_exif.jpg')
        ..writeAsBytesSync(List.filled(100, 0));

      try {
        final job = await client.exif.extract(
          tempFile,
          wait: true,
        );

        expect(job.status, equals('completed'));
        // Even if no metadata, it should complete successfully, maybe with empty output
        expect(job.taskOutput, isNotNull);

        await client.deleteJob(job.jobId);
      } finally {
        if (tempFile.existsSync()) tempFile.deleteSync();
      }
    });
  });
}
