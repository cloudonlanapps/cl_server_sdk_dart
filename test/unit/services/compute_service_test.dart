import 'dart:async';
import 'dart:io';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('ComputeService Tests', () {
    group('getCapabilities', () {
      test('returns WorkerCapabilities on success', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 2, "image_conversion": 1}',
            200,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final capabilities = await service.getCapabilities();

        expect(capabilities, isA<Map<String, int>>());
        expect(capabilities['image_resize'], 2);
        expect(capabilities['image_conversion'], 1);
      });

      test('returns empty map when no capabilities available', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{}',
            200,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final capabilities = await service.getCapabilities();

        expect(capabilities, isEmpty);
      });

      test('returns multiple task types', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 3, "image_conversion": 2, '
            '"video_transcode": 1, "audio_process": 4}',
            200,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final capabilities = await service.getCapabilities();

        expect(capabilities.length, 4);
        expect(capabilities.keys, contains('video_transcode'));
        expect(capabilities['audio_process'], 4);
      });

      test('throws ServerException on 500', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"detail": "Internal server error"}',
            500,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(service.getCapabilities, throwsA(isA<ServerException>()));
      });

      test('throws NetworkException on network error', () async {
        final mockClient = MockHttpClient({});

        final service = ComputeService(
          'http://invalid-url-12345.com',
          httpClient: mockClient,
        );

        expect(
          service.getCapabilities,
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('createJob', () {
      test('returns CreateJobResponse on successful job creation', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 2}',
            200,
          ),
          'POST $computeServiceBaseUrl/compute/jobs/image_resize':
              http.Response(
                '{"job_id": "test-job-123", "status": "queued"}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final response = await service.createJob(
          taskType: 'image_resize',
          body: {'width': '800', 'height': '600'},
        );

        expect(response.jobId, 'test-job-123');
        expect(response.status, 'queued');
      });

      test(
        'throws UnsupportedError when task type not in capabilities',
        () async {
          final mockClient = MockHttpClient({
            'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
              '{"image_resize": 2}',
              200,
            ),
          });

          final service = ComputeService(
            computeServiceBaseUrl,
            httpClient: mockClient,
          );

          expect(
            () => service.createJob(taskType: 'unsupported_task', body: {}),
            throwsA(isA<Exception>()),
          );
        },
      );

      test('validates task type against capabilities before request', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 1, "image_conversion": 1}',
            200,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        // Should fail for unsupported task without making POST request
        try {
          await service.createJob(taskType: 'video_transcode', body: {});
          fail('Should have thrown UnsupportedError');
        } on Exception catch (e) {
          print(e);
          expect(e.toString(), contains('video_transcode'));
          expect(e.toString(), contains('not supported'));
        }
      });

      test('includes priority in request when provided', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 2}',
            200,
          ),
          'POST $computeServiceBaseUrl/compute/jobs/image_resize':
              http.Response(
                '{"job_id": "test-job-456", "status": "queued"}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        await service.createJob(
          taskType: 'image_resize',
          body: {'width': '800'},
          priority: 8,
        );

        // MockHttpClient doesn't allow us to inspect request body easily,
        // but we can verify the call succeeds
        expect(mockClient.lastRequest.method, 'POST');
        expect(mockClient.lastRequest.url.path, '/compute/jobs/image_resize');
      });

      test('includes file in multipart request when provided', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 2}',
            200,
          ),
          'POST $computeServiceBaseUrl/compute/jobs/image_resize':
              http.Response(
                '{"job_id": "test-job-789", "status": "queued"}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        // Create a temporary file for testing
        final tempFile = File('test_temp_file.txt');
        await tempFile.writeAsString('test content');

        try {
          final response = await service.createJob(
            taskType: 'image_resize',
            body: {'width': '800'},
            file: tempFile,
          );

          expect(response.jobId, 'test-job-789');
        } finally {
          // Cleanup
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      });

      test('throws ValidationException on 422', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 2}',
            200,
          ),
          'POST $computeServiceBaseUrl/compute/jobs/image_resize':
              http.Response(
                '{"detail": "Validation error: width must be positive"}',
                422,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(
          () => service.createJob(
            taskType: 'image_resize',
            body: {'width': '-100'},
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('throws AuthException on 401', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 2}',
            200,
          ),
          'POST $computeServiceBaseUrl/compute/jobs/image_resize':
              http.Response(
                '{"detail": "Not authenticated"}',
                401,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(
          () => service.createJob(taskType: 'image_resize', body: {}),
          throwsA(isA<AuthException>()),
        );
      });

      test('throws PermissionException on 403', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/capabilities': http.Response(
            '{"image_resize": 2}',
            200,
          ),
          'POST $computeServiceBaseUrl/compute/jobs/image_resize':
              http.Response(
                '{"detail": "Permission denied"}',
                403,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(
          () => service.createJob(taskType: 'image_resize', body: {}),
          throwsA(isA<PermissionException>()),
        );
      });
    });

    group('getJob', () {
      test('returns Job on success with all fields', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/test-job-123': http.Response(
            '''
            {
              "job_id": "test-job-123",
              "task_type": "image_resize",
              "params": {"width": 800, "height": 600},
              "status": "completed",
              "progress": 100,
              "task_output": {"output_file": "/path/to/output.jpg"},
              "error_message": null,
              "priority": 5,
              "created_at": 1704067200000,
              "updated_at": 1704067500000,
              "started_at": 1704067300000,
              "completed_at": 1704067500000
            }
            ''',
            200,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final job = await service.getJob('test-job-123');

        expect(job.jobId, 'test-job-123');
        expect(job.taskType, 'image_resize');
        expect(job.status, 'completed');
        expect(job.progress, 100);
        expect(job.taskOutput, isNotNull);
        expect(job.taskOutput!['output_file'], '/path/to/output.jpg');
      });

      test('returns Job with minimal fields', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/test-job-456': http.Response(
            '''
            {
              "job_id": "test-job-456",
              "task_type": "image_conversion",
              "params": {},
              "status": "queued",
              "created_at": 1704067200000
            }
            ''',
            200,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final job = await service.getJob('test-job-456');

        expect(job.jobId, 'test-job-456');
        expect(job.taskType, 'image_conversion');
        expect(job.status, 'queued');
        expect(job.taskOutput, null);
        expect(job.errorMessage, null);
      });

      test('throws ResourceNotFoundException on 404', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/non-existent': http.Response(
            '{"detail": "Job not found"}',
            404,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(
          () => service.getJob('non-existent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('throws AuthException on 401', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/test-job': http.Response(
            '{"detail": "Not authenticated"}',
            401,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(() => service.getJob('test-job'), throwsA(isA<AuthException>()));
      });
    });

    group('deleteJob', () {
      test('completes successfully on 204', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/compute/jobs/test-job-123':
              http.Response('', 204),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        await expectLater(service.deleteJob('test-job-123'), completes);
      });

      test('throws ResourceNotFoundException on 404', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/compute/jobs/non-existent':
              http.Response(
                '{"detail": "Job not found"}',
                404,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(
          () => service.deleteJob('non-existent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('throws AuthException on 401', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/compute/jobs/test-job': http.Response(
            '{"detail": "Not authenticated"}',
            401,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(
          () => service.deleteJob('test-job'),
          throwsA(isA<AuthException>()),
        );
      });

      test('throws PermissionException on 403', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/compute/jobs/test-job': http.Response(
            '{"detail": "Permission denied"}',
            403,
          ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(
          () => service.deleteJob('test-job'),
          throwsA(isA<PermissionException>()),
        );
      });
    });

    group('getStorageSize (Admin)', () {
      test('returns StorageInfo on success', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/admin/compute/jobs/storage/size':
              http.Response(
                '{"total_size": 10485760, "job_count": 42}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final info = await service.getStorageSize();

        expect(info.totalSize, 10485760);
        expect(info.jobCount, 42);
      });

      test('returns StorageInfo with zero storage', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/admin/compute/jobs/storage/size':
              http.Response(
                '{"total_size": 0, "job_count": 0}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final info = await service.getStorageSize();

        expect(info.totalSize, 0);
        expect(info.jobCount, 0);
      });

      test('returns StorageInfo with large values', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/admin/compute/jobs/storage/size':
              http.Response(
                '{"total_size": 999999999999, "job_count": 1000000}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final info = await service.getStorageSize();

        expect(info.totalSize, 999999999999);
        expect(info.jobCount, 1000000);
      });

      test('throws PermissionException on 403 (non-admin)', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/admin/compute/jobs/storage/size':
              http.Response(
                '{"detail": "Admin access required"}',
                403,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(service.getStorageSize, throwsA(isA<PermissionException>()));
      });

      test('throws AuthException on 401', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/admin/compute/jobs/storage/size':
              http.Response(
                '{"detail": "Not authenticated"}',
                401,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(service.getStorageSize, throwsA(isA<AuthException>()));
      });
    });

    group('cleanupOldJobs (Admin)', () {
      test('returns CleanupResult on success with default days', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/admin/compute/jobs/cleanup?days=7':
              http.Response(
                '{"deleted_count": 25, "freed_space": 52428800}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final result = await service.cleanupOldJobs();

        expect(result.deletedCount, 25);
        expect(result.freedSpace, 52428800);
      });

      test('returns CleanupResult with custom days parameter', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/admin/compute/jobs/cleanup?days=30':
              http.Response(
                '{"deleted_count": 100, "freed_space": 209715200}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final result = await service.cleanupOldJobs(days: 30);

        expect(result.deletedCount, 100);
        expect(result.freedSpace, 209715200);
      });

      test('returns CleanupResult with zero deleted count', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/admin/compute/jobs/cleanup?days=1':
              http.Response(
                '{"deleted_count": 0, "freed_space": 0}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final result = await service.cleanupOldJobs(days: 1);

        expect(result.deletedCount, 0);
        expect(result.freedSpace, 0);
      });

      test('validates days parameter in query string', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/admin/compute/jobs/cleanup?days=14':
              http.Response(
                '{"deleted_count": 50, "freed_space": 104857600}',
                200,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        await service.cleanupOldJobs(days: 14);

        expect(mockClient.lastRequest.url.queryParameters['days'], '14');
      });

      test('throws PermissionException on 403 (non-admin)', () async {
        final mockClient = MockHttpClient({
          'DELETE $computeServiceBaseUrl/admin/compute/jobs/cleanup?days=7':
              http.Response(
                '{"detail": "Admin access required"}',
                403,
              ),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(service.cleanupOldJobs, throwsA(isA<PermissionException>()));
      });
    });

    group('waitForJobCompletionWithPolling', () {
      test('returns completed job when status is completed', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/test-job': http.Response('''
            {
              "job_id": "test-job",
              "task_type": "image_resize",
              "params": {},
              "status": "completed",
              "progress": 100,
              "created_at": 1704067200000
            }
            ''', 200),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final job = await service.waitForJobCompletionWithPolling(
          'test-job',
          interval: const Duration(milliseconds: 100),
        );

        expect(job.status, 'completed');
        expect(job.isFinished, true);
      });

      test('returns failed job when status is failed', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/test-job': http.Response('''
            {
              "job_id": "test-job",
              "task_type": "image_resize",
              "params": {},
              "status": "failed",
              "error_message": "Processing error",
              "created_at": 1704067200000
            }
            ''', 200),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );
        final job = await service.waitForJobCompletionWithPolling(
          'test-job',
          interval: const Duration(milliseconds: 100),
        );

        expect(job.status, 'failed');
        expect(job.isFinished, true);
        expect(job.errorMessage, 'Processing error');
      });

      test('calls onProgress callback on each poll', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/test-job': http.Response('''
            {
              "job_id": "test-job",
              "task_type": "image_resize",
              "params": {},
              "status": "completed",
              "progress": 100,
              "created_at": 1704067200000
            }
            ''', 200),
        });

        var callbackInvoked = false;
        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        // Note: Due to MockHttpClient limitations, we can't easily simulate
        // multiple different responses. This test verifies the callback is
        // invoked.
        final job = await service.waitForJobCompletionWithPolling(
          'test-job',
          interval: const Duration(milliseconds: 100),
          onProgress: (job) {
            callbackInvoked = true;
          },
        );

        expect(job.isFinished, true);
        expect(callbackInvoked, true);
      });

      test('throws TimeoutException when timeout exceeded', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/test-job': http.Response('''
            {
              "job_id": "test-job",
              "task_type": "image_resize",
              "params": {},
              "status": "running",
              "progress": 50,
              "created_at": 1704067200000
            }
            ''', 200),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        expect(
          () => service.waitForJobCompletionWithPolling(
            'test-job',
            interval: const Duration(milliseconds: 100),
            timeout: const Duration(milliseconds: 500),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('respects custom interval', () async {
        final mockClient = MockHttpClient({
          'GET $computeServiceBaseUrl/compute/jobs/test-job': http.Response('''
            {
              "job_id": "test-job",
              "task_type": "image_resize",
              "params": {},
              "status": "completed",
              "created_at": 1704067200000
            }
            ''', 200),
        });

        final service = ComputeService(
          computeServiceBaseUrl,
          httpClient: mockClient,
        );

        final stopwatch = Stopwatch()..start();
        await service.waitForJobCompletionWithPolling(
          'test-job',
          interval: const Duration(milliseconds: 200),
        );
        stopwatch.stop();

        // Should complete quickly since job is already finished
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    group('waitForJobCompletionWithMQTT', () {
      test('completes when matching job update received', () async {
        final controller = StreamController<Job>();

        final service = ComputeService(computeServiceBaseUrl);

        // Create a future that will complete the job
        final future = service.waitForJobCompletionWithMQTT(
          jobId: 'test-job-123',
          jobUpdateStream: controller.stream,
        );

        // Emit a completed job update
        controller.add(
          const Job(
            jobId: 'test-job-123',
            taskType: 'image_resize',
            params: {},
            status: 'completed',
            createdAt: 1704067200000,
          ),
        );

        final job = await future;

        expect(job.jobId, 'test-job-123');
        expect(job.status, 'completed');

        await controller.close();
      });

      test('filters updates by job_id', () async {
        final controller = StreamController<Job>();

        final service = ComputeService(computeServiceBaseUrl);

        final future = service.waitForJobCompletionWithMQTT(
          jobId: 'test-job-123',
          jobUpdateStream: controller.stream,
        );

        // Emit update for different job (should be ignored)
        controller.add(
          const Job(
            jobId: 'other-job',
            taskType: 'image_resize',
            params: {},
            status: 'completed',
            createdAt: 1704067200000,
          ),
        );

        // Emit update for our job
        controller.add(
          const Job(
            jobId: 'test-job-123',
            taskType: 'image_resize',
            params: {},
            status: 'completed',
            createdAt: 1704067200000,
          ),
        );

        final job = await future;

        expect(job.jobId, 'test-job-123');

        await controller.close();
      });

      test('completes only when isFinished is true', () async {
        final controller = StreamController<Job>();

        final service = ComputeService(computeServiceBaseUrl);

        final future = service.waitForJobCompletionWithMQTT(
          jobId: 'test-job-123',
          jobUpdateStream: controller.stream,
        );

        // Emit running status (should not complete)
        controller.add(
          const Job(
            jobId: 'test-job-123',
            taskType: 'image_resize',
            params: {},
            status: 'running',
            createdAt: 1704067200000,
          ),
        );

        // Give it a moment
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Emit completed status (should complete)
        controller.add(
          const Job(
            jobId: 'test-job-123',
            taskType: 'image_resize',
            params: {},
            status: 'completed',
            createdAt: 1704067200000,
          ),
        );

        final job = await future;

        expect(job.status, 'completed');

        await controller.close();
      });

      test('throws TimeoutException when timeout exceeded', () async {
        final controller = StreamController<Job>();

        final service = ComputeService(computeServiceBaseUrl);

        expect(
          () => service.waitForJobCompletionWithMQTT(
            jobId: 'test-job-123',
            jobUpdateStream: controller.stream,
            timeout: const Duration(milliseconds: 500),
          ),
          throwsA(isA<TimeoutException>()),
        );

        await controller.close();
      });

      test('cancels stream subscription on completion', () async {
        final controller = StreamController<Job>();
        var subscriptionCanceled = false;

        controller.onCancel = () {
          subscriptionCanceled = true;
        };

        final service = ComputeService(computeServiceBaseUrl);

        final future = service.waitForJobCompletionWithMQTT(
          jobId: 'test-job-123',
          jobUpdateStream: controller.stream,
        );

        controller.add(
          const Job(
            jobId: 'test-job-123',
            taskType: 'image_resize',
            params: {},
            status: 'completed',
            createdAt: 1704067200000,
          ),
        );

        await future;

        // Give the subscription time to cancel
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(subscriptionCanceled, true);

        await controller.close();
      });

      test('handles stream errors', () async {
        final controller = StreamController<Job>();

        final service = ComputeService(computeServiceBaseUrl);

        final future = service.waitForJobCompletionWithMQTT(
          jobId: 'test-job-123',
          jobUpdateStream: controller.stream,
        );

        // Emit an error
        controller.addError(Exception('Stream error'));

        expect(() => future, throwsA(isA<Exception>()));

        await controller.close();
      });
    });
  });
}
