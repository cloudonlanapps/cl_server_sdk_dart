import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for HLS streaming manifest generation
///
/// Generates HLS (HTTP Live Streaming) manifests for video streaming.
class HlsStreamingClient extends BasePluginClient {
  /// Initialize HLS streaming client
  ///
  /// [computeService] - ComputeService instance
  HlsStreamingClient(ComputeService computeService)
    : super(computeService, 'hls_streaming');

  /// Generate HLS manifest from video
  ///
  /// [video] - Path to video file
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates
  /// (MQTT, NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion
  /// (MQTT, NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with HLS manifest data in `taskOutput`
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.hlsStreaming.generateManifest(
  ///   video: File('video.mp4'),
  ///   wait: true,
  /// );
  /// final manifestPath = job.taskOutput?['manifest'];
  /// print('HLS manifest: $manifestPath');
  /// ```
  Future<Job> generateManifest({
    required File video,
    bool wait = false,
    Duration? timeout,
    void Function(JobStatus)? onProgress,
    void Function(JobStatus)? onComplete,
  }) async {
    return submitWithFiles(
      files: {'file': video},
      wait: wait,
      timeout: timeout,
      onProgress: onProgress,
      onComplete: onComplete,
    );
  }
}
