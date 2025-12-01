import 'package:http/http.dart' as http;

import '../core/http_client.dart';
import '../core/models/compute_models.dart';
import '../utils/constants.dart';

/// Client for CL Server Compute Service (Port 8002)
class ComputeService {
  ComputeService({
    String? baseUrl,
    this.token,
    http.Client? httpClient,
  }) : baseUrl = baseUrl ?? computeServiceBaseUrl {
    _httpClient = HttpClientWrapper(
      baseUrl: this.baseUrl,
      token: token,
      httpClient: httpClient,
    );
  }
  final String baseUrl;
  final String? token;
  late final HttpClientWrapper _httpClient;

  /// Create a new compute job
  /// POST /api/v1/job/{task_type}
  Future<Job> createJob({
    required String taskType,
    Map<String, dynamic>? metadata,
  }) async {
    final endpoint = ComputeServiceEndpoints.createJob.replaceAll(
      '{task_type}',
      taskType,
    );

    final response = await _httpClient.post(
      endpoint,
      body: metadata ?? {},
      isFormData: true,
    );
    return Job.fromJson(response);
  }

  /// Get job status
  /// GET /api/v1/job/{job_id}
  Future<Job> getJobStatus(String jobId) async {
    final endpoint = ComputeServiceEndpoints.getJobStatus.replaceAll(
      '{job_id}',
      jobId,
    );

    final response = await _httpClient.get(endpoint);
    return Job.fromJson(response);
  }

  /// Delete job
  /// DELETE /api/v1/job/{job_id}
  Future<void> deleteJob(String jobId) async {
    final endpoint = ComputeServiceEndpoints.deleteJob.replaceAll(
      '{job_id}',
      jobId,
    );
    await _httpClient.delete(endpoint);
  }

  /// List all workers
  /// GET /api/v1/workers
  Future<WorkersListResponse> listWorkers() async {
    final response = await _httpClient.get(ComputeServiceEndpoints.listWorkers);
    return WorkersListResponse.fromJson(response);
  }

  /// Get specific worker status
  /// GET /api/v1/workers/status/{worker_id}
  Future<WorkerStatus> getWorkerStatus(String workerId) async {
    final endpoint = ComputeServiceEndpoints.getWorkerStatus.replaceAll(
      '{worker_id}',
      workerId,
    );

    final response = await _httpClient.get(endpoint);
    return WorkerStatus.fromJson(response);
  }

  /// Get storage size
  /// GET /api/v1/admin/storage/size
  Future<StorageSize> getStorageSize() async {
    final response = await _httpClient.get(
      ComputeServiceEndpoints.getStorageSize,
    );
    return StorageSize.fromJson(response);
  }

  /// Cleanup old jobs
  /// DELETE /api/v1/admin/cleanup?days=7
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
