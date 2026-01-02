import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for image format conversion
///
/// Converts images between different formats (JPG, PNG, WebP, etc.) with
/// quality control.
class ImageConversionClient extends BasePluginClient {
  /// Initialize image conversion client
  ///
  /// [computeService] - ComputeService instance
  ImageConversionClient(ComputeService computeService)
    : super(computeService, 'image_conversion');

  /// Convert image to different format
  ///
  /// [image] - Path to source image file
  /// [outputFormat] - Target format (e.g., 'jpg', 'png', 'webp')
  /// [quality] - Output quality (1-100, optional, only for lossy formats)
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates
  /// (MQTT, NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion
  /// (MQTT, NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with converted image path in `taskOutput`
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.imageConversion.convert(
  ///   image: File('photo.png'),
  ///   outputFormat: 'jpg',
  ///   quality: 85,
  ///   wait: true,
  /// );
  /// final convertedPath = job.taskOutput?['output_path'];
  /// print('Converted to: $convertedPath');
  /// ```
  Future<Job> convert({
    required File image,
    String? outputFormat,
    int? quality,
    bool wait = false,
    Duration? timeout,
    void Function(JobStatus)? onProgress,
    void Function(JobStatus)? onComplete,
  }) async {
    final params = <String, String>{};
    if (outputFormat != null) {
      params['output_format'] = outputFormat;
    }
    if (quality != null) {
      params['quality'] = quality.toString();
    }

    return submitWithFiles(
      files: {'file': image},
      params: params,
      wait: wait,
      timeout: timeout,
      onProgress: onProgress,
      onComplete: onComplete,
    );
  }
}
