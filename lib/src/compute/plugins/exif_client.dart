import 'dart:io';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';
import 'base_plugin_client.dart';

/// Client for EXIF metadata extraction
///
/// Extracts EXIF metadata from images including camera info, GPS data,
/// timestamps, etc.
class ExifClient extends BasePluginClient {
  /// Initialize EXIF client
  ///
  /// [computeService] - ComputeService instance
  ExifClient(ComputeService computeService) : super(computeService, 'exif');

  /// Extract EXIF metadata from image
  ///
  /// [image] - Path to image file
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional, default: 5 minutes)
  /// [onProgress] - Callback for job progress updates
  /// (MQTT, NOT YET IMPLEMENTED)
  /// [onComplete] - Callback for job completion
  /// (MQTT, NOT YET IMPLEMENTED)
  ///
  /// Returns [Job] with EXIF data in `taskOutput` as a Map
  ///
  /// Example:
  /// ```dart
  /// final job = await computeService.exif.extract(
  ///   image: File('photo.jpg'),
  ///   wait: true,
  /// );
  /// final exifData = job.taskOutput;
  /// print('Camera: ${exifData?['Make']} ${exifData?['Model']}');
  /// print('Date: ${exifData?['DateTime']}');
  /// ```
  Future<Job> extract({
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
