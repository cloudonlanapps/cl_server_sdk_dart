import 'package:cl_server_dart_client/src/exceptions.dart';
import 'package:cl_server_dart_client/src/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('Exceptions', () {
    test('test_compute_client_error', () {
      final error = ComputeClientError('Test error');
      expect(error.toString(), contains('Test error'));
      expect(error, isA<Exception>());
    });

    test('test_job_not_found_error', () {
      final error = JobNotFoundError('test-123');
      expect(error.toString(), contains('test-123'));
      expect(error.jobId, equals('test-123'));
      expect(error, isA<ComputeClientError>());
    });

    test('test_job_failed_error', () {
      final job = JobResponse(
        jobId: 'test-123',
        taskType: 'clip_embedding',
        status: 'failed',
        progress: 50,
        createdAt: 1234567890,
        errorMessage: 'Something went wrong',
      );

      final error = JobFailedError(job);
      expect(error.toString(), contains('test-123'));
      expect(error.toString(), contains('Something went wrong'));
      expect(error.job, equals(job));
      expect(error, isA<ComputeClientError>());
    });

    test('test_authentication_error', () {
      final error = AuthenticationError('Unauthorized');
      expect(error, isA<ComputeClientError>());
      expect(error.message, equals('Unauthorized'));
    });

    test('test_permission_error', () {
      final error = PermissionError('Forbidden');
      expect(error, isA<ComputeClientError>());
      expect(error.message, equals('Forbidden'));
    });

    test('test_worker_unavailable_error', () {
      final error = WorkerUnavailableError('clip_embedding', {
        'dino_embedding': 1,
        'exif': 1,
      });

      expect(error.toString(), contains('clip_embedding'));
      expect(error.taskType, equals('clip_embedding'));
      expect(
        error.availableCapabilities,
        equals({'dino_embedding': 1, 'exif': 1}),
      );
      expect(error, isA<ComputeClientError>());
    });
  });
}
