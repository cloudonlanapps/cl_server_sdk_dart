import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('test_models', () {
    test('test_job_response_basic', () {
      final job = JobResponse(
        jobId: 'test-123',
        taskType: 'clip_embedding',
        status: 'completed',
        progress: 100,
        createdAt: 1234567890,
      );

      expect(job.jobId, equals('test-123'));
      expect(job.taskType, equals('clip_embedding'));
      expect(job.status, equals('completed'));
      expect(job.progress, equals(100));
      expect(job.params, equals({}));
      expect(job.taskOutput, isNull);
    });

    test('test_job_response_with_output', () {
      final job = JobResponse(
        jobId: 'test-123',
        taskType: 'clip_embedding',
        status: 'completed',
        progress: 100,
        createdAt: 1234567890,
        taskOutput: {
          'embedding': [0.1, 0.2, 0.3],
        },
      );

      expect(job.taskOutput, isNotNull);
      expect(job.taskOutput, contains('embedding'));
      expect(job.taskOutput!['embedding'], isA<List<dynamic>>());
    });

    test('test_worker_capabilities_response', () {
      final caps = WorkerCapabilitiesResponse(
        numWorkers: 2,
        capabilities: {'clip_embedding': 1, 'dino_embedding': 1},
      );

      expect(caps.numWorkers, equals(2));
      expect(caps.capabilities['clip_embedding'], equals(1));
      expect(caps.capabilities['dino_embedding'], equals(1));
    });

    test('test_worker_capability', () {
      final worker = WorkerCapability(
        workerId: 'worker-1',
        capabilities: ['clip_embedding', 'dino_embedding'],
        idleCount: 1,
        timestamp: 1234567890,
      );

      expect(worker.workerId, equals('worker-1'));
      expect(worker.capabilities.length, equals(2));
      expect(worker.capabilities, contains('clip_embedding'));
      expect(worker.idleCount, equals(1));
    });
  });
}
