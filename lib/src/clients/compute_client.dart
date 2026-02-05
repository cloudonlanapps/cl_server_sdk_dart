import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth.dart';
import '../config.dart';
import '../exceptions.dart';
import '../http_utils.dart';
import '../models/models.dart';
import '../mqtt_monitor.dart';
import '../plugins/base.dart';
// Plugins
import '../plugins/clip_embedding.dart';
import '../plugins/dino_embedding.dart';
import '../plugins/exif.dart';
import '../plugins/face_detection.dart';
import '../plugins/face_embedding.dart';
import '../plugins/hash.dart';
import '../plugins/hls_streaming.dart';
import '../plugins/image_conversion.dart';
import '../plugins/media_thumbnail.dart';

class ComputeClient implements ClientProtocol {
  ComputeClient({
    required this.baseUrl,
    required String mqttUrl,
    AuthProvider? authProvider,
    http.Client? client,
    MQTTJobMonitor? mqttMonitor,
    Duration? timeout,
  }) : auth = authProvider ?? NoAuthProvider(),
       timeout = timeout ?? ComputeClientConfig.defaultTimeout {
    _session = client ?? http.Client();
    _mqtt = mqttMonitor ?? getMqttMonitor(url: mqttUrl);
    // Auto-connect if not connected.
    // Note: Python client connects in init strictly.
    if (!_mqtt.isConnected) {
      unawaited(_mqtt.connect()); // Async, fire and forget for constructor
    }
  }
  final String baseUrl;
  final Duration timeout;
  final AuthProvider auth;
  late final http.Client _session;
  late final MQTTJobMonitor _mqtt;

  Future<void> close() async {
    _session.close();
    releaseMqttMonitor(_mqtt);
  }

  // Auth Helpers

  Future<Map<String, String>> _getHeaders() async {
    await auth.refreshTokenIfNeeded();
    return auth.getHeaders();
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        try {
          return json.decode(response.body);
        } on Object catch (_) {
          return null;
        }
      }
      return null;
    } else if (response.statusCode == 401) {
      throw AuthenticationError();
    } else {
      throw ComputeClientError('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // Admin

  Future<bool> updateGuestMode({required bool guestMode}) async {
    final response = await _session
        .put(
          Uri.parse('$baseUrl/admin/pref/guest-mode'),
          body: {'guest_mode': guestMode.toString().toLowerCase()},
          headers: {
            ...(await _getHeaders()),
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        )
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }
    await _handleResponse(response);
    return false;
  }

  // ClientProtocol Implementation

  @override
  Future<String> httpSubmitJob(
    String endpoint, {
    required Map<String, File> files,
    Map<String, dynamic>? data,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _getHeaders());

    if (data != null) {
      data.forEach((k, v) {
        request.fields[k] = v.toString();
      });
    }

    for (final entry in files.entries) {
      request.files.add(
        await HttpUtils.createMultipartFile(entry.key, entry.value),
      );
    }

    final streamResponse = await _session.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamResponse);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return jsonMap['job_id'] as String;
  }

  @override
  Future<JobResponse> getJob(String jobId) async {
    final endpoint = ComputeClientConfig.endpointGetJob(jobId);
    final response = await _session
        .get(Uri.parse('$baseUrl$endpoint'), headers: await _getHeaders())
        .timeout(timeout);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return JobResponse.fromMap(jsonMap);
  }

  Future<void> deleteJob(String jobId) async {
    final endpoint = ComputeClientConfig.endpointDeleteJob(jobId);
    final response = await _session
        .delete(Uri.parse('$baseUrl$endpoint'), headers: await _getHeaders())
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) return;
    await _handleResponse(response);
  }

  @override
  Future<JobResponse> waitForJob(
    String jobId, {
    Duration? pollInterval,
    Duration? timeout,
  }) async {
    final start = DateTime.now();
    final interval = pollInterval ?? ComputeClientConfig.defaultPollInterval;
    var currentInterval = interval;

    while (true) {
      final job = await getJob(jobId);

      if (job.status == 'completed' ||
          job.status == 'failed' ||
          job.status == 'error') {
        return job;
      }

      if (timeout != null && DateTime.now().difference(start) > timeout) {
        throw TimeoutException(
          'Job $jobId timeout after ${timeout.inSeconds}s (status: ${job.status})',
        );
      }

      await Future<void>.delayed(currentInterval);

      final nextMs =
          (currentInterval.inMilliseconds *
                  ComputeClientConfig.pollBackoffMultiplier)
              .round();
      final maxMs = ComputeClientConfig.maxPollBackoff.inMilliseconds;
      currentInterval = Duration(milliseconds: nextMs > maxMs ? maxMs : nextMs);
    }
  }

  @override
  String mqttSubscribeJobUpdates(
    String jobId, {
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
    String taskType = 'unknown',
  }) {
    return _mqtt.subscribeJobUpdates(
      jobId,
      onProgress: onProgress,
      onComplete: onComplete,
      taskType: taskType,
    );
  }

  void unsubscribe(String subscriptionId) {
    _mqtt.unsubscribe(subscriptionId);
  }

  // File Download

  Future<void> downloadJobFile(String jobId, String filePath, File dest) async {
    final endpoint = ComputeClientConfig.endpointGetJobFile(jobId, filePath);
    final response = await _session
        .get(Uri.parse('$baseUrl$endpoint'), headers: await _getHeaders())
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await dest.writeAsBytes(response.bodyBytes);
    } else {
      await _handleResponse(response);
    }
  }

  // Worker Capabilities

  Future<WorkerCapabilitiesResponse> getCapabilities() async {
    final response = await _session
        .get(
          Uri.parse('$baseUrl${ComputeClientConfig.endpointCapabilities}'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return WorkerCapabilitiesResponse.fromMap(jsonMap);
  }

  Future<bool> waitForWorkers({
    List<String>? requiredCapabilities,
    Duration? timeout,
  }) async {
    if (requiredCapabilities == null || requiredCapabilities.isEmpty) {
      return true;
    }

    final t = timeout ?? ComputeClientConfig.workerWaitTimeout;

    for (final cap in requiredCapabilities) {
      await _mqtt.waitForCapability(cap, timeout: t);
    }
    return true;
  }

  // Plugins

  late final _clipEmbedding = ClipEmbeddingClient(this);
  ClipEmbeddingClient get clipEmbedding => _clipEmbedding;

  late final _dinoEmbedding = DinoEmbeddingClient(this);
  DinoEmbeddingClient get dinoEmbedding => _dinoEmbedding;

  late final _exif = ExifClient(this);
  ExifClient get exif => _exif;

  late final _faceDetection = FaceDetectionClient(this);
  FaceDetectionClient get faceDetection => _faceDetection;

  late final _faceEmbedding = FaceEmbeddingClient(this);
  FaceEmbeddingClient get faceEmbedding => _faceEmbedding;

  late final _hash = HashClient(this);
  HashClient get hash => _hash;

  late final _hlsStreaming = HlsStreamingClient(this);
  HlsStreamingClient get hlsStreaming => _hlsStreaming;

  late final _imageConversion = ImageConversionClient(this);
  ImageConversionClient get imageConversion => _imageConversion;

  late final _mediaThumbnail = MediaThumbnailClient(this);
  MediaThumbnailClient get mediaThumbnail => _mediaThumbnail;
}
