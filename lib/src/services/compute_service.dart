import 'dart:convert';

import 'package:http/http.dart' as http;

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
  /// - [externalFiles]: Optional list of external file references
  ///     with 'path' and optional 'metadata' keys
  Future<Job> createJob({
    required String taskType,
    Map<String, dynamic>? metadata,
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

    final response = await _httpClient.post(
      endpoint,
      body: body.isNotEmpty ? body : {},
      isFormData: true,
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
}
