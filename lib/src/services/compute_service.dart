import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../core/http_client.dart';
import '../core/models/compute_models.dart';
import '../utils/constants.dart';

/// Client for CL Server Compute Service
class ComputeService {
  ComputeService(
    this.baseUrl, {
    this.token,
    http.Client? httpClient,
  }) {
    _httpClient = HttpClientWrapper(
      baseUrl: baseUrl,
      token: token,
      httpClient: httpClient,
    );
  }
  final String baseUrl;
  final String? token;
  late final HttpClientWrapper _httpClient;

  /// Create a new compute job
  /// POST /compute/jobs/{task_type}
  ///
  /// Parameters:
  /// - [taskType]: The type of task to execute
  /// - [metadata]: Optional metadata to attach to the job
  /// - [uploadFiles]: Optional list of file paths to upload with the job
  /// - [externalFiles]: Optional list of external file references
  ///     with 'path' and optional 'metadata' keys
  Future<Job> createJob({
    required String taskType,
    Map<String, dynamic>? metadata,
    List<String>? uploadFiles,
    List<Map<String, dynamic>>? externalFiles,
  }) async {
    final endpoint = ComputeServiceEndpoints.createJob.replaceAll(
      '{task_type}',
      taskType,
    );

    final body = <String, dynamic>{
      ...?metadata,
    };

    // Add external files if provided
    if (externalFiles != null && externalFiles.isNotEmpty) {
      body['external_files'] = jsonEncode(externalFiles);
    }

    // Convert string paths to File objects
    final files = uploadFiles?.map((path) => File(path)).toList();

    final response = await _httpClient.post(
      endpoint,
      body: body.isNotEmpty ? body : {},
      isFormData: true,
      files: files,
    );
    return Job.fromMap(response);
  }

  /// Get job status
  /// GET /compute/jobs/{job_id}
  Future<Job> getJobStatus(String jobId) async {
    final endpoint = ComputeServiceEndpoints.getJobStatus.replaceAll(
      '{job_id}',
      jobId,
    );

    final response = await _httpClient.get(endpoint);
    return Job.fromMap(response);
  }

  /// Delete job
  /// DELETE /compute/jobs/{job_id}
  Future<void> deleteJob(String jobId) async {
    final endpoint = ComputeServiceEndpoints.deleteJob.replaceAll(
      '{job_id}',
      jobId,
    );
    await _httpClient.delete(endpoint);
  }

  /// Get available worker capabilities
  /// GET /compute/capabilities
  Future<WorkerCapabilities> getCapabilities() async {
    final response = await _httpClient.get(
      ComputeServiceEndpoints.getCapabilities,
    );
    return WorkerCapabilities.fromMap(response);
  }

  /// Get storage size
  /// GET /admin/compute/jobs/storage/size
  Future<StorageSize> getStorageSize() async {
    final response = await _httpClient.get(
      ComputeServiceEndpoints.getStorageSize,
    );
    return StorageSize.fromJson(response);
  }

  /// Cleanup old jobs
  /// DELETE /admin/compute/jobs/cleanup?days=7
  Future<CleanupResponse> cleanupOldJobs({
    required int days,
  }) async {
    final response = await _httpClient.delete(
      ComputeServiceEndpoints.cleanupOldJobs,
      queryParameters: {
        QueryParameters.days: days.toString(),
      },
    );
    return CleanupResponse.fromJson(response);
  }

  /// Wait for job completion using HTTP polling
  /// Polls the job status endpoint every [pollInterval] until [timeout] is exceeded
  /// Throws TimeoutException if job doesn't complete within timeout
  /// Returns the completed Job object
  Future<Job> waitForJobCompletionWithPolling(
    String jobId, {
    Duration timeout = const Duration(minutes: 5),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      final job = await getJobStatus(jobId);

      // Check if job completed or failed
      if (job.status == 'completed' || job.status == 'failed') {
        return job;
      }

      // Check timeout
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > timeout) {
        throw TimeoutException(
          'Job $jobId did not complete within $timeout',
        );
      }

      // Wait before next poll
      await Future<void>.delayed(pollInterval);
    }
  }

  /// Wait for job completion using MQTT event listening
  /// Subscribes to inference/events topic and waits for job completion message
  /// Throws TimeoutException if job doesn't complete within timeout
  /// Returns the completed Job object parsed from MQTT message
  Future<Job> waitForJobCompletionWithMQTT(
    String jobId, {
    String brokerUrl = 'localhost',
    int brokerPort = 1883,
    Duration timeout = const Duration(minutes: 5),
    String eventTopic = 'inference/events',
  }) async {
    final client = MqttServerClient(brokerUrl, 'dart-client-$jobId');
    client.port = brokerPort;
    client.keepAlivePeriod = 20;
    client.logging(on: false);

    try {
      // Connect to broker
      await client.connect();

      final completer = Completer<Job>();

      // Subscribe to job events topic
      client.subscribe(eventTopic, MqttQos.atLeastOnce);

      // Setup message listener for job completion events
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        // Convert byte array to string
        final messageBytes = recMess.payload.message;
        final pt = String.fromCharCodes(messageBytes);

        try {
          final eventData = jsonDecode(pt) as Map<String, dynamic>;
          final eventJobId = eventData['job_id'] as String?;
          final eventType = eventData['event_type'] as String?;

          // Only process events for this specific job
          if (eventJobId == jobId) {
            // Check if job completed or failed
            if (eventType == 'completed' || eventType == 'failed') {
              if (!completer.isCompleted) {
                // Get full job status via HTTP if needed, or construct from event
                final outputFiles = eventData['output_files'] as List<dynamic>?;
                final jobData = <String, dynamic>{
                  'job_id': jobId,
                  'status': eventType == 'completed' ? 'completed' : 'failed',
                  'output_files': outputFiles ?? <String>[],
                  'task_output': eventData['error'] != null
                      ? <String, dynamic>{'error': eventData['error']}
                      : <String, dynamic>{},
                  'created_at': eventData['timestamp'] ?? 0,
                };
                completer.complete(Job.fromMap(jobData));
              }
            }
          }
        } on Exception {
          // Ignore parsing errors and continue listening
        }
      });

      // Wait for completion with timeout
      final job = await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Job $jobId did not complete within $timeout',
          );
        },
      );

      return job;
    } finally {
      client.disconnect();
    }
  }
}
