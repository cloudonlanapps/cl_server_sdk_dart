import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for perceptual image hashing.
class HashClient extends BasePluginClient {
  HashClient(ClientProtocol client) : super(client, 'hash');

  Future<JobResponse> compute(
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
