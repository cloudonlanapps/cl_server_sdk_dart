import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('Compute Models Tests', () {
    group('CreateJobResponse Model', () {
      final sampleJson = {
        'job_id': 'test-job-123',
        'status': 'queued',
      };

      test('CreateJobResponse.fromJson creates instance correctly', () {
        final response = CreateJobResponse.fromJson(sampleJson);

        expect(response.jobId, 'test-job-123');
        expect(response.status, 'queued');
      });

      test('CreateJobResponse.fromJson with different status values', () {
        final statuses = ['queued', 'running', 'completed', 'failed'];

        for (final status in statuses) {
          final json = {'job_id': 'job-$status', 'status': status};
          final response = CreateJobResponse.fromJson(json);

          expect(response.jobId, 'job-$status');
          expect(response.status, status);
        }
      });
    });

    group('Job Model', () {
      final sampleJobJson = {
        'job_id': 'test-job-123',
        'task_type': 'image_resize',
        'params': {'width': 800, 'height': 600},
        'status': 'queued',
        'progress': 0,
        'task_output': null,
        'error_message': null,
        'priority': 5,
        'created_at': 1704067200000,
        'updated_at': null,
        'started_at': null,
        'completed_at': null,
      };

      final completedJobJson = {
        'job_id': 'test-job-456',
        'task_type': 'image_resize',
        'params': {'width': 800, 'height': 600},
        'status': 'completed',
        'progress': 100,
        'task_output': {
          'output_file': '/path/to/output.jpg',
          'width': 800,
          'height': 600,
        },
        'error_message': null,
        'priority': 5,
        'created_at': 1704067200000,
        'updated_at': 1704067500000,
        'started_at': 1704067300000,
        'completed_at': 1704067500000,
      };

      test('Job.fromMap creates instance correctly with all fields', () {
        final job = Job.fromMap(completedJobJson);

        expect(job.jobId, 'test-job-456');
        expect(job.taskType, 'image_resize');
        expect(job.params['width'], 800);
        expect(job.params['height'], 600);
        expect(job.status, 'completed');
        expect(job.progress, 100);
        expect(job.taskOutput, isNotNull);
        expect(job.taskOutput!['output_file'], '/path/to/output.jpg');
        expect(job.errorMessage, null);
        expect(job.priority, 5);
        expect(job.createdAt, 1704067200000);
        expect(job.updatedAt, 1704067500000);
        expect(job.startedAt, 1704067300000);
        expect(job.completedAt, 1704067500000);
      });

      test('Job.fromMap creates instance with minimal required fields', () {
        final job = Job.fromMap(sampleJobJson);

        expect(job.jobId, 'test-job-123');
        expect(job.taskType, 'image_resize');
        expect(job.status, 'queued');
        expect(job.progress, 0);
        expect(job.priority, 5);
        expect(job.createdAt, 1704067200000);
        expect(job.taskOutput, null);
        expect(job.errorMessage, null);
        expect(job.updatedAt, null);
        expect(job.startedAt, null);
        expect(job.completedAt, null);
      });

      test('Job.fromMap handles numeric type coercion for progress', () {
        final json = {
          ...sampleJobJson,
          'progress': 50, // int
        };
        final job1 = Job.fromMap(json);
        expect(job1.progress, 50);

        final json2 = {
          ...sampleJobJson,
          'progress': 75.0, // double (num)
        };
        final job2 = Job.fromMap(json2);
        expect(job2.progress, 75);
      });

      test('Job.fromMap handles numeric type coercion for priority', () {
        final json = {
          ...sampleJobJson,
          'priority': 8, // int
        };
        final job1 = Job.fromMap(json);
        expect(job1.priority, 8);

        final json2 = {
          ...sampleJobJson,
          'priority': 3.0, // double (num)
        };
        final job2 = Job.fromMap(json2);
        expect(job2.priority, 3);
      });

      test('Job.fromMap defaults status to queued if missing', () {
        final json = Map<String, dynamic>.from(sampleJobJson);
        json.remove('status');

        final job = Job.fromMap(json);
        expect(job.status, 'queued');
      });

      test('Job.fromMap defaults progress to 0 if missing', () {
        final json = Map<String, dynamic>.from(sampleJobJson);
        json.remove('progress');

        final job = Job.fromMap(json);
        expect(job.progress, 0);
      });

      test('Job.fromMap defaults priority to 5 if missing', () {
        final json = Map<String, dynamic>.from(sampleJobJson);
        json.remove('priority');

        final job = Job.fromMap(json);
        expect(job.priority, 5);
      });

      test('Job.fromMap handles empty params map', () {
        final json = {
          ...sampleJobJson,
          'params': <String, dynamic>{},
        };

        final job = Job.fromMap(json);
        expect(job.params, isEmpty);
      });

      test('Job.fromMap handles deeply nested taskOutput', () {
        final json = {
          ...completedJobJson,
          'task_output': {
            'output_file': '/path/to/output.jpg',
            'metadata': {
              'width': 800,
              'height': 600,
              'format': 'jpeg',
              'processing': {'duration_ms': 1234, 'worker_id': 'worker-1'},
            },
          },
        };

        final job = Job.fromMap(json);
        expect(job.taskOutput, isNotNull);
        expect(job.taskOutput!['metadata']['processing']['duration_ms'], 1234);
      });

      test('Job.toMap serializes correctly', () {
        final job = Job.fromMap(completedJobJson);
        final map = job.toMap();

        expect(map['job_id'], 'test-job-456');
        expect(map['task_type'], 'image_resize');
        expect(map['status'], 'completed');
        expect(map['progress'], 100);
        expect(map['priority'], 5);
        expect(map['created_at'], 1704067200000);
      });

      test('Job.copyWith creates new instance with changes', () {
        final job = Job.fromMap(sampleJobJson);
        final updated = job.copyWith(
          status: 'running',
          progress: 50,
        );

        expect(updated.jobId, job.jobId);
        expect(updated.taskType, job.taskType);
        expect(updated.status, 'running');
        expect(updated.progress, 50);
        expect(updated.priority, job.priority);
      });

      test('Job.copyWith preserves unchanged fields', () {
        final job = Job.fromMap(completedJobJson);
        final updated = job.copyWith(progress: 75);

        expect(updated.jobId, job.jobId);
        expect(updated.taskType, job.taskType);
        expect(updated.status, job.status);
        expect(updated.progress, 75);
        expect(updated.taskOutput, job.taskOutput);
        expect(updated.createdAt, job.createdAt);
      });

      test('Job.isFinished returns true for completed status', () {
        final json = {...sampleJobJson, 'status': 'completed'};
        final job = Job.fromMap(json);

        expect(job.isFinished, isTrue);
      });

      test('Job.isFinished returns true for failed status', () {
        final json = {...sampleJobJson, 'status': 'failed'};
        final job = Job.fromMap(json);

        expect(job.isFinished, isTrue);
      });

      test('Job.isFinished returns false for queued status', () {
        final job = Job.fromMap(sampleJobJson);
        expect(job.isFinished, isFalse);
      });

      test('Job.isFinished returns false for running status', () {
        final json = {...sampleJobJson, 'status': 'running'};
        final job = Job.fromMap(json);

        expect(job.isFinished, isFalse);
      });

      test('Job.isFinished returns false for processing status', () {
        final json = {...sampleJobJson, 'status': 'processing'};
        final job = Job.fromMap(json);

        expect(job.isFinished, isFalse);
      });
    });

    group('WorkerCapabilities Type', () {
      test('WorkerCapabilities is Map<String, int>', () {
        final caps = <String, int>{
          'image_resize': 2,
          'image_conversion': 1,
        };

        // Type check
        expect(caps, isA<Map<String, int>>());
        expect(caps['image_resize'], 2);
        expect(caps['image_conversion'], 1);
      });

      test('WorkerCapabilities with empty map', () {
        final caps = <String, int>{};

        expect(caps, isEmpty);
        expect(caps.containsKey('any_task'), isFalse);
      });

      test('WorkerCapabilities with multiple task types', () {
        final caps = <String, int>{
          'image_resize': 3,
          'image_conversion': 2,
          'video_transcode': 1,
          'audio_process': 4,
        };

        expect(caps.length, 4);
        expect(caps.keys, contains('video_transcode'));
        expect(caps['audio_process'], 4);
      });
    });

    group('StorageInfo Model', () {
      final sampleJson = {
        'total_size': 10485760,
        'job_count': 42,
      };

      test('StorageInfo.fromJson creates instance correctly', () {
        final info = StorageInfo.fromJson(sampleJson);

        expect(info.totalSize, 10485760);
        expect(info.jobCount, 42);
      });

      test('StorageInfo.fromJson with zero values', () {
        final json = {
          'total_size': 0,
          'job_count': 0,
        };

        final info = StorageInfo.fromJson(json);

        expect(info.totalSize, 0);
        expect(info.jobCount, 0);
      });

      test('StorageInfo.fromJson with large values', () {
        final json = {
          'total_size': 999999999999,
          'job_count': 1000000,
        };

        final info = StorageInfo.fromJson(json);

        expect(info.totalSize, 999999999999);
        expect(info.jobCount, 1000000);
      });
    });

    group('CleanupResult Model', () {
      final sampleJson = {
        'deleted_count': 25,
        'freed_space': 52428800,
      };

      test('CleanupResult.fromJson creates instance correctly', () {
        final result = CleanupResult.fromJson(sampleJson);

        expect(result.deletedCount, 25);
        expect(result.freedSpace, 52428800);
      });

      test('CleanupResult.fromJson with zero deleted count', () {
        final json = {
          'deleted_count': 0,
          'freed_space': 0,
        };

        final result = CleanupResult.fromJson(json);

        expect(result.deletedCount, 0);
        expect(result.freedSpace, 0);
      });

      test('CleanupResult.fromJson with large freed space', () {
        final json = {
          'deleted_count': 1000,
          'freed_space': 10737418240, // 10GB
        };

        final result = CleanupResult.fromJson(json);

        expect(result.deletedCount, 1000);
        expect(result.freedSpace, 10737418240);
      });
    });

    group('WorkerStatus Model', () {
      final sampleJson = {
        'worker_id': 'worker-1',
        'running': true,
        'ttl_remaining': 3600,
      };

      test('WorkerStatus.fromJson creates instance correctly', () {
        final status = WorkerStatus.fromJson(sampleJson);

        expect(status.workerId, 'worker-1');
        expect(status.running, true);
        expect(status.ttlRemaining, 3600);
      });

      test('WorkerStatus.fromMap creates instance correctly', () {
        final status = WorkerStatus.fromMap(sampleJson);

        expect(status.workerId, 'worker-1');
        expect(status.running, true);
        expect(status.ttlRemaining, 3600);
      });

      test('WorkerStatus.toJson serializes correctly', () {
        final status = WorkerStatus.fromJson(sampleJson);
        final json = status.toJson();

        expect(json['worker_id'], 'worker-1');
        expect(json['running'], true);
        expect(json['ttl_remaining'], 3600);
      });

      test('WorkerStatus.toMap returns same as toJson', () {
        final status = WorkerStatus.fromJson(sampleJson);

        expect(status.toMap(), status.toJson());
      });

      test('WorkerStatus.copyWith creates new instance with changes', () {
        final status = WorkerStatus.fromJson(sampleJson);
        final updated = status.copyWith(running: false);

        expect(updated.workerId, status.workerId);
        expect(updated.running, false);
        expect(updated.ttlRemaining, status.ttlRemaining);
      });

      test('WorkerStatus with null ttlRemaining', () {
        final json = {
          'worker_id': 'worker-2',
          'running': false,
          'ttl_remaining': null,
        };

        final status = WorkerStatus.fromJson(json);

        expect(status.workerId, 'worker-2');
        expect(status.running, false);
        expect(status.ttlRemaining, null);
      });

      test('WorkerStatus defaults running to false if missing', () {
        final json = {
          'worker_id': 'worker-3',
        };

        final status = WorkerStatus.fromJson(json);

        expect(status.running, false);
      });
    });

    group('WorkersListResponse Model', () {
      final sampleJson = {
        'workers': [
          {
            'worker_id': 'worker-1',
            'running': true,
            'ttl_remaining': 3600,
          },
          {
            'worker_id': 'worker-2',
            'running': false,
            'ttl_remaining': null,
          },
        ],
        'total': 2,
      };

      test('WorkersListResponse.fromJson creates instance correctly', () {
        final response = WorkersListResponse.fromJson(sampleJson);

        expect(response.workers, hasLength(2));
        expect(response.total, 2);
        expect(response.workers[0].workerId, 'worker-1');
        expect(response.workers[1].workerId, 'worker-2');
      });

      test('WorkersListResponse.fromMap creates instance correctly', () {
        final response = WorkersListResponse.fromMap(sampleJson);

        expect(response.workers, hasLength(2));
        expect(response.total, 2);
      });

      test('WorkersListResponse.fromJson with empty workers list', () {
        final json = {
          'workers': <dynamic>[],
          'total': 0,
        };

        final response = WorkersListResponse.fromJson(json);

        expect(response.workers, isEmpty);
        expect(response.total, 0);
      });

      test('WorkersListResponse.toJson serializes correctly', () {
        final response = WorkersListResponse.fromJson(sampleJson);
        final json = response.toJson();

        expect(json['workers'], hasLength(2));
        expect(json['total'], 2);
        expect(json['workers'][0]['worker_id'], 'worker-1');
      });

      test('WorkersListResponse.toMap returns same as toJson', () {
        final response = WorkersListResponse.fromJson(sampleJson);

        expect(response.toMap(), response.toJson());
      });

      test('WorkersListResponse.copyWith creates new instance', () {
        final response = WorkersListResponse.fromJson(sampleJson);
        final updated = response.copyWith(total: 5);

        expect(updated.workers, response.workers);
        expect(updated.total, 5);
      });

      test('WorkersListResponse defaults to empty list and zero total', () {
        final json = <String, dynamic>{};

        final response = WorkersListResponse.fromJson(json);

        expect(response.workers, isEmpty);
        expect(response.total, 0);
      });
    });

    group('StorageSize Model', () {
      final sampleJson = {
        'total_bytes': 10485760,
        'total_mb': 10.0,
        'job_count': 50,
      };

      test('StorageSize.fromJson creates instance correctly', () {
        final size = StorageSize.fromJson(sampleJson);

        expect(size.totalBytes, 10485760);
        expect(size.totalMb, 10.0);
        expect(size.jobCount, 50);
      });

      test('StorageSize.fromMap creates instance correctly', () {
        final size = StorageSize.fromMap(sampleJson);

        expect(size.totalBytes, 10485760);
        expect(size.totalMb, 10.0);
        expect(size.jobCount, 50);
      });

      test('StorageSize.toJson serializes correctly', () {
        final size = StorageSize.fromJson(sampleJson);
        final json = size.toJson();

        expect(json['total_bytes'], 10485760);
        expect(json['total_mb'], 10.0);
        expect(json['job_count'], 50);
      });

      test('StorageSize.toMap returns same as toJson', () {
        final size = StorageSize.fromJson(sampleJson);

        expect(size.toMap(), size.toJson());
      });

      test('StorageSize.copyWith creates new instance with changes', () {
        final size = StorageSize.fromJson(sampleJson);
        final updated = size.copyWith(jobCount: 100);

        expect(updated.totalBytes, size.totalBytes);
        expect(updated.totalMb, size.totalMb);
        expect(updated.jobCount, 100);
      });

      test('StorageSize with zero values', () {
        final json = {
          'total_bytes': 0,
          'total_mb': 0.0,
          'job_count': 0,
        };

        final size = StorageSize.fromJson(json);

        expect(size.totalBytes, 0);
        expect(size.totalMb, 0.0);
        expect(size.jobCount, 0);
      });

      test('StorageSize with precise double for totalMb', () {
        final json = {
          'total_bytes': 10737418240,
          'total_mb': 10240.0,
          'job_count': 100,
        };

        final size = StorageSize.fromJson(json);

        expect(size.totalMb, 10240.0);
      });

      test('StorageSize defaults to zero if fields missing', () {
        final json = <String, dynamic>{};

        final size = StorageSize.fromJson(json);

        expect(size.totalBytes, 0);
        expect(size.totalMb, 0.0);
        expect(size.jobCount, 0);
      });
    });

    group('CleanupResponse Model', () {
      final sampleJson = {
        'message': 'Successfully cleaned up 10 jobs',
        'deleted_count': 10,
      };

      test('CleanupResponse.fromJson creates instance correctly', () {
        final response = CleanupResponse.fromJson(sampleJson);

        expect(response.message, 'Successfully cleaned up 10 jobs');
        expect(response.deletedCount, 10);
      });

      test('CleanupResponse.fromMap creates instance correctly', () {
        final response = CleanupResponse.fromMap(sampleJson);

        expect(response.message, 'Successfully cleaned up 10 jobs');
        expect(response.deletedCount, 10);
      });

      test('CleanupResponse.toJson serializes correctly', () {
        final response = CleanupResponse.fromJson(sampleJson);
        final json = response.toJson();

        expect(json['message'], 'Successfully cleaned up 10 jobs');
        expect(json['deleted_count'], 10);
      });

      test('CleanupResponse.toMap returns same as toJson', () {
        final response = CleanupResponse.fromJson(sampleJson);

        expect(response.toMap(), response.toJson());
      });

      test('CleanupResponse.copyWith creates new instance with changes', () {
        final response = CleanupResponse.fromJson(sampleJson);
        final updated = response.copyWith(deletedCount: 20);

        expect(updated.message, response.message);
        expect(updated.deletedCount, 20);
      });

      test('CleanupResponse defaults to empty string and zero', () {
        final json = <String, dynamic>{};

        final response = CleanupResponse.fromJson(json);

        expect(response.message, '');
        expect(response.deletedCount, 0);
      });
    });
  });
}
