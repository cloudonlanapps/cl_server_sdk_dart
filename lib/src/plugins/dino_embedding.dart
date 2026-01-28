import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for DINO image embeddings.
class DinoEmbeddingClient extends BasePluginClient {
  DinoEmbeddingClient(ClientProtocol client) : super(client, 'dino_embedding');

  Future<JobResponse> embedImage(
    File image, {
    bool wait = false,
    Duration? timeout,
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
  }) {
    return submitWithFiles(
      files: {'file': image},
      wait: wait,
      timeout: timeout,
      onProgress: onProgress,
      onComplete: onComplete,
    );
  }
}
