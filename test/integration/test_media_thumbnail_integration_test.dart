import 'dart:async';
import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Media Thumbnail Integration Tests', () {
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

    test('test_media_thumbnail_http_polling', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_image_1920x1080.jpg',
      );

      final job = await client.mediaThumbnail.generate(
        image,
        width: 128,
        height: 128,
        wait: true,
        timeout: const Duration(seconds: 30),
      );

      expect(job.status, equals('completed'));

      final tempDir = await Directory.systemTemp.createTemp('thumb_test_img');
      final outputFile = File('${tempDir.path}/thumbnail.jpg');

      try {
        await client.downloadJobFile(
          job.jobId,
          'output/thumbnail.jpg',
          outputFile,
        );

        expect(outputFile.existsSync(), isTrue);
        expect(outputFile.lengthSync(), greaterThan(0));
      } finally {
        await tempDir.delete(recursive: true);
        await client.deleteJob(job.jobId);
      }
    });

    test('test_media_thumbnail_file_download', () async {
      final originalVideo = await IntegrationHelper.getTestVideo(
        'test_video_1080p_10s.mp4',
      );
      final tempDirUnique = await Directory.systemTemp.createTemp(
        'thumb_vid_unique',
      );
      final uniqueVideo = File('${tempDirUnique.path}/unique.mp4');
      await IntegrationHelper.createUniqueCopy(originalVideo, uniqueVideo);

      final job = await client.mediaThumbnail.generate(
        uniqueVideo,
        width: 128,
        wait: true,
        timeout: const Duration(seconds: 60),
      );

      if (job.status != 'completed') {
        print(
          'Thumbnail Job Failed: ${job.status}, Error: ${job.errorMessage}',
        );
      }
      expect(job.status, equals('completed'));

      final tempDir = await Directory.systemTemp.createTemp('thumb_test_vid');
      final outputFile = File('${tempDir.path}/thumbnail.jpg');

      try {
        await client.downloadJobFile(
          job.jobId,
          'output/thumbnail.jpg',
          outputFile,
        );

        expect(outputFile.existsSync(), isTrue);
        expect(outputFile.lengthSync(), greaterThan(0));
      } finally {
        await tempDir.delete(recursive: true);
        await client.deleteJob(job.jobId);
      }
    });

    test('test_media_thumbnail_mqtt_callbacks', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_image_1920x1080.jpg',
      );

      final completionCompleter = Completer<JobResponse>();
      final job = await client.mediaThumbnail.generate(
        image,
        width: 64,
        onComplete: (j) => completionCompleter.complete(j),
      );

      final finalJob = await completionCompleter.future.timeout(
        const Duration(seconds: 30),
      );

      expect(finalJob.status, equals('completed'));
      await client.deleteJob(job.jobId);
    });

    test('test_media_thumbnail_both_callbacks', () async {
      final image = await IntegrationHelper.getTestImage(
        'test_image_1920x1080.jpg',
      );

      bool progressCalled = false;
      bool completeCalled = false;
      final completionCompleter = Completer<void>();

      await client.mediaThumbnail.generate(
        image,
        width: 128,
        height: 128,
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

    test('test_media_thumbnail_worker_capabilities', () async {
      final hasWorkers = await client.waitForWorkers(
        requiredCapabilities: ['media_thumbnail'],
        timeout: const Duration(seconds: 35), // Heartbeat is 30s
      );

      expect(hasWorkers, isTrue);
    });
  });
}
