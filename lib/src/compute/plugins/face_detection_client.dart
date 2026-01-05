import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for face detection
///
/// Detects faces in images and returns bounding boxes, confidence scores,
/// facial landmarks (5 keypoints), and cropped face images.
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
  /// Returns [Job] with `taskOutput['faces']` containing:
  /// - `bbox`: Normalized bounding box (x1, y1, x2, y2 in [0.0, 1.0])
  /// - `confidence`: Detection confidence [0.0, 1.0]
  /// - `landmarks`: Five keypoints (right_eye, left_eye, nose_tip, mouth_right, mouth_left)
  /// - `file_path`: Path to cropped face image
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.faceDetection.detect(
  ///   image: File('photo.jpg'), wait: true,
  /// );
  /// final faces = job.taskOutput?['faces'] as List;
  ///
  /// // Access landmarks
  /// final landmarks = faces[0]['landmarks'];
  /// print('Right eye: ${landmarks['right_eye']}');
  ///
  /// // Download cropped face
  /// final bytes = await computeService.downloadJobFile(job.jobId, faces[0]['file_path']);
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
