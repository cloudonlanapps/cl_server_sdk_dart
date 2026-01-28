import 'dart:convert';

/// Bounding box coordinates (normalized 0.0-1.0).
class BBox {
  BBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory BBox.fromMap(Map<String, dynamic> map) {
    return BBox(
      x1: (map['x1'] as num).toDouble(),
      y1: (map['y1'] as num).toDouble(),
      x2: (map['x2'] as num).toDouble(),
      y2: (map['y2'] as num).toDouble(),
    );
  }

  factory BBox.fromJson(String source) =>
      BBox.fromMap(json.decode(source) as Map<String, dynamic>);
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  Map<String, dynamic> toMap() {
    return {
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Facial landmarks (normalized 0.0-1.0).
class FaceLandmarks {
  FaceLandmarks({
    required this.rightEye,
    required this.leftEye,
    required this.noseTip,
    required this.mouthRight,
    required this.mouthLeft,
  });

  factory FaceLandmarks.fromMap(Map<String, dynamic> map) {
    List<double> toList(dynamic value) =>
        (value as List).map((e) => (e as num).toDouble()).toList();

    return FaceLandmarks(
      rightEye: toList(map['right_eye']),
      leftEye: toList(map['left_eye']),
      noseTip: toList(map['nose_tip']),
      mouthRight: toList(map['mouth_right']),
      mouthLeft: toList(map['mouth_left']),
    );
  }

  factory FaceLandmarks.fromJson(String source) =>
      FaceLandmarks.fromMap(json.decode(source) as Map<String, dynamic>);
  final List<double> rightEye;
  final List<double> leftEye;
  final List<double> noseTip;
  final List<double> mouthRight;
  final List<double> mouthLeft;

  Map<String, dynamic> toMap() {
    return {
      'right_eye': rightEye,
      'left_eye': leftEye,
      'nose_tip': noseTip,
      'mouth_right': mouthRight,
      'mouth_left': mouthLeft,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Response schema for detected face.
class FaceResponse {
  FaceResponse({
    required this.id,
    required this.entityId,
    required this.bbox,
    required this.confidence,
    required this.landmarks,
    required this.filePath,
    required this.createdAt,
    this.knownPersonId,
  });

  factory FaceResponse.fromMap(Map<String, dynamic> map) {
    return FaceResponse(
      id: map['id'] as int,
      entityId: map['entity_id'] as int,
      bbox: BBox.fromMap(map['bbox'] as Map<String, dynamic>),
      confidence: (map['confidence'] as num).toDouble(),
      landmarks: FaceLandmarks.fromMap(
        map['landmarks'] as Map<String, dynamic>,
      ),
      filePath: map['file_path'] as String,
      createdAt: map['created_at'] as int,
      knownPersonId: map['known_person_id'] as int?,
    );
  }

  factory FaceResponse.fromJson(String source) =>
      FaceResponse.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Face ID
  final int id;

  /// Entity ID this face belongs to
  final int entityId;

  /// Normalized bounding box
  final BBox bbox;

  /// Detection confidence score [0.0, 1.0]
  final double confidence;

  /// Five facial keypoints
  final FaceLandmarks landmarks;

  /// Relative path to cropped face image
  final String filePath;

  /// Creation timestamp (milliseconds)
  final int createdAt;

  /// Known person ID (face recognition)
  final int? knownPersonId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_id': entityId,
      'bbox': bbox.toMap(),
      'confidence': confidence,
      'landmarks': landmarks.toMap(),
      'file_path': filePath,
      'created_at': createdAt,
      'known_person_id': knownPersonId,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Job tracking information.
class JobInfo {
  JobInfo({
    required this.jobId,
    required this.taskType,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  factory JobInfo.fromMap(Map<String, dynamic> map) {
    return JobInfo(
      jobId: map['job_id'] as String,
      taskType: map['task_type'] as String,
      status: map['status'] as String,
      startedAt: map['started_at'] as int,
      completedAt: map['completed_at'] as int?,
      errorMessage: map['error_message'] as String?,
    );
  }

  factory JobInfo.fromJson(String source) =>
      JobInfo.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Compute service job ID
  final String jobId;

  /// Task type (face_detection, clip_embedding, dino_embedding)
  final String taskType;

  /// Job status (queued, in_progress, completed, failed)
  final String status;

  /// Job start timestamp (milliseconds)
  final int startedAt;

  /// Completion timestamp (milliseconds)
  final int? completedAt;

  /// Error message if failed
  final String? errorMessage;

  Map<String, dynamic> toMap() {
    return {
      'job_id': jobId,
      'task_type': taskType,
      'status': status,
      'started_at': startedAt,
      'completed_at': completedAt,
      'error_message': errorMessage,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Fine-grained inference status.
class InferenceStatus {
  InferenceStatus({
    this.faceDetection = 'pending',
    this.clipEmbedding = 'pending',
    this.dinoEmbedding = 'pending',
    this.faceEmbeddings,
  });

  factory InferenceStatus.fromMap(Map<String, dynamic> map) {
    return InferenceStatus(
      faceDetection: map['face_detection'] as String? ?? 'pending',
      clipEmbedding: map['clip_embedding'] as String? ?? 'pending',
      dinoEmbedding: map['dino_embedding'] as String? ?? 'pending',
      faceEmbeddings: map['face_embeddings'] != null
          ? List<String>.from(map['face_embeddings'] as List)
          : null,
    );
  }

  factory InferenceStatus.fromJson(String source) =>
      InferenceStatus.fromMap(json.decode(source) as Map<String, dynamic>);
  final String faceDetection;
  final String clipEmbedding;
  final String dinoEmbedding;
  final List<String>? faceEmbeddings;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'face_detection': faceDetection,
      'clip_embedding': clipEmbedding,
      'dino_embedding': dinoEmbedding,
    };
    if (faceEmbeddings != null) {
      map['face_embeddings'] = faceEmbeddings;
    }
    return map;
  }

  String toJson() => json.encode(toMap());
}

/// Denormalized intelligence data (JSON field).
class EntityIntelligenceData {
  EntityIntelligenceData({
    required this.inferenceStatus,
    required this.lastUpdated,
    this.overallStatus = 'queued',
    this.lastProcessedMd5,
    this.lastProcessedVersion,
    this.faceCount,
    this.activeProcessingMd5,
    this.activeJobs = const [],
    this.jobHistory = const [],
    this.errorMessage,
  });

  factory EntityIntelligenceData.fromMap(Map<String, dynamic> map) {
    return EntityIntelligenceData(
      overallStatus: map['overall_status'] as String? ?? 'queued',
      lastProcessedMd5: map['last_processed_md5'] as String?,
      lastProcessedVersion: map['last_processed_version'] as int?,
      faceCount: map['face_count'] as int?,
      activeProcessingMd5: map['active_processing_md5'] as String?,
      activeJobs: map['active_jobs'] != null
          ? (map['active_jobs'] as List)
                .map((e) => JobInfo.fromMap(e as Map<String, dynamic>))
                .toList()
          : const [],
      jobHistory: map['job_history'] != null
          ? (map['job_history'] as List)
                .map((e) => JobInfo.fromMap(e as Map<String, dynamic>))
                .toList()
          : const [],
      inferenceStatus: map['inference_status'] != null
          ? InferenceStatus.fromMap(
              map['inference_status'] as Map<String, dynamic>,
            )
          : InferenceStatus(),
      lastUpdated: map['last_updated'] as int,
      errorMessage: map['error_message'] as String?,
    );
  }

  factory EntityIntelligenceData.fromJson(String source) =>
      EntityIntelligenceData.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  /// Overall status (queued, processing, completed, failed)
  final String overallStatus;
  final String? lastProcessedMd5;
  final int? lastProcessedVersion;
  final int? faceCount;
  final String? activeProcessingMd5;
  final List<JobInfo> activeJobs;
  final List<JobInfo> jobHistory;
  final InferenceStatus inferenceStatus;

  /// Last update timestamp (milliseconds)
  final int lastUpdated;

  final String? errorMessage;

  Map<String, dynamic> toMap() {
    return {
      'overall_status': overallStatus,
      'last_processed_md5': lastProcessedMd5,
      'last_processed_version': lastProcessedVersion,
      'face_count': faceCount,
      'active_processing_md5': activeProcessingMd5,
      'active_jobs': activeJobs.map((e) => e.toMap()).toList(),
      'job_history': jobHistory.map((e) => e.toMap()).toList(),
      'inference_status': inferenceStatus.toMap(),
      'last_updated': lastUpdated,
      'error_message': errorMessage,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Response schema for known person.
class KnownPersonResponse {
  KnownPersonResponse({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.name,
    this.faceCount,
  });

  factory KnownPersonResponse.fromMap(Map<String, dynamic> map) {
    return KnownPersonResponse(
      id: map['id'] as int,
      name: map['name'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      faceCount: map['face_count'] as int?,
    );
  }

  factory KnownPersonResponse.fromJson(String source) =>
      KnownPersonResponse.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Known person ID
  final int id;

  /// Person name (optional)
  final String? name;

  /// Creation timestamp (milliseconds)
  final int createdAt;

  /// Last update timestamp (milliseconds)
  final int updatedAt;

  /// Number of faces for this person (optional)
  final int? faceCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'face_count': faceCount,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Request to update a known person's name.
class UpdatePersonNameRequest {
  UpdatePersonNameRequest({required this.name});

  factory UpdatePersonNameRequest.fromMap(Map<String, dynamic> map) {
    return UpdatePersonNameRequest(
      name: map['name'] as String,
    );
  }

  factory UpdatePersonNameRequest.fromJson(String source) =>
      UpdatePersonNameRequest.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  /// New name for the person
  final String name;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Alias for JobInfo to match Python SDK
class EntityJobResponse extends JobInfo {
  EntityJobResponse({
    required super.jobId,
    required super.taskType,
    required super.status,
    required super.startedAt,
    super.completedAt,
    super.errorMessage,
  });

  factory EntityJobResponse.fromMap(Map<String, dynamic> map) {
    final info = JobInfo.fromMap(map);
    return EntityJobResponse(
      jobId: info.jobId,
      taskType: info.taskType,
      status: info.status,
      startedAt: info.startedAt,
      completedAt: info.completedAt,
      errorMessage: info.errorMessage,
    );
  }
}
