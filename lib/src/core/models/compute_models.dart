import 'package:meta/meta.dart';

/// Job model for Compute service
@immutable
class Job {
  const Job({
    required this.jobId,
    required this.taskType,
    required this.status,
    required this.progress,
    required this.inputFiles,
    required this.outputFiles,
    required this.taskOutput,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final taskOutputData = json['task_output'];
    final Map<String, dynamic> taskOutput;
    if (taskOutputData is Map) {
      taskOutput = Map<String, dynamic>.from(taskOutputData);
    } else {
      taskOutput = {};
    }

    return Job(
      jobId: json['job_id'] as String,
      taskType: json['task_type'] as String,
      status: json['status'] as String,
      progress: json['progress'] as int? ?? 0,
      inputFiles: json['input_files'] as List<dynamic>,
      outputFiles: List<String>.from(
        (json['output_files'] as List<dynamic>? ?? []).cast<String>(),
      ),
      taskOutput: taskOutput,
      createdAt: _parseDateTime(json['created_at']),
      startedAt: json['started_at'] != null
          ? _parseDateTime(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? _parseDateTime(json['completed_at'])
          : null,
    );
  }

  factory Job.fromMap(Map<String, dynamic> map) {
    return Job.fromJson(map);
  }
  final String jobId;
  final String taskType;
  final String status;
  final int progress;
  // FIXME: InputFile require its own class
  final List<dynamic> inputFiles;
  final List<String> outputFiles;
  final Map<String, dynamic> taskOutput;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'task_type': taskType,
      'status': status,
      'progress': progress,
      'input_files': inputFiles,
      'output_files': outputFiles,
      'task_output': taskOutput,
      'created_at': createdAt.millisecondsSinceEpoch,
      'started_at': startedAt?.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  Job copyWith({
    String? jobId,
    String? taskType,
    String? status,
    int? progress,
    List<String>? inputFiles,
    List<String>? outputFiles,
    Map<String, dynamic>? taskOutput,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return Job(
      jobId: jobId ?? this.jobId,
      taskType: taskType ?? this.taskType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      inputFiles: inputFiles ?? this.inputFiles,
      outputFiles: outputFiles ?? this.outputFiles,
      taskOutput: taskOutput ?? this.taskOutput,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.parse(value);
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }
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

  WorkerStatus copyWith({
    String? workerId,
    bool? running,
    int? ttlRemaining,
  }) {
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
  const WorkersListResponse({
    required this.workers,
    required this.total,
  });

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
    return {
      'workers': workers.map((e) => e.toJson()).toList(),
      'total': total,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  WorkersListResponse copyWith({
    List<WorkerStatus>? workers,
    int? total,
  }) {
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

  StorageSize copyWith({
    int? totalBytes,
    double? totalMb,
    int? jobCount,
  }) {
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
  const CleanupResponse({
    required this.message,
    required this.deletedCount,
  });

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
    return {
      'message': message,
      'deleted_count': deletedCount,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  CleanupResponse copyWith({
    String? message,
    int? deletedCount,
  }) {
    return CleanupResponse(
      message: message ?? this.message,
      deletedCount: deletedCount ?? this.deletedCount,
    );
  }
}

/// Worker capabilities model
@immutable
class WorkerCapabilities {
  const WorkerCapabilities({
    required this.numWorkers,
    required this.capabilities,
  });

  factory WorkerCapabilities.fromJson(Map<String, dynamic> json) {
    return WorkerCapabilities(
      numWorkers: json['num_workers'] as int? ?? 0,
      capabilities: Map<String, int>.from(
        (json['capabilities'] as Map<dynamic, dynamic>? ?? {})
            .cast<String, int>(),
      ),
    );
  }

  factory WorkerCapabilities.fromMap(Map<String, dynamic> map) {
    return WorkerCapabilities.fromJson(map);
  }

  final int numWorkers;
  final Map<String, int> capabilities;

  Map<String, dynamic> toJson() {
    return {
      'num_workers': numWorkers,
      'capabilities': capabilities,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  WorkerCapabilities copyWith({
    int? numWorkers,
    Map<String, int>? capabilities,
  }) {
    return WorkerCapabilities(
      numWorkers: numWorkers ?? this.numWorkers,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}
