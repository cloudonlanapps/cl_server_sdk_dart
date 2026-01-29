import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('DINO Embedding Integration Tests', () {
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

    test('test_dino_embedding_flow', () async {
      final image = await IntegrationHelper.getTestImage();

      final job = await client.dinoEmbedding.embedImage(
        image,
        wait: true,
        timeout: const Duration(seconds: 30),
      );

      expect(job.status, equals('completed'));
      expect(job.taskOutput, isNotNull);
      // DINOv2 dimension is usually 384 or 768 or 1024 or 1536 depending on model
      expect(job.taskOutput!['embedding_dim'], isNotNull);

      await client.deleteJob(job.jobId);
    });

    test('test_dino_embedding_file_download', () async {
      final image = await IntegrationHelper.getTestImage();

      final job = await client.dinoEmbedding.embedImage(
        image,
        wait: true,
      );

      final tempDir = await Directory.systemTemp.createTemp('dino_test');
      final outputFile = File('${tempDir.path}/dino_embedding.npy');

      try {
        await client.downloadJobFile(
          job.jobId,
          'output/dino_embedding.npy',
          outputFile,
        );

        expect(outputFile.existsSync(), isTrue);
        expect(outputFile.lengthSync(), greaterThan(0));
      } finally {
        await tempDir.delete(recursive: true);
        await client.deleteJob(job.jobId);
      }
    });

    test('test_dino_embedding_worker_capabilities', () async {
      final hasWorkers = await client.waitForWorkers(
        requiredCapabilities: ['dino_embedding'],
        timeout: const Duration(seconds: 5),
      );

      expect(hasWorkers, isTrue);
    });
  });
}
