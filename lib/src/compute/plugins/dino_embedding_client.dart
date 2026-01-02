import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for DINO image embeddings
///
/// Generates 384-dimensional DINO embeddings from images using
/// Facebook's DINO model.
/// DINO embeddings capture semantic image features useful for similarity
/// search.
class DinoEmbeddingClient extends BasePluginClient {
  /// Initialize DINO embedding client
  ///
  /// [computeService] - ComputeService instance
  DinoEmbeddingClient(ComputeService computeService)
    : super(computeService, 'dino_embedding');

  /// Generate DINO embedding from image
  ///
  /// [image] - Path to image file
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates (MQTT)
  /// (NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion (MQTT)
  /// (NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with embedding in `taskOutput['embedding']`
  /// (384-dimensional list)
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.dinoEmbedding.embedImage(
  ///   image: File('photo.jpg'),
  ///   wait: true,
  /// );
  /// final embedding = job.taskOutput?['embedding'] as List;
  /// print('Generated ${embedding.length}-dim DINO embedding');
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
