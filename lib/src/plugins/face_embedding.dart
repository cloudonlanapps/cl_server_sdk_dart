import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for face embeddings.
class FaceEmbeddingClient extends BasePluginClient {
  FaceEmbeddingClient(ClientProtocol client) : super(client, 'face_embedding');

  Future<JobResponse> embedFaces(
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
