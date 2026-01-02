import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for media thumbnail generation
///
/// Generates thumbnails from images and videos with configurable dimensions.
class MediaThumbnailClient extends BasePluginClient {
  /// Initialize media thumbnail client
  ///
  /// [computeService] - ComputeService instance
  MediaThumbnailClient(ComputeService computeService)
    : super(computeService, 'media_thumbnail');

  /// Generate thumbnail from media file
  ///
  /// [media] - Path to media file (image or video)
  /// [width] - Thumbnail width in pixels (optional)
  /// [height] - Thumbnail height in pixels (optional)
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates
  /// (MQTT, NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion
  /// (MQTT, NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with thumbnail path in `taskOutput`
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.mediaThumbnail.generate(
  ///   media: File('video.mp4'),
  ///   width: 256,
  ///   height: 256,
  ///   wait: true,
  /// );
  /// final thumbnailPath = job.taskOutput?['thumbnail_path'];
  /// print('Thumbnail: $thumbnailPath');
  /// ```
  Future<Job> generate({
    required File media,
    int? width,
    int? height,
    bool wait = false,
    Duration? timeout,
    void Function(JobStatus)? onProgress,
    void Function(JobStatus)? onComplete,
  }) async {
    final params = <String, String>{};
    if (width != null) {
      params['width'] = width.toString();
    }
    if (height != null) {
      params['height'] = height.toString();
    }

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
