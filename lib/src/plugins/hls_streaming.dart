import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for HLS streaming manifest generation.
class HlsStreamingClient extends BasePluginClient {
  HlsStreamingClient(ClientProtocol client) : super(client, 'hls_streaming');

  Future<JobResponse> generateManifest(
    File video, {
    bool wait = false,
    Duration? timeout,
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
  }) {
    return submitWithFiles(
      files: {'file': video},
      wait: wait,
      timeout: timeout,
      onProgress: onProgress,
      onComplete: onComplete,
    );
  }
}
