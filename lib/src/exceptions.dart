import 'models/models.dart';

/// Base exception for compute client errors.
class ComputeClientError implements Exception {
  ComputeClientError(this.message);
  final String message;

  @override
  String toString() => 'ComputeClientError: $message';
}

/// Job not found (404).
class JobNotFoundError extends ComputeClientError {
  JobNotFoundError(this.jobId) : super('Job not found: $jobId');
  final String jobId;

  @override
  String toString() => 'JobNotFoundError: $message';
}

/// Job failed during execution.
class JobFailedError extends ComputeClientError {
  JobFailedError(this.job)
    : super('Job ${job.jobId} failed: ${job.errorMessage}');
  final JobResponse job;

  @override
  String toString() => 'JobFailedError: $message';
}

/// Authentication failed (401).
class AuthenticationError extends ComputeClientError {
  AuthenticationError([super.message = 'Authentication failed']);

  @override
  String toString() => 'AuthenticationError: $message';
}

/// Insufficient permissions (403).
class PermissionError extends ComputeClientError {
  PermissionError([super.message = 'Insufficient permissions']);

  @override
  String toString() => 'PermissionError: $message';
}

/// No workers available for task type.
class WorkerUnavailableError extends ComputeClientError {
  WorkerUnavailableError(this.taskType, this.availableCapabilities)
    : super(
        'No workers available for task type: $taskType\nAvailable capabilities: $availableCapabilities',
      );
  final String taskType;
  final Map<String, int> availableCapabilities;

  @override
  String toString() => 'WorkerUnavailableError: $message';
}

/// Thrown when validation fails (400 Bad Request).
class ValidationError extends ComputeClientError {
  ValidationError(super.message);

  @override
  String toString() => 'ValidationError: $message';
}

/// Thrown when resource is not found (404 Not Found).
class NotFoundError extends ComputeClientError {
  NotFoundError(super.message);

  @override
  String toString() => 'NotFoundError: $message';
}

/// HTTP error from server (matches Python's httpx.HTTPStatusError).
class HttpStatusError extends ComputeClientError {
  HttpStatusError(this.statusCode, String message, {this.responseBody})
    : super(message);

  final int statusCode;
  final String? responseBody;

  @override
  String toString() => 'HttpStatusError($statusCode): $message';
}
