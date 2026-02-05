import 'dart:io';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockClientProtocol extends Mock implements ClientProtocol {}

void main() {
  setUpAll(() {
    registerFallbackValue(File(''));
    registerFallbackValue(const Duration(seconds: 1));
  });

  group('Plugins', () {
    late MockClientProtocol mockComputeClient;
    late File tempImageFile;

    setUp(() {
      mockComputeClient = MockClientProtocol();
      tempImageFile = File('test_image.jpg');
      if (!tempImageFile.existsSync()) {
        tempImageFile.writeAsBytesSync([1, 2, 3]);
      }
    });

    tearDown(() {
      if (tempImageFile.existsSync()) {
        tempImageFile.deleteSync();
      }
    });

    group('BasePluginClient', () {
      test('test_base_plugin_init', () {
        final plugin = BasePluginClient(mockComputeClient, 'clip_embedding');
        expect(plugin.client, equals(mockComputeClient));
        expect(plugin.taskType, equals('clip_embedding'));
        expect(plugin.endpoint, equals('/jobs/clip_embedding'));
      });

      test('test_base_plugin_submit_job_not_implemented', () async {
        final plugin = BasePluginClient(mockComputeClient, 'clip_embedding');
        expect(plugin.submitJob, throwsA(isA<UnimplementedError>()));
      });

      test('test_base_plugin_submit_with_files', () async {
        final plugin = BasePluginClient(mockComputeClient, 'media_thumbnail');
        const jobId = 'test-job-123';

        when(
          () => mockComputeClient.httpSubmitJob(
            any(),
            files: any(named: 'files'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => jobId);

        final jobResponse = JobResponse(
          jobId: jobId,
          taskType: 'media_thumbnail',
          status: 'queued',
          createdAt: 1234567890,
        );
        when(
          () => mockComputeClient.getJob(jobId),
        ).thenAnswer((_) async => jobResponse);

        final job = await plugin.submitWithFiles(
          files: {'file': tempImageFile},
          params: {'width': 256, 'height': 256},
          priority: 7,
        );

        verify(
          () => mockComputeClient.httpSubmitJob(
            '/jobs/media_thumbnail',
            files: any(named: 'files'),
            data: any(named: 'data'),
          ),
        ).called(1);
        expect(job.jobId, equals(jobId));
        expect(job.status, equals('queued'));
      });

      test('test_base_plugin_submit_with_files_and_wait', () async {
        final plugin = BasePluginClient(mockComputeClient, 'media_thumbnail');
        const jobId = 'test-job-123';

        when(
          () => mockComputeClient.httpSubmitJob(
            any(),
            files: any(named: 'files'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => jobId);

        final queuedJob = JobResponse(
          jobId: jobId,
          taskType: 'media_thumbnail',
          status: 'queued',
          createdAt: 1234567890,
        );
        when(
          () => mockComputeClient.getJob(jobId),
        ).thenAnswer((_) async => queuedJob);

        final completedJob = JobResponse(
          jobId: jobId,
          taskType: 'media_thumbnail',
          status: 'completed',
          progress: 100,
          createdAt: 1234567890,
        );
        when(
          () => mockComputeClient.waitForJob(
            jobId,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => completedJob);

        final job = await plugin.submitWithFiles(
          files: {'file': tempImageFile},
          wait: true,
          timeout: const Duration(seconds: 30),
        );

        verify(
          () => mockComputeClient.waitForJob(
            jobId,
            timeout: const Duration(seconds: 30),
          ),
        ).called(1);
        expect(job.status, equals('completed'));
      });

      test('test_base_plugin_submit_with_callbacks', () async {
        final plugin = BasePluginClient(mockComputeClient, 'media_thumbnail');
        const jobId = 'test-job-123';

        when(
          () => mockComputeClient.httpSubmitJob(
            any(),
            files: any(named: 'files'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => jobId);
        when(() => mockComputeClient.getJob(jobId)).thenAnswer(
          (_) async => JobResponse(
            jobId: jobId,
            taskType: 'media_thumbnail',
            status: 'queued',
            createdAt: 1234567890,
          ),
        );
        when(
          () => mockComputeClient.mqttSubscribeJobUpdates(
            any(),
            onProgress: any(named: 'onProgress'),
            onComplete: any(named: 'onComplete'),
            taskType: any(named: 'taskType'),
          ),
        ).thenReturn('sub-123');

        void onProgress(JobResponse j) {}
        void onComplete(JobResponse j) {}

        await plugin.submitWithFiles(
          files: {'file': tempImageFile},
          onProgress: onProgress,
          onComplete: onComplete,
        );

        verify(
          () => mockComputeClient.mqttSubscribeJobUpdates(
            jobId,
            onProgress: onProgress,
            onComplete: onComplete,
            taskType: 'media_thumbnail',
          ),
        ).called(1);
      });

      test('test_base_plugin_file_not_found', () async {
        final plugin = BasePluginClient(mockComputeClient, 'media_thumbnail');
        final missingFile = File('missing.jpg');
        expect(
          () => plugin.submitWithFiles(files: {'file': missingFile}),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('IndividualPlugins', () {
      test('test_clip_embedding_init', () {
        final plugin = ClipEmbeddingClient(mockComputeClient);
        expect(plugin.taskType, equals('clip_embedding'));
      });

      test('test_clip_embedding_embed_image', () async {
        final plugin = ClipEmbeddingClient(mockComputeClient);
        const jobId = 'test-job-123';
        when(
          () => mockComputeClient.httpSubmitJob(
            any(),
            files: any(named: 'files'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => jobId);
        when(() => mockComputeClient.getJob(jobId)).thenAnswer(
          (_) async => JobResponse(
            jobId: jobId,
            taskType: 'clip_embedding',
            status: 'queued',
            createdAt: 1234567890,
          ),
        );

        final job = await plugin.embedImage(tempImageFile);
        expect(job.jobId, equals(jobId));
        expect(job.taskType, equals('clip_embedding'));
      });

      test('test_dino_embedding_init', () {
        expect(
          DinoEmbeddingClient(mockComputeClient).taskType,
          equals('dino_embedding'),
        );
      });

      test('test_exif_init', () {
        expect(ExifClient(mockComputeClient).taskType, equals('exif'));
      });

      test('test_face_detection_init', () {
        expect(
          FaceDetectionClient(mockComputeClient).taskType,
          equals('face_detection'),
        );
      });

      test('test_face_embedding_init', () {
        expect(
          FaceEmbeddingClient(mockComputeClient).taskType,
          equals('face_embedding'),
        );
      });

      test('test_hash_init', () {
        expect(HashClient(mockComputeClient).taskType, equals('hash'));
      });

      test('test_hls_streaming_init', () {
        expect(
          HlsStreamingClient(mockComputeClient).taskType,
          equals('hls_streaming'),
        );
      });

      test('test_image_conversion_init', () {
        expect(
          ImageConversionClient(mockComputeClient).taskType,
          equals('image_conversion'),
        );
      });

      test('test_image_conversion_convert', () async {
        final plugin = ImageConversionClient(mockComputeClient);
        const jobId = 'test-job-456';
        when(
          () => mockComputeClient.httpSubmitJob(
            any(),
            files: any(named: 'files'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => jobId);
        when(() => mockComputeClient.getJob(jobId)).thenAnswer(
          (_) async => JobResponse(
            jobId: jobId,
            taskType: 'image_conversion',
            status: 'queued',
            createdAt: 1234567890,
          ),
        );

        final job = await plugin.convert(
          tempImageFile,
          outputFormat: 'png',
          quality: 90,
        );
        expect(job.jobId, equals(jobId));
        expect(job.taskType, equals('image_conversion'));
      });

      test('test_media_thumbnail_init', () {
        expect(
          MediaThumbnailClient(mockComputeClient).taskType,
          equals('media_thumbnail'),
        );
      });

      test('test_media_thumbnail_generate', () async {
        final plugin = MediaThumbnailClient(mockComputeClient);
        const jobId = 'test-job-789';
        when(
          () => mockComputeClient.httpSubmitJob(
            any(),
            files: any(named: 'files'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => jobId);
        when(() => mockComputeClient.getJob(jobId)).thenAnswer(
          (_) async => JobResponse(
            jobId: jobId,
            taskType: 'media_thumbnail',
            status: 'queued',
            createdAt: 1234567890,
          ),
        );

        final job = await plugin.generate(
          tempImageFile,
          width: 256,
          height: 256,
        );
        expect(job.jobId, equals(jobId));
        expect(job.taskType, equals('media_thumbnail'));
      });
    });

    group('ComputeClientLazyLoading', () {
      test('test_compute_client_lazy_load_clip_embedding', () {
        final client = ComputeClient(
          baseUrl: 'http://compute.local:8012',
          mqttUrl: 'mqtt://mqtt.local:1883',
          mqttMonitor: MockMQTTJobMonitor(),
        );
        final plugin = client.clipEmbedding;
        expect(plugin, isA<ClipEmbeddingClient>());
        expect(client.clipEmbedding, same(plugin));
      });

      test('test_compute_client_lazy_load_all_plugins', () {
        final client = ComputeClient(
          baseUrl: 'http://compute.local:8012',
          mqttUrl: 'mqtt://mqtt.local:1883',
          mqttMonitor: MockMQTTJobMonitor(),
        );
        expect(client.clipEmbedding, isA<ClipEmbeddingClient>());
        expect(client.dinoEmbedding, isA<DinoEmbeddingClient>());
        expect(client.exif, isA<ExifClient>());
        expect(client.faceDetection, isA<FaceDetectionClient>());
        expect(client.faceEmbedding, isA<FaceEmbeddingClient>());
        expect(client.hash, isA<HashClient>());
        expect(client.hlsStreaming, isA<HlsStreamingClient>());
        expect(client.imageConversion, isA<ImageConversionClient>());
        expect(client.mediaThumbnail, isA<MediaThumbnailClient>());
      });
    });
  });
}

class MockMQTTJobMonitor extends Mock implements MQTTJobMonitor {
  @override
  bool get isConnected => true;
  @override
  Future<bool> connect() async => true;
}
