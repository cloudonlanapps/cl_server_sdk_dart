import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for HLS streaming manifest generation.
class HlsStreamingClient extends BasePluginClient {
  HlsStreamingClient(ClientProtocol client) : super(client, 'hls_streaming');

  Future<JobResponse> generateManifest({
    File? video,
    String? inputAbsolutePath,
    String? outputAbsolutePath,
    int? priority,
    bool wait = false,
    Duration? timeout,
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
  }) {
    final params = <String, Object>{};
    if (inputAbsolutePath != null) {
      params['input_absolute_path'] = inputAbsolutePath;
    }
    if (outputAbsolutePath != null) {
      params['output_absolute_path'] = outputAbsolutePath;
    }

    if (video != null) {
      return submitWithFiles(
        files: {'file': video},
        params: params,
        priority: priority ?? 5,
        wait: wait,
        timeout: timeout,
        onProgress: onProgress,
        onComplete: onComplete,
      );
    } else {
      return submitJob(
        params: params,
        priority: priority ?? 5,
        wait: wait,
        timeout: timeout,
        onProgress: onProgress,
        onComplete: onComplete,
      );
    }
  }
}
