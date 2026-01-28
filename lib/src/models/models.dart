import 'dart:convert';

/// Response schema for job information (mirrors server schema).
class JobResponse {
  JobResponse({
    required this.jobId,
    required this.taskType,
    required this.status,
    required this.createdAt,
    this.progress = 0,
    this.params = const {},
    this.taskOutput,
    this.errorMessage,
    this.priority = 5,
    this.updatedAt,
    this.startedAt,
    this.completedAt,
  });

  factory JobResponse.fromMap(Map<String, dynamic> map) {
    return JobResponse(
      jobId: map['job_id'] as String,
      taskType: map['task_type'] as String,
      status: map['status'] as String,
      progress: map['progress'] as int? ?? 0,
      params: map['params'] as Map<String, dynamic>? ?? const {},
      taskOutput: map['task_output'] as Map<String, dynamic>?,
      errorMessage: map['error_message'] as String?,
      priority: map['priority'] as int? ?? 5,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int?,
      startedAt: map['started_at'] as int?,
      completedAt: map['completed_at'] as int?,
    );
  }

  factory JobResponse.fromJson(String source) =>
      JobResponse.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Unique job identifier
  final String jobId;

  /// Type of task to execute
  final String taskType;

  /// Job status (queued, in_progress, completed, failed)
  final String status;

  /// Progress percentage (0-100)
  final int progress;

  /// Task parameters
  final Map<String, dynamic> params;

  /// Task output/results
  final Map<String, dynamic>? taskOutput;

  /// Error message if job failed
  final String? errorMessage;

  /// Job priority (0-10)
  final int priority;

  /// Job creation timestamp (milliseconds)
  final int createdAt;

  /// Job last update timestamp (milliseconds)
  final int? updatedAt;

  /// Job start timestamp (milliseconds)
  final int? startedAt;

  /// Job completion timestamp (milliseconds)
  final int? completedAt;

  Map<String, dynamic> toMap() {
    return {
      'job_id': jobId,
      'task_type': taskType,
      'status': status,
      'progress': progress,
      'params': params,
      'task_output': taskOutput,
      'error_message': errorMessage,
      'priority': priority,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'started_at': startedAt,
      'completed_at': completedAt,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Response schema for worker capabilities endpoint (mirrors server schema).
class WorkerCapabilitiesResponse {
  WorkerCapabilitiesResponse({
    required this.numWorkers,
    required this.capabilities,
  });

  factory WorkerCapabilitiesResponse.fromMap(Map<String, dynamic> map) {
    return WorkerCapabilitiesResponse(
      numWorkers: map['num_workers'] as int,
      capabilities: Map<String, int>.from(map['capabilities'] as Map),
    );
  }

  factory WorkerCapabilitiesResponse.fromJson(String source) =>
      WorkerCapabilitiesResponse.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  /// Total number of connected workers
  final int numWorkers;

  /// Available capability counts
  final Map<String, int> capabilities;

  Map<String, dynamic> toMap() {
    return {
      'num_workers': numWorkers,
      'capabilities': capabilities,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Individual worker capability information.
class WorkerCapability {
  WorkerCapability({
    required this.workerId,
    required this.capabilities,
    required this.idleCount,
    required this.timestamp,
  });

  factory WorkerCapability.fromMap(Map<String, dynamic> map) {
    return WorkerCapability(
      workerId: map['worker_id'] as String,
      capabilities: List<String>.from(map['capabilities'] as List),
      idleCount: map['idle_count'] as int,
      timestamp: map['timestamp'] as int,
    );
  }

  factory WorkerCapability.fromJson(String source) =>
      WorkerCapability.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Worker unique ID
  final String workerId;

  /// List of task types worker supports
  final List<String> capabilities;

  /// 1 if idle, 0 if busy
  final int idleCount;

  /// Message timestamp (milliseconds)
  final int timestamp;

  Map<String, dynamic> toMap() {
    return {
      'worker_id': workerId,
      'capabilities': capabilities,
      'idle_count': idleCount,
      'timestamp': timestamp,
    };
  }

  String toJson() => json.encode(toMap());
}
