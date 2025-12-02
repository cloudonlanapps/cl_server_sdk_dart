import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('Compute Models Tests', () {
    group('Job Model', () {
      final sampleJobJson = <String, dynamic>{
        'job_id': 'job-123',
        'task_type': 'image_resize',
        'status': 'processing',
        'progress': 45,
        'input_files': <String>['image.jpg'],
        'output_files': <String>[],
        'task_output': <String, dynamic>{},
        'created_at': 1704067200,
        'started_at': 1704067210,
        'completed_at': null,
      };

      test('Job.fromJson creates instance correctly', () {
        final job = Job.fromJson(sampleJobJson);

        expect(job.jobId, 'job-123');
        expect(job.taskType, 'image_resize');
        expect(job.status, 'processing');
        expect(job.progress, 45);
        expect(job.inputFiles, <String>['image.jpg']);
      });

      test('Job.toJson serializes correctly', () {
        final job = Job.fromJson(sampleJobJson);
        final json = job.toJson();

        expect(json['job_id'], 'job-123');
        expect(json['task_type'], 'image_resize');
        expect(json['progress'], 45);
      });

      test('Job.copyWith creates new instance with changes', () {
        final job = Job.fromJson(sampleJobJson);
        final updated = job.copyWith(
          status: 'completed',
          progress: 100,
        );

        expect(updated.jobId, job.jobId);
        expect(updated.status, 'completed');
        expect(updated.progress, 100);
      });

      test('Job.toMap returns same as toJson', () {
        final job = Job.fromJson(sampleJobJson);
        expect(job.toMap(), job.toJson());
      });
    });

    group('WorkerStatus Model', () {
      final sampleWorkerJson = {
        'worker_id': 'worker-1',
        'running': true,
        'ttl_remaining': 25,
      };

      test('WorkerStatus.fromJson creates instance correctly', () {
        final worker = WorkerStatus.fromJson(sampleWorkerJson);

        expect(worker.workerId, 'worker-1');
        expect(worker.running, true);
        expect(worker.ttlRemaining, 25);
      });

      test('WorkerStatus.toJson serializes correctly', () {
        final worker = WorkerStatus.fromJson(sampleWorkerJson);
        final json = worker.toJson();

        expect(json['worker_id'], 'worker-1');
        expect(json['running'], true);
        expect(json['ttl_remaining'], 25);
      });

      test('WorkerStatus.copyWith creates new instance', () {
        final worker = WorkerStatus.fromJson(sampleWorkerJson);
        final updated = worker.copyWith(running: false);

        expect(updated.workerId, worker.workerId);
        expect(updated.running, false);
      });
    });

    group('WorkersListResponse Model', () {
      final sampleListJson = {
        'workers': [
          {
            'worker_id': 'worker-1',
            'running': true,
            'ttl_remaining': 25,
          },
          {
            'worker_id': 'worker-2',
            'running': true,
            'ttl_remaining': 28,
          },
        ],
        'total': 2,
      };

      test('WorkersListResponse.fromJson creates instance correctly', () {
        final response = WorkersListResponse.fromJson(sampleListJson);

        expect(response.workers, hasLength(2));
        expect(response.workers[0].workerId, 'worker-1');
        expect(response.workers[1].workerId, 'worker-2');
        expect(response.total, 2);
      });

      test('WorkersListResponse.toJson serializes correctly', () {
        final response = WorkersListResponse.fromJson(sampleListJson);
        final json = response.toJson();

        expect(json['workers'], hasLength(2));
        expect(json['total'], 2);
      });

      test('WorkersListResponse.copyWith creates new instance', () {
        final response = WorkersListResponse.fromJson(sampleListJson);
        final updated = response.copyWith(
          workers: [],
          total: 0,
        );

        expect(updated.workers, isEmpty);
        expect(updated.total, 0);
      });
    });

    group('StorageSize Model', () {
      final sampleStorageJson = {
        'total_bytes': 1073741824,
        'total_mb': 1024.0,
        'job_count': 5,
      };

      test('StorageSize.fromJson creates instance correctly', () {
        final storage = StorageSize.fromJson(sampleStorageJson);

        expect(storage.totalBytes, 1073741824);
        expect(storage.totalMb, 1024.0);
        expect(storage.jobCount, 5);
      });

      test('StorageSize.toJson serializes correctly', () {
        final storage = StorageSize.fromJson(sampleStorageJson);
        final json = storage.toJson();

        expect(json['total_bytes'], 1073741824);
        expect(json['total_mb'], 1024.0);
        expect(json['job_count'], 5);
      });

      test('StorageSize.copyWith creates new instance', () {
        final storage = StorageSize.fromJson(sampleStorageJson);
        final updated = storage.copyWith(totalBytes: 2147483648);

        expect(updated.totalBytes, 2147483648);
        expect(updated.totalMb, storage.totalMb);
        expect(updated.jobCount, storage.jobCount);
      });
    });

    group('CleanupResponse Model', () {
      final sampleCleanupJson = {
        'message': 'All jobs older than 7 days deleted successfully',
        'deleted_count': 10,
      };

      test('CleanupResponse.fromJson creates instance correctly', () {
        final response = CleanupResponse.fromJson(sampleCleanupJson);

        expect(
          response.message,
          'All jobs older than 7 days deleted successfully',
        );
        expect(response.deletedCount, 10);
      });

      test('CleanupResponse.toJson serializes correctly', () {
        final response = CleanupResponse.fromJson(sampleCleanupJson);
        final json = response.toJson();

        expect(
          json['message'],
          'All jobs older than 7 days deleted successfully',
        );
        expect(json['deleted_count'], 10);
      });

      test('CleanupResponse.copyWith creates new instance', () {
        final response = CleanupResponse.fromJson(sampleCleanupJson);
        final updated = response.copyWith(deletedCount: 15);

        expect(updated.message, response.message);
        expect(updated.deletedCount, 15);
      });
    });
  });
}
