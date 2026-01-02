import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Response returned when job is created
class CreateJobResponse {
  CreateJobResponse({required this.jobId, required this.status});

  factory CreateJobResponse.fromJson(Map<String, dynamic> json) {
    return CreateJobResponse(
      jobId: json['job_id'] as String,
      status: json['status'] as String,
    );
  }
  final String jobId;
  final String status;
}

/// Worker capabilities structure: { "task_name": count }
typedef WorkerCapabilities = Map<String, int>;

/// Main Job Model - matches JobResponse in OpenAPI
@immutable
class Job {
  const Job({
    required this.jobId,
    required this.taskType,
    required this.params,
    required this.status,
    required this.createdAt,
    this.progress = 0,
    this.taskOutput,
    this.errorMessage,
    this.priority = 5,
    this.updatedAt,
    this.startedAt,
    this.completedAt,
  });

  factory Job.fromJson(String source) =>
      Job.fromMap(json.decode(source) as Map<String, dynamic>);

  factory Job.fromMap(Map<String, dynamic> json) {
    return Job(
      jobId: json['job_id'] as String,
      taskType: json['task_type'] as String,
      params: (json['params'] as Map<String, dynamic>? ?? {}).map(MapEntry.new),
      status: json['status'] as String? ?? 'queued',
      progress: (json['progress'] is int)
          ? json['progress'] as int
          : (json['progress'] as num?)?.toInt() ?? 0,
      taskOutput: (json['task_output'] is Map)
          ? Map<String, dynamic>.from(json['task_output'] as Map)
          : null,
      errorMessage: json['error_message'] as String?,
      priority: (json['priority'] is int)
          ? json['priority'] as int
          : (json['priority'] as num?)?.toInt() ?? 5,
      createdAt: (json['created_at'] as num).toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
      startedAt: (json['started_at'] as num?)?.toInt(),
      completedAt: (json['completed_at'] as num?)?.toInt(),
    );
  }
  final String jobId;
  final String taskType;
  final Map<String, dynamic> params;
  final String status;
  final int progress;
  final Map<String, dynamic>? taskOutput;
  final String? errorMessage;
  final int priority;
  final int createdAt;
  final int? updatedAt;
  final int? startedAt;
  final int? completedAt;

  Job copyWith({
    String? jobId,
    String? taskType,
    Map<String, dynamic>? params,
    String? status,
    int? progress,
    Map<String, dynamic>? taskOutput,
    String? errorMessage,
    int? priority,
    int? createdAt,
    int? updatedAt,
    int? startedAt,
    int? completedAt,
  }) {
    return Job(
      jobId: jobId ?? this.jobId,
      taskType: taskType ?? this.taskType,
      params: params ?? this.params,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      taskOutput: taskOutput ?? this.taskOutput,
      errorMessage: errorMessage ?? this.errorMessage,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Optional: useful for logging and debug
  Map<String, dynamic> toMap() {
    return {
      'job_id': jobId,
      'task_type': taskType,
      'params': params,
      'status': status,
      'progress': progress,
      'task_output': taskOutput,
      'error_message': errorMessage,
      'priority': priority,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'started_at': startedAt,
      'completed_at': completedAt,
    };
  }

  bool get isFinished => status == 'completed' || status == 'failed';

  @override
  String toString() {
    return 'Job(jobId: $jobId, taskType: $taskType, params: $params, '
        'status: $status, progress: $progress, taskOutput: $taskOutput, '
        'errorMessage: $errorMessage, priority: $priority, '
        'createdAt: $createdAt, updatedAt: $updatedAt, '
        'startedAt: $startedAt, completedAt: $completedAt)';
  }

  @override
  bool operator ==(covariant Job other) {
    if (identical(this, other)) return true;
    final mapEquals = const DeepCollectionEquality().equals;

    return other.jobId == jobId &&
        other.taskType == taskType &&
        mapEquals(other.params, params) &&
        other.status == status &&
        other.progress == progress &&
        mapEquals(other.taskOutput, taskOutput) &&
        other.errorMessage == errorMessage &&
        other.priority == priority &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.startedAt == startedAt &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode {
    return jobId.hashCode ^
        taskType.hashCode ^
        params.hashCode ^
        status.hashCode ^
        progress.hashCode ^
        taskOutput.hashCode ^
        errorMessage.hashCode ^
        priority.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        startedAt.hashCode ^
        completedAt.hashCode;
  }

  String toJson() => json.encode(toMap());
}

/// Lightweight job status from MQTT updates
///
/// Only tracks status, progress, and timestamp. Does NOT contain output/error.
/// Clients must call ComputeService.getJob() to fetch full Job with results.
///
/// MQTT Message → JobStatus Mapping:
/// - event_type → status
/// - job_id → jobId
/// - data.progress → progress
/// - timestamp → timestamp
@immutable
class JobStatus {
  const JobStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.timestamp,
  });

  /// Create JobStatus from MQTT message payload
  factory JobStatus.fromMqttMessage(Map<String, dynamic> json) {
    return JobStatus(
      jobId: json['job_id'] as String,
      status: json['event_type'] as String, // MQTT event_type → status
      progress: (json['data']?['progress'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] as int,
    );
  }

  factory JobStatus.fromMap(Map<String, dynamic> json) {
    return JobStatus.fromMqttMessage(json);
  }

  factory JobStatus.fromJson(String source) =>
      JobStatus.fromMap(json.decode(source) as Map<String, dynamic>);

  final String jobId;
  final String status; // 'queued', 'processing', 'completed', 'failed'
  final int progress; // 0-100
  final int timestamp; // Unix timestamp (milliseconds)

  /// Check if job is finished (completed or failed)
  bool get isFinished => status == 'completed' || status == 'failed';

  JobStatus copyWith({
    String? jobId,
    String? status,
    int? progress,
    int? timestamp,
  }) {
    return JobStatus(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'job_id': jobId,
      'status': status,
      'progress': progress,
      'timestamp': timestamp,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'JobStatus(jobId: $jobId, status: $status, '
        'progress: $progress, timestamp: $timestamp)';
  }

  @override
  bool operator ==(covariant JobStatus other) {
    if (identical(this, other)) return true;

    return other.jobId == jobId &&
        other.status == status &&
        other.progress == progress &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return jobId.hashCode ^
        status.hashCode ^
        progress.hashCode ^
        timestamp.hashCode;
  }
}

class StorageInfo {
  StorageInfo({required this.totalSize, required this.jobCount});

  factory StorageInfo.fromJson(Map<String, dynamic> json) {
    return StorageInfo(
      totalSize: json['total_size'] as int,
      jobCount: json['job_count'] as int,
    );
  }
  final int totalSize;
  final int jobCount;
}

class CleanupResult {
  CleanupResult({required this.deletedCount, required this.freedSpace});

  factory CleanupResult.fromJson(Map<String, dynamic> json) {
    return CleanupResult(
      deletedCount: json['deleted_count'] as int,
      freedSpace: json['freed_space'] as int,
    );
  }
  final int deletedCount;
  final int freedSpace;
}

/// Worker status model
@immutable
class WorkerStatus {
  const WorkerStatus({
    required this.workerId,
    required this.running,
    this.ttlRemaining,
  });

  factory WorkerStatus.fromJson(Map<String, dynamic> json) {
    return WorkerStatus(
      workerId: json['worker_id'] as String,
      running: json['running'] as bool? ?? false,
      ttlRemaining: json['ttl_remaining'] as int?,
    );
  }

  factory WorkerStatus.fromMap(Map<String, dynamic> map) {
    return WorkerStatus.fromJson(map);
  }
  final String workerId;
  final bool running;
  final int? ttlRemaining;

  Map<String, dynamic> toJson() {
    return {
      'worker_id': workerId,
      'running': running,
      'ttl_remaining': ttlRemaining,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  WorkerStatus copyWith({String? workerId, bool? running, int? ttlRemaining}) {
    return WorkerStatus(
      workerId: workerId ?? this.workerId,
      running: running ?? this.running,
      ttlRemaining: ttlRemaining ?? this.ttlRemaining,
    );
  }
}

/// Workers list response model
@immutable
class WorkersListResponse {
  const WorkersListResponse({required this.workers, required this.total});

  factory WorkersListResponse.fromJson(Map<String, dynamic> json) {
    return WorkersListResponse(
      workers: (json['workers'] as List<dynamic>? ?? [])
          .map((e) => WorkerStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
    );
  }

  factory WorkersListResponse.fromMap(Map<String, dynamic> map) {
    return WorkersListResponse.fromJson(map);
  }
  final List<WorkerStatus> workers;
  final int total;

  Map<String, dynamic> toJson() {
    return {'workers': workers.map((e) => e.toJson()).toList(), 'total': total};
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  WorkersListResponse copyWith({List<WorkerStatus>? workers, int? total}) {
    return WorkersListResponse(
      workers: workers ?? this.workers,
      total: total ?? this.total,
    );
  }
}

/// Storage size model
@immutable
class StorageSize {
  const StorageSize({
    required this.totalBytes,
    required this.totalMb,
    required this.jobCount,
  });

  factory StorageSize.fromJson(Map<String, dynamic> json) {
    return StorageSize(
      totalBytes: json['total_bytes'] as int? ?? 0,
      totalMb: json['total_mb'] as double? ?? 0.0,
      jobCount: json['job_count'] as int? ?? 0,
    );
  }

  factory StorageSize.fromMap(Map<String, dynamic> map) {
    return StorageSize.fromJson(map);
  }
  final int totalBytes;
  final double totalMb;
  final int jobCount;

  Map<String, dynamic> toJson() {
    return {
      'total_bytes': totalBytes,
      'total_mb': totalMb,
      'job_count': jobCount,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  StorageSize copyWith({int? totalBytes, double? totalMb, int? jobCount}) {
    return StorageSize(
      totalBytes: totalBytes ?? this.totalBytes,
      totalMb: totalMb ?? this.totalMb,
      jobCount: jobCount ?? this.jobCount,
    );
  }
}

/// Cleanup response model
@immutable
class CleanupResponse {
  const CleanupResponse({required this.message, required this.deletedCount});

  factory CleanupResponse.fromJson(Map<String, dynamic> json) {
    return CleanupResponse(
      message: json['message'] as String? ?? '',
      deletedCount: json['deleted_count'] as int? ?? 0,
    );
  }

  factory CleanupResponse.fromMap(Map<String, dynamic> map) {
    return CleanupResponse.fromJson(map);
  }
  final String message;
  final int deletedCount;

  Map<String, dynamic> toJson() {
    return {'message': message, 'deleted_count': deletedCount};
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  CleanupResponse copyWith({String? message, int? deletedCount}) {
    return CleanupResponse(
      message: message ?? this.message,
      deletedCount: deletedCount ?? this.deletedCount,
    );
  }
}
