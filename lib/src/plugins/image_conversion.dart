import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for image format conversion.
class ImageConversionClient extends BasePluginClient {
  ImageConversionClient(ClientProtocol client)
    : super(client, 'image_conversion');

  Future<JobResponse> convert(
    File image, {
    required String outputFormat,
    int? quality,
    bool wait = false,
    Duration? timeout,
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
  }) {
    final params = <String, Object>{'format': outputFormat};
    if (quality != null) {
      params['quality'] = quality;
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
