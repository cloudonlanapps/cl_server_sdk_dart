import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for perceptual hashing
///
/// Computes perceptual hashes (phash and dhash) for image similarity detection.
/// Useful for finding duplicate or similar images.
class HashClient extends BasePluginClient {
  /// Initialize hash client
  ///
  /// [computeService] - ComputeService instance
  HashClient(ComputeService computeService) : super(computeService, 'hash');

  /// Compute perceptual hashes for image
  ///
  /// [image] - Path to image file
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates
  /// (MQTT, NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion
  /// (MQTT, NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with phash and dhash values in `taskOutput`
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.hash.compute(
  ///   image: File('photo.jpg'),
  ///   wait: true,
  /// );
  /// final phash = job.taskOutput?['phash'];
  /// final dhash = job.taskOutput?['dhash'];
  /// print('pHash: $phash, dHash: $dhash');
  /// ```
  Future<Job> compute({
    required File image,
    bool wait = false,
    Duration? timeout,
    void Function(JobStatus)? onProgress,
    void Function(JobStatus)? onComplete,
  }) async {
    return submitWithFiles(
      files: {'file': image},
      wait: wait,
      timeout: timeout,
      onProgress: onProgress,
      onComplete: onComplete,
    );
  }
}
