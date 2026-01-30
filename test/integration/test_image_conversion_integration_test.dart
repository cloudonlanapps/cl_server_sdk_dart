import 'dart:async';
import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Image Conversion Integration Tests', () {
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

    test('test_image_conversion_http_polling', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_image_1920x1080.jpg',
      );

      final job = await client.imageConversion.convert(
        image,
        outputFormat: 'png',
        wait: true,
        timeout: const Duration(seconds: 30),
      );

      expect(job.status, equals('completed'));

      final tempDir = await Directory.systemTemp.createTemp('conv_test');
      final outputFile = File('${tempDir.path}/converted.png');

      final outputPath = job.params['output_path'] as String?;
      expect(
        outputPath,
        isNotNull,
        reason: 'output_path should be in job params',
      );

      try {
        await client.downloadJobFile(
          job.jobId,
          outputPath!,
          outputFile,
        );

        expect(outputFile.existsSync(), isTrue);
        expect(outputFile.lengthSync(), greaterThan(0));

        // Basic PNG header check
        final bytes = outputFile.readAsBytesSync();
        expect(bytes[0], equals(0x89));
        expect(bytes[1], equals(0x50));
        expect(bytes[2], equals(0x4E));
        expect(bytes[3], equals(0x47));
      } finally {
        await tempDir.delete(recursive: true);
        await client.deleteJob(job.jobId);
      }
    });

    test('test_image_conversion_multiple_formats', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_image_1920x1080.jpg',
      );

      final job = await client.imageConversion.convert(
        image,
        outputFormat: 'webp',
        quality: 50,
        wait: true,
      );

      expect(job.status, equals('completed'));
      await client.deleteJob(job.jobId);
    });

    test('test_image_conversion_mqtt_callbacks', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_image_1920x1080.jpg',
      );

      final completionCompleter = Completer<JobResponse>();
      final job = await client.imageConversion.convert(
        image,
        outputFormat: 'png',
        onComplete: (j) => completionCompleter.complete(j),
      );

      final finalJob = await completionCompleter.future.timeout(
        const Duration(seconds: 30),
      );

      expect(finalJob.status, equals('completed'));
      await client.deleteJob(job.jobId);
    });
  });
}
