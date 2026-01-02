import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for CLIP image embeddings
///
/// Generates 512-dimensional CLIP embeddings from images using
/// OpenAI's CLIP model.
/// CLIP embeddings are useful for image search, similarity comparison,
/// and semantic understanding.
class ClipEmbeddingClient extends BasePluginClient {
  /// Initialize CLIP embedding client
  ///
  /// [computeService] - ComputeService instance
  ClipEmbeddingClient(ComputeService computeService)
    : super(computeService, 'clip_embedding');

  /// Generate CLIP embedding from image
  ///
  /// [image] - Path to image file
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates
  /// (MQTT, primary workflow, NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion
  /// (MQTT, primary workflow, NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with embedding in `taskOutput['embedding']`
  /// (512-dimensional list)
  ///
  /// Example (HTTP polling - secondary):
  /// ```dart
  /// final job = await computeService.clipEmbedding.embedImage(
  ///   image: File('photo.jpg'),
  ///   wait: true,
  /// );
  /// final embedding = job.taskOutput?['embedding'] as List;
  /// print('Generated ${embedding.length}-dim embedding');
  /// ```
  ///
  /// Example (MQTT callbacks - primary, NOT YET IMPLEMENTED):
  /// ```dart
  /// final job = await computeService.clipEmbedding.embedImage(
  ///   image: File('photo.jpg'),
  ///   onComplete: (status) => print('Embedding complete: ${status.status}'),
  /// );
  /// // Note: Callbacks will be wired up in Part 2: MQTT Implementation
  /// ```
  Future<Job> embedImage({
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
