import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for media thumbnail generation.
class MediaThumbnailClient extends BasePluginClient {
  MediaThumbnailClient(ClientProtocol client)
    : super(client, 'media_thumbnail');

  Future<JobResponse> generate(
    File media, {
    int? width,
    int? height,
    bool wait = false,
    Duration? timeout,
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
  }) {
    final params = <String, Object>{};
    if (width != null) params['width'] = width;
    if (height != null) params['height'] = height;

    return submitWithFiles(
      files: {'file': media},
      params: params,
      wait: wait,
      timeout: timeout,
      onProgress: onProgress,
      onComplete: onComplete,
    );
  }
}
