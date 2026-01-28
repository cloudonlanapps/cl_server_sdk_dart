import 'dart:async';
import 'dart:io';

import '../config.dart';
import '../http_utils.dart';
import '../models/models.dart';

/// Protocol for client operations required by plugins.
abstract class ClientProtocol {
  Future<String> httpSubmitJob(
    String endpoint, {
    required Map<String, File> files,
    Map<String, dynamic>? data,
  });

  Future<JobResponse> getJob(String jobId);

  Future<JobResponse> waitForJob(
    String jobId, {
    Duration? pollInterval,
    Duration? timeout,
  });

  String mqttSubscribeJobUpdates(
    String jobId, {
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
    String taskType = 'unknown',
  });
}

/// Base class for plugin-specific clients.
class BasePluginClient {
  BasePluginClient(this.client, this.taskType)
    : endpoint = ComputeClientConfig.getPluginEndpoint(taskType);
  final ClientProtocol client;
  final String taskType;
  final String endpoint;

  Future<JobResponse> submitJob({
    Map<String, Object>? params,
    int priority = 5,
    bool wait = false,
    Duration? timeout,
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
  }) async {
    throw UnimplementedError(
      '$taskType requires file uploads. '
      'Use submitWithFiles() instead. '
      'This method is reserved for future file-less plugins.',
    );
  }

  Future<JobResponse> submitWithFiles({
    required Map<String, File> files,
    Map<String, Object>? params,
    int priority = 5,
    bool wait = false,
    Duration? timeout,
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
  }) async {
    // 1. Submit job (http)
    final jobId = await client.httpSubmitJob(
      endpoint,
      files: files,
      data: HttpUtils.buildFormData(params: params, priority: priority),
    );

    // 2. Fetch full job details
    final job = await client.getJob(jobId);

    // 3. Subscribe to MQTT callbacks if provided
    if (onProgress != null || onComplete != null) {
      client.mqttSubscribeJobUpdates(
        jobId,
        onProgress: onProgress,
        onComplete: onComplete,
        taskType: taskType,
      );
    }

    // 4. Wait for completion if requested
    if (wait) {
      return client.waitForJob(jobId, timeout: timeout);
    }

    return job;
  }
}
