import 'dart:async';
import 'dart:io';

import 'package:cl_server_dart_client/src/core/http_client.dart'
    show HttpClientWrapper;
import 'package:cl_server_dart_client/src/core/models/compute_models.dart'
    show CleanupResult, CreateJobResponse, Job, StorageInfo, WorkerCapabilities;
import 'package:http/http.dart' as http;

import '../compute/plugins/clip_embedding_client.dart';
import '../compute/plugins/dino_embedding_client.dart';
import '../compute/plugins/exif_client.dart';
import '../compute/plugins/face_detection_client.dart';
import '../compute/plugins/face_embedding_client.dart';
import '../compute/plugins/hash_client.dart';
import '../compute/plugins/hls_streaming_client.dart';
import '../compute/plugins/image_conversion_client.dart';
import '../compute/plugins/media_thumbnail_client.dart';

class ComputeService {
  ComputeService(
    this.baseUrl, {
    this.token,
    http.Client? httpClient,
  }) {
    _httpClient = HttpClientWrapper(
      baseUrl: baseUrl,
      token: token,
      httpClient: httpClient,
    );
  }
  final String baseUrl;
  final String? token;
  late final HttpClientWrapper _httpClient;

  /// ----------------------------
  /// Worker Capability Management
  /// ----------------------------

  Future<WorkerCapabilities> getCapabilities() async {
    final json = await _httpClient.get('/compute/capabilities');
    // Handle both flat format (tests) and nested format (real server)
    final capabilitiesMap = json.containsKey('capabilities')
        ? json['capabilities'] as Map<String, dynamic>
        : json;
    return capabilitiesMap.map<String, int>((key, value) {
      final intValue = value is int ? value : (value as num).toInt();
      return MapEntry(key, intValue);
    });
  }

  /// ----------------------------
  /// Job Creation (Generic)
  /// ----------------------------

  Future<CreateJobResponse> createJob({
    required String taskType,
    required Map<String, dynamic> body,
    File? file,
    int? priority,
  }) async {
    final caps = await getCapabilities();
    if (!caps.containsKey(taskType)) {
      throw Exception(
        "Task type '$taskType' not supported. "
        "Available: ${caps.keys.join(', ')}",
      );
    }

    final fields = {...body};
    if (priority != null) {
      fields['priority'] = priority;
    }

    final json = await _httpClient.post(
      '/compute/jobs/$taskType',
      body: fields,
      files: file != null ? {'file': file} : null,
    );

    return CreateJobResponse.fromJson(json);
  }

  /// ----------------------------
  /// Job Status Management
  /// ----------------------------

  Future<Job> getJob(String jobId) async {
    final json = await _httpClient.get('/compute/jobs/$jobId');
    return Job.fromMap(json);
  }

  Future<void> deleteJob(String jobId) async {
    await _httpClient.delete('/compute/jobs/$jobId');
  }

  /// ----------------------------
  /// Admin — Compute Job Storage
  /// ----------------------------

  Future<StorageInfo> getStorageSize() async {
    final json = await _httpClient.get('/admin/compute/jobs/storage/size');
    return StorageInfo.fromJson(json);
  }

  Future<CleanupResult> cleanupOldJobs({int days = 7}) async {
    final json = await _httpClient.delete(
      '/admin/compute/jobs/cleanup',
      queryParameters: {'days': days.toString()},
    );
    return CleanupResult.fromJson(json);
  }

  /// ----------------------------
  /// Wait for completion — Polling
  /// ----------------------------

  Future<Job> waitForJobCompletionWithPolling(
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
    void Function(Job)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (true) {
      final job = await getJob(jobId);

      onProgress?.call(job);

      if (job.isFinished) {
        return job;
      }

      if (stopwatch.elapsed > timeout) {
        throw TimeoutException(
          'Timeout waiting for job: $jobId',
          timeout,
        );
      }

      await Future<void>.delayed(interval);
    }
  }

  /// ----------------------------
  /// Wait for completion — MQTT (DEPRECATED)
  /// ----------------------------

  @Deprecated(
    'MqttService provides JobStatus stream and does not depend on '
    'ComputeService. '
    'See MqttService documentation for usage examples.',
  )
  Future<Job> waitForJobCompletionWithMQTT({
    required String jobId,
    required Stream<Job> jobUpdateStream,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final completer = Completer<Job>();
    late StreamSubscription<Job> sub;

    sub = jobUpdateStream.listen(
      (update) {
        if (update.jobId == jobId && update.isFinished) {
          completer.complete(update);
        }
      },
      onError: completer.completeError,
    );

    return completer.future.timeout(timeout).whenComplete(() => sub.cancel());
  }

  Future<bool> hasTaskType(String taskType) async {
    final caps = await getCapabilities();
    return caps.containsKey(taskType);
  }

  /// ----------------------------
  /// Plugin Clients
  /// ----------------------------

  ClipEmbeddingClient? _clipEmbedding;

  /// CLIP embedding plugin client
  ///
  /// Generates 512-dimensional CLIP embeddings from images.
  ClipEmbeddingClient get clipEmbedding =>
      _clipEmbedding ??= ClipEmbeddingClient(this);

  DinoEmbeddingClient? _dinoEmbedding;

  /// DINO embedding plugin client
  ///
  /// Generates 384-dimensional DINO embeddings from images.
  DinoEmbeddingClient get dinoEmbedding =>
      _dinoEmbedding ??= DinoEmbeddingClient(this);

  ExifClient? _exif;

  /// EXIF metadata extraction plugin client
  ///
  /// Extracts EXIF metadata from images.
  ExifClient get exif => _exif ??= ExifClient(this);

  FaceDetectionClient? _faceDetection;

  /// Face detection plugin client
  ///
  /// Detects faces in images with bounding boxes.
  FaceDetectionClient get faceDetection =>
      _faceDetection ??= FaceDetectionClient(this);

  FaceEmbeddingClient? _faceEmbedding;

  /// Face embedding plugin client
  ///
  /// Generates 128-dimensional face embeddings.
  FaceEmbeddingClient get faceEmbedding =>
      _faceEmbedding ??= FaceEmbeddingClient(this);

  HashClient? _hash;

  /// Perceptual hash plugin client
  ///
  /// Computes perceptual hashes (phash, dhash) for images.
  HashClient get hash => _hash ??= HashClient(this);

  HlsStreamingClient? _hlsStreaming;

  /// HLS streaming plugin client
  ///
  /// Generates HLS manifests for video streaming.
  HlsStreamingClient get hlsStreaming =>
      _hlsStreaming ??= HlsStreamingClient(this);

  ImageConversionClient? _imageConversion;

  /// Image conversion plugin client
  ///
  /// Converts images between formats with quality control.
  ImageConversionClient get imageConversion =>
      _imageConversion ??= ImageConversionClient(this);

  MediaThumbnailClient? _mediaThumbnail;

  /// Media thumbnail plugin client
  ///
  /// Generates thumbnails from images and videos.
  MediaThumbnailClient get mediaThumbnail =>
      _mediaThumbnail ??= MediaThumbnailClient(this);
}
