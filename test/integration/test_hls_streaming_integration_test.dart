import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('HLS Streaming Integration Tests', () {
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

    test('test_hls_manifest_generation', () async {
      final video = await IntegrationHelper.getTestVideo();

      final job = await client.hlsStreaming.generateManifest(
        video,
        wait: true,
        timeout: const Duration(seconds: 120), // Video processing takes longer
      );

      expect(job.status, equals('completed'));

      final tempDir = await Directory.systemTemp.createTemp('hls_test');
      final outputFile = File('${tempDir.path}/master.m3u8');

      try {
        await client.downloadJobFile(
          job.jobId,
          'output/master.m3u8',
          outputFile,
        );

        expect(outputFile.existsSync(), isTrue);
        expect(outputFile.lengthSync(), greaterThan(0));

        final content = outputFile.readAsStringSync();
        expect(content, contains('#EXTM3U'));
      } finally {
        await tempDir.delete(recursive: true);
        await client.deleteJob(job.jobId);
      }
    });
  });
}
