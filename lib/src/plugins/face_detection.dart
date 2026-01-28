import 'dart:io';
import '../models/models.dart';
import 'base.dart';

/// Client for face detection.
class FaceDetectionClient extends BasePluginClient {
  FaceDetectionClient(ClientProtocol client) : super(client, 'face_detection');

  Future<JobResponse> detect(
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
