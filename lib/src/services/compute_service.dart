import 'dart:async';
import 'dart:io';

import 'package:cl_server_dart_client/src/core/http_client.dart'
    show HttpClientWrapper;
import 'package:cl_server_dart_client/src/core/models/compute_models.dart'
    show CleanupResult, CreateJobResponse, Job, StorageInfo, WorkerCapabilities;
import 'package:http/http.dart' as http;

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

  /// ----------------------------
  /// Worker Capability Management
  /// ----------------------------

  Future<WorkerCapabilities> getCapabilities() async {
    final json = await _httpClient.get('/compute/capabilities');
    // Handle both flat format (tests) and nested format (real server)
    final capabilitiesMap = json.containsKey('capabilities')
        ? json['capabilities'] as Map<String, dynamic>
        : json;
    return capabilitiesMap.map<String, int>((key, value) {
      final intValue = value is int ? value : (value as num).toInt();
      return MapEntry(key, intValue);
    });
  }

  /// ----------------------------
  /// Job Creation (Generic)
  /// ----------------------------

  Future<CreateJobResponse> createJob({
    required String taskType,
    required Map<String, dynamic> body,
    File? file,
    int? priority,
  }) async {
    final caps = await getCapabilities();
    if (!caps.containsKey(taskType)) {
      throw UnsupportedError(
        "Task type '$taskType' not supported. "
        "Available: ${caps.keys.join(', ')}",
      );
    }

    final fields = {...body};
    if (priority != null) {
      fields['priority'] = priority;
    }

    final json = await _httpClient.post(
      '/compute/jobs/$taskType',
      body: fields,
      files: file != null ? {'file': file} : null,
    );

    return CreateJobResponse.fromJson(json);
  }

  /// ----------------------------
  /// Job Status Management
  /// ----------------------------

  Future<Job> getJob(String jobId) async {
    final json = await _httpClient.get('/compute/jobs/$jobId');
    return Job.fromMap(json);
  }

  Future<void> deleteJob(String jobId) async {
    await _httpClient.delete('/compute/jobs/$jobId');
  }

  /// ----------------------------
  /// Admin — Compute Job Storage
  /// ----------------------------

  Future<StorageInfo> getStorageSize() async {
    final json = await _httpClient.get('/admin/compute/jobs/storage/size');
    return StorageInfo.fromJson(json);
  }

  Future<CleanupResult> cleanupOldJobs({int days = 7}) async {
    final json = await _httpClient.delete(
      '/admin/compute/jobs/cleanup',
      queryParameters: {'days': days.toString()},
    );
    return CleanupResult.fromJson(json);
  }

  /// ----------------------------
  /// Wait for completion — Polling
  /// ----------------------------

  Future<Job> waitForJobCompletionWithPolling(
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
    void Function(Job)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (true) {
      final job = await getJob(jobId);

      onProgress?.call(job);

      if (job.isFinished) {
        return job;
      }

      if (stopwatch.elapsed > timeout) {
        throw TimeoutException(
          'Timeout waiting for job: $jobId',
          timeout,
        );
      }

      await Future<void>.delayed(interval);
    }
  }

  /// ----------------------------
  /// Wait for completion — MQTT
  /// (Implementation unchanged — same topic + payload pattern)
  /// ----------------------------

  Future<Job> waitForJobCompletionWithMQTT({
    required String jobId,
    required Stream<Job> jobUpdateStream,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final completer = Completer<Job>();
    late StreamSubscription<Job> sub;

    sub = jobUpdateStream.listen(
      (update) {
        if (update.jobId == jobId && update.isFinished) {
          completer.complete(update);
        }
      },
      onError: completer.completeError,
    );

    return completer.future.timeout(timeout).whenComplete(() => sub.cancel());
  }
}
