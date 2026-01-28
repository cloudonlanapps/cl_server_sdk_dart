import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for EXIF metadata extraction.
class ExifClient extends BasePluginClient {
  ExifClient(ClientProtocol client) : super(client, 'exif');

  Future<JobResponse> extract(
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
