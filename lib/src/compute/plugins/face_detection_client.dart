import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for face detection
///
/// Detects faces in images and returns bounding boxes with confidence scores.
class FaceDetectionClient extends BasePluginClient {
  /// Initialize face detection client
  ///
  /// [computeService] - ComputeService instance
  FaceDetectionClient(ComputeService computeService)
    : super(computeService, 'face_detection');

  /// Detect faces in image
  ///
  /// [image] - Path to image file
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates
  /// (MQTT, NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion
  /// (MQTT, NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with face bounding boxes in `taskOutput`
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.faceDetection.detect(
  ///   image: File('group_photo.jpg'),
  ///   wait: true,
  /// );
  /// final faces = job.taskOutput?['faces'] as List;
  /// print('Detected ${faces.length} faces');
  /// ```
  Future<Job> detect({
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
