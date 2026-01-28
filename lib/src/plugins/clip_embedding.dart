import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for CLIP image embeddings.
class ClipEmbeddingClient extends BasePluginClient {
  ClipEmbeddingClient(ClientProtocol client) : super(client, 'clip_embedding');

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
