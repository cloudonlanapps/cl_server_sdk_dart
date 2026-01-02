import 'dart:io';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../../../test_helpers.dart';
import '../../health_check_test.dart';
import '../../image_resize_test_helpers.dart';

/// Integration tests for all 9 compute plugin clients
///
/// These tests require:
/// - Compute service running at http://localhost:8002
/// - At least one worker with required capabilities
/// - Test media files in test/media/
void main() {
  group('Plugin Integration Tests', () {
    late ComputeService computeService;
    late File testImage;
    late File testVideo;

    setUpAll(() async {
      // Check if compute service is available
      final isHealthy = await checkComputeServiceHealth();
      if (!isHealthy) {
        throw Exception(
          'Compute service not available at $computeServiceBaseUrl. '
          'Please start the compute service before running integration tests.',
        );
      }

      computeService = ComputeService(computeServiceBaseUrl);

      // Create test media files
      final imagePath = await generateTestImage(
        width: 640,
        height: 480,
        fileName: 'test_plugin_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      testImage = File(imagePath);
      testVideo = await generateTestVideo();
    });

    tearDownAll(() async {
      // Cleanup test files
      if (testImage.existsSync()) {
        await testImage.delete();
      }
      if (testVideo.existsSync()) {
        await testVideo.delete();
      }
    });

    group('CLIP Embedding Client', () {
      test('embeds image successfully with polling', () async {
        final job = await computeService.clipEmbedding.embedImage(
          image: testImage,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'clip_embedding');
        expect(job.taskOutput, isNotNull);
        expect(job.taskOutput!['embedding'], isNotNull);
      });

      test('embeds image successfully', () async {
        final job = await computeService.clipEmbedding.embedImage(
          image: testImage,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'clip_embedding');
      });
    });

    group('DINO Embedding Client', () {
      test('embeds image successfully with polling', () async {
        final job = await computeService.dinoEmbedding.embedImage(
          image: testImage,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'dino_embedding');
        expect(job.taskOutput, isNotNull);
      });
    });

    group('EXIF Client', () {
      test('extracts EXIF metadata successfully', () async {
        final job = await computeService.exif.extract(
          image: testImage,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'exif');
        expect(job.taskOutput, isNotNull);
      });
    });

    group('Face Detection Client', () {
      test('detects faces successfully', () async {
        final job = await computeService.faceDetection.detect(
          image: testImage,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'face_detection');
        expect(job.taskOutput, isNotNull);
      });
    });

    group('Face Embedding Client', () {
      test('embeds faces successfully', () async {
        final job = await computeService.faceEmbedding.embedFaces(
          image: testImage,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'face_embedding');
        expect(job.taskOutput, isNotNull);
      });
    });

    group('Hash Client', () {
      test('computes perceptual hashes successfully', () async {
        final job = await computeService.hash.compute(
          image: testImage,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'hash');
        expect(job.taskOutput, isNotNull);
        expect(job.taskOutput!['phash'], isNotNull);
        expect(job.taskOutput!['dhash'], isNotNull);
      });
    });

    group('HLS Streaming Client', () {
      test('generates HLS manifest successfully', () async {
        final job = await computeService.hlsStreaming.generateManifest(
          video: testVideo,
          wait: true,
          timeout: const Duration(seconds: 120),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'hls_streaming');
        expect(job.taskOutput, isNotNull);
      });
    });

    group('Image Conversion Client', () {
      test('converts image format successfully', () async {
        final job = await computeService.imageConversion.convert(
          image: testImage,
          outputFormat: 'jpg',
          quality: 85,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'image_conversion');
        expect(job.taskOutput, isNotNull);
      });

      test('converts to WebP format', () async {
        final job = await computeService.imageConversion.convert(
          image: testImage,
          outputFormat: 'webp',
          quality: 90,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskOutput, isNotNull);
      });
    });

    group('Media Thumbnail Client', () {
      test('generates thumbnail from image', () async {
        final job = await computeService.mediaThumbnail.generate(
          media: testImage,
          width: 256,
          height: 256,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskType, 'media_thumbnail');
        expect(job.taskOutput, isNotNull);
      });

      test('generates thumbnail from video', () async {
        final job = await computeService.mediaThumbnail.generate(
          media: testVideo,
          width: 128,
          height: 128,
          wait: true,
          timeout: const Duration(seconds: 60),
        );

        expect(job.status, 'completed');
        expect(job.taskOutput, isNotNull);
      });
    });

    group('Plugin Client MQTT Integration', () {
      late MqttService mqttService;

      setUp(() async {
        // Check if MQTT broker is available
        final mqttHealthy = await checkMqttBrokerHealth();
        if (!mqttHealthy) {
          throw Exception(
            'MQTT broker not available at localhost:1883. '
            'Skipping MQTT tests.',
          );
        }

        mqttService = MqttService(brokerUrl: 'localhost', brokerPort: 1883);
        await mqttService.connect();
      });

      tearDown(() async {
        await mqttService.disconnect();
      });

      test('CLIP embedding with MQTT callbacks', () async {
        var progressCalled = false;
        var completeCalled = false;
        JobStatus? finalStatus;

        final job = await computeService.clipEmbedding.embedImage(
          image: testImage,
          onProgress: (status) {
            progressCalled = true;
            expect(status.jobId, isNotEmpty);
          },
          onComplete: (status) {
            completeCalled = true;
            finalStatus = status;
            expect(status.isFinished, true);
          },
        );

        // Wait for completion via MQTT
        await mqttService.waitForCompletion(
          jobId: job.jobId,
          timeout: const Duration(seconds: 60),
        );

        // Verify callbacks were invoked
        expect(completeCalled, true);
        expect(finalStatus, isNotNull);
        expect(finalStatus!.status, anyOf('completed', 'failed'));

        // Fetch full job to verify output
        final fullJob = await computeService.getJob(job.jobId);
        expect(fullJob.status, 'completed');
        expect(fullJob.taskOutput, isNotNull);
      });

      test('Multiple plugins with concurrent MQTT monitoring', () async {
        // Submit multiple jobs concurrently
        final jobs = await Future.wait([
          computeService.clipEmbedding.embedImage(image: testImage),
          computeService.dinoEmbedding.embedImage(image: testImage),
          computeService.hash.compute(image: testImage),
        ]);

        // Wait for all to complete via MQTT
        await Future.wait(
          jobs.map(
            (job) => mqttService.waitForCompletion(
              jobId: job.jobId,
              timeout: const Duration(seconds: 120),
            ),
          ),
        );

        // Verify all completed
        for (final job in jobs) {
          final fullJob = await computeService.getJob(job.jobId);
          expect(fullJob.status, 'completed');
          expect(fullJob.taskOutput, isNotNull);
        }
      });
    });
  });
}

/// Helper to generate test video file
Future<File> generateTestVideo() async {
  final tempDir = Directory.systemTemp;
  final videoPath = path.join(
    tempDir.path,
    'test_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
  );
  final videoFile = File(videoPath);

  // Create a minimal valid MP4 file (1x1 pixel, 1 frame)
  // This is a base64-encoded minimal MP4 file
  const minimalMp4Base64 =
      'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAu1tZGF0AAACrgYF//+c3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE1MiByMjg1NCBlOWE1OTAzIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAxNyAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTMgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTI1IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAABDGWIhAAv//73au4APsNVxjBiRbL0Yc9RbmjdJJr1V6ql39PG2XY1gbOBMCIJ9MAsqgAAAAMAAAMAAAMAAAMAAAMABBgSIX9kwAAApQAAAAEBQo=';

  // Decode and write to file
  final bytes = Uri.parse(
    'data:video/mp4;base64,$minimalMp4Base64',
  ).data!.contentAsBytes();
  await videoFile.writeAsBytes(bytes);

  return videoFile;
}
