import 'dart:async';
import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('CLIP Embedding Integration Tests', () {
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

    test('test_clip_embedding_http_polling', () async {
      final image = await IntegrationHelper.getTestImage();

      // Submit and wait using polling (wait: true)
      final job = await client.clipEmbedding.embedImage(
        image,
        wait: true,
        timeout: const Duration(seconds: 30),
      );

      expect(job.status, equals('completed'));
      expect(job.progress, equals(100));
      expect(job.taskOutput, isNotNull);
      expect(job.taskOutput!['embedding_dim'], equals(512));

      // Cleanup
      await client.deleteJob(job.jobId);
    });

    test('test_clip_embedding_mqtt_callbacks', () async {
      final image = await IntegrationHelper.getTestImage();

      final progressUpdates = <int>[];
      final completionCompleter = Completer<JobResponse>();

      final job = await client.clipEmbedding.embedImage(
        image,
        onProgress: (j) => progressUpdates.add(j.progress),
        onComplete: (j) => completionCompleter.complete(j),
      );

      final finalJob = await completionCompleter.future.timeout(
        const Duration(seconds: 30),
      );

      expect(finalJob.status, equals('completed'));
      expect(progressUpdates, isNotEmpty);

      // To verify output, fetch full job details via HTTP
      final fullJob = await client.getJob(job.jobId);
      expect(fullJob.taskOutput, isNotNull);
      expect(fullJob.taskOutput!['embedding_dim'], equals(512));

      // Cleanup
      await client.deleteJob(job.jobId);
    });

    test('test_clip_embedding_both_callbacks', () async {
      final image = await IntegrationHelper.getTestImage();

      bool progressCalled = false;
      bool completeCalled = false;
      final completionCompleter = Completer<void>();

      await client.clipEmbedding.embedImage(
        image,
        onProgress: (j) => progressCalled = true,
        onComplete: (j) {
          completeCalled = true;
          completionCompleter.complete();
        },
      );

      await completionCompleter.future.timeout(const Duration(seconds: 30));

      expect(progressCalled, isTrue, reason: 'onProgress was not called');
      expect(completeCalled, isTrue, reason: 'onComplete was not called');
    });

    test('test_clip_embedding_file_download', () async {
      final image = await IntegrationHelper.getTestImage();

      final job = await client.clipEmbedding.embedImage(
        image,
        wait: true,
      );

      final tempDir = await Directory.systemTemp.createTemp('clip_test');
      final outputFile = File('${tempDir.path}/clip_embedding.npy');

      try {
        await client.downloadJobFile(
          job.jobId,
          'output/clip_embedding.npy',
          outputFile,
        );

        expect(outputFile.existsSync(), isTrue);
        expect(outputFile.lengthSync(), greaterThan(0));
      } finally {
        await tempDir.delete(recursive: true);
        await client.deleteJob(job.jobId);
      }
    });

    test('test_clip_embedding_worker_capabilities', () async {
      // This tests if it can wait for workers with clip_embedding capability
      // It might timeout if no worker is running
      final hasWorkers = await client.waitForWorkers(
        requiredCapabilities: ['clip_embedding'],
        timeout: const Duration(seconds: 5),
      );

      expect(hasWorkers, isTrue);
    });
  });
}
