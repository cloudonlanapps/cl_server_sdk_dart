import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for face embeddings
///
/// Generates 128-dimensional face embeddings for face recognition and
/// comparison.
class FaceEmbeddingClient extends BasePluginClient {
  /// Initialize face embedding client
  ///
  /// [computeService] - ComputeService instance
  FaceEmbeddingClient(ComputeService computeService)
    : super(computeService, 'face_embedding');

  /// Generate face embeddings from image
  ///
  /// [image] - Path to image file containing faces
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates
  /// (MQTT, NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion
  /// (MQTT, NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with face embeddings in `taskOutput`
  /// (128-dimensional vectors)
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.faceEmbedding.embedFaces(
  ///   image: File('face.jpg'),
  ///   wait: true,
  /// );
  /// final embeddings = job.taskOutput?['embeddings'] as List;
  /// print('Generated ${embeddings.length} face embeddings');
  /// ```
  Future<Job> embedFaces({
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
