import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockHttpClient extends http.BaseClient {
  MockHttpClient(this.responses);
  final Map<String, http.Response> responses;
  late http.BaseRequest lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final key = '${request.method} ${request.url}';
    final response = responses[key];

    if (response != null) {
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }

    return http.StreamedResponse(
      Stream.value([]),
      404,
      request: request,
    );
  }
}

void main() {
  group('ComputeService Tests', () {
    test('createJob returns Job', () async {
      final mockClient = MockHttpClient({
        'POST $computeServiceBaseUrl/api/v1/job/image_resize': http.Response(
          '''
          {
            "job_id": "job-123",
            "task_type": "image_resize",
            "status": "queued",
            "progress": 0,
            "input_files": [{}],
            "output_files": [],
            "task_output": {},
            "created_at": 1704067200,
            "started_at": null,
            "completed_at": null
          }''',
          201,
        ),
      });

      final computeService = ComputeService(
        token: 'test-token',
        httpClient: mockClient,
      );
      final job = await computeService.createJob(
        taskType: 'image_resize',
        metadata: {'width': 800, 'height': 600},
        externalFiles: [
          {
            'path': '/tmp/test_image.jpg',
            'metadata': {'name': 'input_image'},
          },
        ],
      );

      expect(job.jobId, 'job-123');
      expect(job.taskType, 'image_resize');
      expect(job.status, 'queued');
      expect(job.progress, 0);
    });

    test('getJobStatus returns Job', () async {
      final mockClient = MockHttpClient({
        'GET $computeServiceBaseUrl/api/v1/job/job-123': http.Response(
          '''
{
            "job_id": "job-123",
            "task_type": "image_resize",
            "status": "processing",
            "progress": 45,
            "input_files": ["image.jpg"],
            "output_files": [],
            "task_output": {},
            "created_at": 1704067200,
            "started_at": 1704067210,
            "completed_at": null
          }''',
          200,
        ),
      });

      final computeService = ComputeService(httpClient: mockClient);
      final job = await computeService.getJobStatus('job-123');

      expect(job.jobId, 'job-123');
      expect(job.status, 'processing');
      expect(job.progress, 45);
    });

    test('getJobStatus throws ResourceNotFoundException on 404', () async {
      final mockClient = MockHttpClient({
        'GET $computeServiceBaseUrl/api/v1/job/nonexistent': http.Response(
          '{"detail": "Job not found"}',
          404,
        ),
      });

      final computeService = ComputeService(httpClient: mockClient);

      expect(
        () => computeService.getJobStatus('nonexistent'),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('deleteJob completes successfully', () async {
      final mockClient = MockHttpClient({
        'DELETE $computeServiceBaseUrl/api/v1/job/job-123': http.Response(
          '',
          204,
        ),
      });

      final computeService = ComputeService(
        token: 'test-token',
        httpClient: mockClient,
      );

      expect(() => computeService.deleteJob('job-123'), returnsNormally);
    });

    test('listWorkers returns WorkersListResponse', () async {
      final mockClient = MockHttpClient({
        'GET $computeServiceBaseUrl/api/v1/workers': http.Response(
          '''
{
            "workers": [
              {"worker_id": "worker-1", "running": true, "ttl_remaining": 25},
              {"worker_id": "worker-2", "running": true, "ttl_remaining": 28}
            ],
            "total": 2
          }''',
          200,
        ),
      });

      final computeService = ComputeService(httpClient: mockClient);
      final response = await computeService.listWorkers();

      expect(response.workers, hasLength(2));
      expect(response.workers[0].workerId, 'worker-1');
      expect(response.workers[1].workerId, 'worker-2');
      expect(response.total, 2);
    });

    test('getWorkerStatus returns WorkerStatus', () async {
      final mockClient = MockHttpClient({
        'GET $computeServiceBaseUrl/api/v1/workers/status/worker-1':
            http.Response(
              '{"worker_id": "worker-1", "running": true, "ttl_remaining": 24}',
              200,
            ),
      });

      final computeService = ComputeService(httpClient: mockClient);
      final status = await computeService.getWorkerStatus('worker-1');

      expect(status.workerId, 'worker-1');
      expect(status.running, true);
      expect(status.ttlRemaining, 24);
    });

    test('getWorkerStatus returns running false on 404', () async {
      final mockClient = MockHttpClient({
        'GET $computeServiceBaseUrl/api/v1/workers/status/nonexistent':
            http.Response(
              '{"worker_id": "nonexistent", "running": false}',
              200,
            ),
      });

      final computeService = ComputeService(httpClient: mockClient);
      final status = await computeService.getWorkerStatus('nonexistent');

      expect(status.running, false);
    });

    test('getStorageSize returns StorageSize', () async {
      final mockClient = MockHttpClient({
        'GET $computeServiceBaseUrl/api/v1/admin/storage/size': http.Response(
          '{"total_bytes": 1073741824, "total_mb": 1024.0, "job_count": 5}',
          200,
        ),
      });

      final computeService = ComputeService(
        token: 'test-token',
        httpClient: mockClient,
      );
      final storage = await computeService.getStorageSize();

      expect(storage.totalBytes, 1073741824);
      expect(storage.totalMb, 1024.0);
      expect(storage.jobCount, 5);
    });

    test('cleanupOldJobs returns CleanupResponse', () async {
      final mockClient = MockHttpClient({
        'DELETE $computeServiceBaseUrl/api/v1/admin/cleanup?days=7':
            http.Response(
              '''
{
            "message": "All jobs older than 7 days deleted successfully",
            "deleted_count": 10
          }''',
              200,
            ),
      });

      final computeService = ComputeService(
        token: 'test-token',
        httpClient: mockClient,
      );
      final response = await computeService.cleanupOldJobs(days: 7);

      expect(response.deletedCount, 10);
      expect(response.message, contains('deleted successfully'));
    });

    test('cleanupOldJobs throws PermissionException on 403', () async {
      final mockClient = MockHttpClient({
        'DELETE $computeServiceBaseUrl/api/v1/admin/cleanup?days=7':
            http.Response(
              '{"detail": "Not enough permissions"}',
              403,
            ),
      });

      final computeService = ComputeService(httpClient: mockClient);

      expect(
        () => computeService.cleanupOldJobs(days: 7),
        throwsA(isA<PermissionException>()),
      );
    });
  });
}
