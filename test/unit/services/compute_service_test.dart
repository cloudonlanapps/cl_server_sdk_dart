import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('ComputeService Tests', () {
    test('createJob returns Job', () async {
      final mockClient = MockHttpClient({
        // ignore: lines_longer_than_80_chars will become unreadable
        'POST $computeServiceBaseUrl${ComputeServiceEndpoints.createJob.replaceAll('{task_type}', 'image_resize')}':
            http.Response(
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
        computeServiceBaseUrl,
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
        // ignore: lines_longer_than_80_chars will become unreadable
        'GET $computeServiceBaseUrl${ComputeServiceEndpoints.getJobStatus.replaceAll('{job_id}', 'job-123')}':
            http.Response(
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

      final computeService = ComputeService(
        computeServiceBaseUrl,
        httpClient: mockClient,
      );
      final job = await computeService.getJobStatus('job-123');

      expect(job.jobId, 'job-123');
      expect(job.status, 'processing');
      expect(job.progress, 45);
    });

    test('getJobStatus throws ResourceNotFoundException on 404', () async {
      final mockClient = MockHttpClient({
        // ignore: lines_longer_than_80_chars will become unreadable
        'GET $computeServiceBaseUrl${ComputeServiceEndpoints.getJobStatus.replaceAll('{job_id}', 'nonexistent')}':
            http.Response(
              '{"detail": "Job not found"}',
              404,
            ),
      });

      final computeService = ComputeService(
        computeServiceBaseUrl,
        httpClient: mockClient,
      );

      expect(
        () => computeService.getJobStatus('nonexistent'),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('deleteJob completes successfully', () async {
      final mockClient = MockHttpClient({
        // ignore: lines_longer_than_80_chars will become unreadable
        'DELETE $computeServiceBaseUrl${ComputeServiceEndpoints.deleteJob.replaceAll('{job_id}', 'job-123')}':
            http.Response(
              '',
              204,
            ),
      });
      //compute/jobs/jobs-123
      final computeService = ComputeService(
        computeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );

      expect(() => computeService.deleteJob('job-123'), returnsNormally);
    });

    test('getStorageSize returns StorageSize', () async {
      final mockClient = MockHttpClient({
        'GET $computeServiceBaseUrl${ComputeServiceEndpoints.getStorageSize}':
            http.Response(
              '{"total_bytes": 1073741824, "total_mb": 1024.0, "job_count": 5}',
              200,
            ),
      });

      final computeService = ComputeService(
        computeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final storage = await computeService.getStorageSize();

      expect(storage.totalBytes, 1073741824);
      expect(storage.totalMb, 1024.0);
      expect(storage.jobCount, 5);
    });

    test('getCapabilities returns WorkerCapabilities', () async {
      final mockClient = MockHttpClient({
        'GET $computeServiceBaseUrl${ComputeServiceEndpoints.getCapabilities}':
            http.Response(
              '''
          {
            "num_workers": 3,
            "capabilities": {
              "image_resize": 2,
              "image_conversion": 1
            }
          }''',
              200,
            ),
      });

      final computeService = ComputeService(
        computeServiceBaseUrl,
        httpClient: mockClient,
      );
      final capabilities = await computeService.getCapabilities();

      expect(capabilities.numWorkers, 3);
      expect(capabilities.capabilities['image_resize'], 2);
      expect(capabilities.capabilities['image_conversion'], 1);
    });

    test('cleanupOldJobs returns CleanupResponse', () async {
      final mockClient = MockHttpClient({
        'DELETE $computeServiceBaseUrl'
            '${ComputeServiceEndpoints.cleanupOldJobs}?days=7': http.Response(
          '''
{
            "message": "All jobs older than 7 days deleted successfully",
            "deleted_count": 10
          }''',
          200,
        ),
      });

      final computeService = ComputeService(
        computeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final response = await computeService.cleanupOldJobs(days: 7);

      expect(response.deletedCount, 10);
      expect(response.message, contains('deleted successfully'));
    });

    test('cleanupOldJobs throws PermissionException on 403', () async {
      final mockClient = MockHttpClient({
        'DELETE $computeServiceBaseUrl'
            '${ComputeServiceEndpoints.cleanupOldJobs}?days=7': http.Response(
          '{"detail": "Not enough permissions"}',
          403,
        ),
      });

      final computeService = ComputeService(
        computeServiceBaseUrl,
        httpClient: mockClient,
      );

      expect(
        () => computeService.cleanupOldJobs(days: 7),
        throwsA(isA<PermissionException>()),
      );
    });
  });
}
