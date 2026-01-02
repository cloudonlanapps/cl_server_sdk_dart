import 'dart:io';

import 'package:mime/mime.dart';

import '../../core/models/compute_models.dart';
import '../../services/compute_service.dart';

/// Base plugin client for job submission
///
/// Provides common functionality for all plugin clients:
/// - Job submission with file uploads
/// - MQTT callback-based monitoring (primary workflow)
/// - Optional HTTP polling (secondary workflow)
/// - File handling and MIME type detection
///
/// Each plugin client extends this to provide typed, plugin-specific methods.
abstract class BasePluginClient {
  /// Initialize plugin client
  ///
  /// [computeService] - ComputeService instance
  /// [taskType] - Plugin task type (used for endpoint and capability check)
  BasePluginClient(this.computeService, this.taskType);

  final ComputeService computeService;
  final String taskType;

  /// Submit job with file uploads (PRIMARY METHOD)
  ///
  /// Uploads files via multipart/form-data and optionally monitors completion.
  /// Uses MQTT callbacks (primary) or HTTP polling (secondary) based on
  /// parameters.
  ///
  /// [files] - Map of field names to File objects
  /// (e.g., {"file": File("img.jpg")})
  /// [params] - Additional task parameters (plugin-specific, stringified)
  /// [priority] - Job priority (0-10, default: 5)
  /// [wait] - If true, use HTTP polling until completion (secondary workflow)
  /// [timeout] - Timeout for wait (optional)
  /// [onProgress] - Callback for job progress updates (MQTT, primary workflow)
  /// [onComplete] - Callback for job completion (MQTT, primary workflow)
  ///
  /// Returns:
  /// - If wait=true: Returns final job status (completed/failed)
  /// - If callbacks provided: Returns initial job status,
  ///   callbacks invoked later (NOT YET IMPLEMENTED)
  /// - Otherwise: Returns initial job status (queued)
  ///
  /// Throws:
  /// - [FileSystemException] if any file doesn't exist or can't be read
  /// - [Exception] if task type not supported or request fails
  ///
  /// Example (HTTP polling - secondary):
  /// ```dart
  /// final job = await client.clipEmbedding.embedImage(
  ///   image: File('photo.jpg'),
  ///   wait: true,
  ///   timeout: Duration(seconds: 30),
  /// );
  /// print('Embedding: ${job.taskOutput}');
  /// ```
  ///
  /// Example (MQTT callbacks - primary, NOT YET IMPLEMENTED):
  /// ```dart
  /// final job = await client.clipEmbedding.embedImage(
  ///   image: File('photo.jpg'),
  ///   onComplete: (status) => print('Done: ${status.status}'),
  /// );
  /// // Note: Currently callbacks are not yet wired up (Part 2: MQTT Implementation)
  /// ```
  Future<Job> submitWithFiles({
    required Map<String, File> files,
    Map<String, String>? params,
    int priority = 5,
    bool wait = false,
    Duration? timeout,
    void Function(JobStatus)? onProgress,
    void Function(JobStatus)? onComplete,
  }) async {
    // Validate all files exist
    for (final entry in files.entries) {
      final file = entry.value;
      if (!await file.exists()) {
        throw FileSystemException('File not found', file.path);
      }
    }

    // Prepare form data body - all values must be strings or stringified
    final body = <String, dynamic>{'priority': priority.toString()};

    // Add plugin-specific parameters (stringify all values)
    if (params != null) {
      for (final entry in params.entries) {
        body[entry.key] = entry.value;
      }
    }

    // Validate file contents and prepare for upload
    // The ComputeService.createJob expects a single 'file' field,
    // but we support multiple files via the files map
    if (files.length > 1) {
      throw UnsupportedError(
        'Multiple file uploads not yet supported. '
        'Current implementation supports single file field.',
      );
    }

    // Get the single file (all current plugins use single file)
    final file = files.values.first;

    // Submit job via ComputeService
    final response = await computeService.createJob(
      taskType: taskType,
      body: body,
      file: file,
      priority: priority,
    );

    // Fetch full job details (submission response may be minimal)
    var job = await computeService.getJob(response.jobId);

    // TODO(anandas): Subscribe to MQTT callbacks if provided
    // (Part 2: MQTT Implementation)

    // When MqttService is implemented, uncomment and wire this up:
    // if (onProgress != null || onComplete != null) {
    //   await mqttService.subscribeJobUpdates(
    //     jobId: job.jobId,
    //     onProgress: onProgress,
    //     onComplete: onComplete,
    //   );
    // }

    // Wait for completion if requested (secondary workflow via HTTP polling)
    if (wait) {
      job = await computeService.waitForJobCompletionWithPolling(
        response.jobId,
        timeout: timeout ?? const Duration(minutes: 5),
      );
    }

    return job;
  }

  /// Guess MIME type from file extension
  ///
  /// Uses the mime package for detection, falls back to octet-stream.
  ///
  /// [file] - File to detect MIME type for
  ///
  /// Returns MIME type string (e.g., 'image/jpeg', 'video/mp4')
  String _guessMimeType(File file) {
    final mimeType = lookupMimeType(file.path);
    return mimeType ?? 'application/octet-stream';
  }
}
