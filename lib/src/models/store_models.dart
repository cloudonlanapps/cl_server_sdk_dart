import 'dart:convert';
import 'intelligence_models.dart';

/// Information about an orphaned file.
class OrphanedFileInfo {
  OrphanedFileInfo({
    required this.filePath,
    this.fileSize,
    this.lastModified,
  });

  factory OrphanedFileInfo.fromMap(Map<String, dynamic> map) {
    return OrphanedFileInfo(
      filePath: map['file_path'] as String,
      fileSize: map['file_size'] as int?,
      lastModified: map['last_modified'] as int?,
    );
  }

  final String filePath;
  final int? fileSize;
  final int? lastModified;

  Map<String, dynamic> toMap() {
    return {
      'file_path': filePath,
      'file_size': fileSize,
      'last_modified': lastModified,
    };
  }
}

/// Information about an orphaned face record.
class OrphanedFaceInfo {
  OrphanedFaceInfo({
    required this.faceId,
    required this.entityId,
  });

  factory OrphanedFaceInfo.fromMap(Map<String, dynamic> map) {
    return OrphanedFaceInfo(
      faceId: map['face_id'] as int,
      entityId: map['entity_id'] as int,
    );
  }

  final int faceId;
  final int entityId;

  Map<String, dynamic> toMap() {
    return {
      'face_id': faceId,
      'entity_id': entityId,
    };
  }
}

/// Information about an orphaned vector in Qdrant.
class OrphanedVectorInfo {
  OrphanedVectorInfo({
    required this.vectorId,
    required this.collectionName,
  });

  factory OrphanedVectorInfo.fromMap(Map<String, dynamic> map) {
    return OrphanedVectorInfo(
      vectorId: map['vector_id'] as String,
      collectionName: map['collection_name'] as String,
    );
  }

  final String vectorId;
  final String collectionName;

  Map<String, dynamic> toMap() {
    return {
      'vector_id': vectorId,
      'collection_name': collectionName,
    };
  }
}

/// Information about an orphaned MQTT retained message.
class OrphanedMqttInfo {
  OrphanedMqttInfo({
    required this.entityId,
    required this.topic,
  });

  factory OrphanedMqttInfo.fromMap(Map<String, dynamic> map) {
    return OrphanedMqttInfo(
      entityId: map['entity_id'] as int,
      topic: map['topic'] as String,
    );
  }

  final int entityId;
  final String topic;

  Map<String, dynamic> toMap() {
    return {
      'entity_id': entityId,
      'topic': topic,
    };
  }
}

/// Comprehensive audit report of data integrity issues.
class AuditReport {
  AuditReport({
    required this.orphanedFiles,
    required this.orphanedFaces,
    required this.orphanedVectors,
    required this.orphanedMqtt,
    required this.timestamp,
  });

  factory AuditReport.fromMap(Map<String, dynamic> map) {
    return AuditReport(
      orphanedFiles: (map['orphaned_files'] as List)
          .map((e) => OrphanedFileInfo.fromMap(e as Map<String, dynamic>))
          .toList(),
      orphanedFaces: (map['orphaned_faces'] as List)
          .map((e) => OrphanedFaceInfo.fromMap(e as Map<String, dynamic>))
          .toList(),
      orphanedVectors: (map['orphaned_vectors'] as List)
          .map((e) => OrphanedVectorInfo.fromMap(e as Map<String, dynamic>))
          .toList(),
      orphanedMqtt: (map['orphaned_mqtt'] as List)
          .map((e) => OrphanedMqttInfo.fromMap(e as Map<String, dynamic>))
          .toList(),
      timestamp:
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  final List<OrphanedFileInfo> orphanedFiles;
  final List<OrphanedFaceInfo> orphanedFaces;
  final List<OrphanedVectorInfo> orphanedVectors;
  final List<OrphanedMqttInfo> orphanedMqtt;
  final int timestamp;

  Map<String, dynamic> toMap() {
    return {
      'orphaned_files': orphanedFiles.map((e) => e.toMap()).toList(),
      'orphaned_faces': orphanedFaces.map((e) => e.toMap()).toList(),
      'orphaned_vectors': orphanedVectors.map((e) => e.toMap()).toList(),
      'orphaned_mqtt': orphanedMqtt.map((e) => e.toMap()).toList(),
      'timestamp': timestamp,
    };
  }
}

/// Summary of cleaned up orphaned resources.
class CleanupReport {
  CleanupReport({
    required this.filesDeleted,
    required this.facesDeleted,
    required this.vectorsDeleted,
    required this.mqttCleared,
    required this.timestamp,
  });

  factory CleanupReport.fromMap(Map<String, dynamic> map) {
    return CleanupReport(
      filesDeleted: map['files_deleted'] as int,
      facesDeleted: map['faces_deleted'] as int,
      vectorsDeleted: map['vectors_deleted'] as int,
      mqttCleared: map['mqtt_cleared'] as int,
      timestamp:
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  final int filesDeleted;
  final int facesDeleted;
  final int vectorsDeleted;
  final int mqttCleared;
  final int timestamp;

  Map<String, dynamic> toMap() {
    return {
      'files_deleted': filesDeleted,
      'faces_deleted': facesDeleted,
      'vectors_deleted': vectorsDeleted,
      'mqtt_cleared': mqttCleared,
      'timestamp': timestamp,
    };
  }
}

/// Media entity with metadata and file properties.
class Entity {
  Entity({
    required this.id,
    this.isCollection,
    this.label,
    this.description,
    this.parentId,
    this.addedDate,
    this.updatedDate,
    this.createDate,
    this.addedBy,
    this.updatedBy,
    this.isDeleted,
    this.fileSize,
    this.height,
    this.width,
    this.duration,
    this.mimeType,
    this.type,
    this.extension,
    this.md5,
    this.filePath,
    this.isIndirectlyDeleted,
    this.intelligenceData,
  });

  factory Entity.fromMap(Map<String, dynamic> map) {
    return Entity(
      id: map['id'] as int,
      isCollection: map['is_collection'] as bool?,
      label: map['label'] as String?,
      description: map['description'] as String?,
      parentId: map['parent_id'] as int?,
      addedDate: map['added_date'] as int?,
      updatedDate: map['updated_date'] as int?,
      createDate: map['create_date'] as int?,
      addedBy: map['added_by'] as String?,
      updatedBy: map['updated_by'] as String?,
      isDeleted: map['is_deleted'] as bool?,
      fileSize: map['file_size'] as int?,
      height: map['height'] as int?,
      width: map['width'] as int?,
      duration: (map['duration'] as num?)?.toDouble(),
      mimeType: map['mime_type'] as String?,
      type: map['type'] as String?,
      extension: map['extension'] as String?,
      md5: map['md5'] as String?,
      filePath: map['file_path'] as String?,
      isIndirectlyDeleted: map['is_indirectly_deleted'] as bool?,
      intelligenceData: map['intelligence_data'] != null
          ? EntityIntelligenceData.fromMap(
              map['intelligence_data'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  factory Entity.fromJson(String source) =>
      Entity.fromMap(json.decode(source) as Map<String, dynamic>);
  // Core fields

  /// Unique entity identifier
  final int id;

  /// Whether this is a collection (folder) or media item
  final bool? isCollection;

  /// Display name for the entity
  final String? label;

  /// Entity description
  final String? description;

  /// ID of parent collection
  final int? parentId;

  // Audit/metadata fields (milliseconds since epoch)

  /// Creation timestamp (milliseconds since epoch)
  final int? addedDate;

  /// Last modification timestamp (milliseconds since epoch)
  final int? updatedDate;

  /// Initial creation timestamp (milliseconds since epoch)
  final int? createDate;

  /// User who created the entity
  final String? addedBy;

  /// User who last modified the entity
  final String? updatedBy;

  /// Soft delete flag
  final bool? isDeleted;

  // Media file properties

  /// File size in bytes
  final int? fileSize;

  /// Image/video height in pixels
  final int? height;

  /// Image/video width in pixels
  final int? width;

  /// Audio/video duration in seconds
  final double? duration;

  /// MIME type
  final String? mimeType;

  /// Media type category
  final String? type;

  /// File extension
  final String? extension;

  /// MD5 checksum
  final String? md5;

  /// Relative file path in storage
  final String? filePath;

  /// True if any ancestor in the parent chain is soft-deleted
  final bool? isIndirectlyDeleted;

  /// Denormalized intelligence data
  final EntityIntelligenceData? intelligenceData;

  /// Compatibility property for overall intelligence status.
  String? get intelligenceStatus => intelligenceData?.overallStatus;

  /// Convert added_date (milliseconds) to DateTime.
  DateTime? get addedDateDatetime => addedDate != null
      ? DateTime.fromMillisecondsSinceEpoch(addedDate!)
      : null;

  /// Convert updated_date (milliseconds) to DateTime.
  DateTime? get updatedDateDatetime => updatedDate != null
      ? DateTime.fromMillisecondsSinceEpoch(updatedDate!)
      : null;

  /// Convert create_date (milliseconds) to DateTime.
  DateTime? get createDateDatetime => createDate != null
      ? DateTime.fromMillisecondsSinceEpoch(createDate!)
      : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'is_collection': isCollection,
      'label': label,
      'description': description,
      'parent_id': parentId,
      'added_date': addedDate,
      'updated_date': updatedDate,
      'create_date': createDate,
      'added_by': addedBy,
      'updated_by': updatedBy,
      'is_deleted': isDeleted,
      'file_size': fileSize,
      'height': height,
      'width': width,
      'duration': duration,
      'mime_type': mimeType,
      'type': type,
      'extension': extension,
      'md5': md5,
      'file_path': filePath,
      'is_indirectly_deleted': isIndirectlyDeleted,
      'intelligence_data': intelligenceData?.toMap(),
    };
  }

  String toJson() => json.encode(toMap());
}

/// Pagination metadata for entity lists.
class EntityPagination {
  EntityPagination({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory EntityPagination.fromMap(Map<String, dynamic> map) {
    return EntityPagination(
      page: map['page'] as int,
      pageSize: map['page_size'] as int,
      totalItems: map['total_items'] as int,
      totalPages: map['total_pages'] as int,
      hasNext: map['has_next'] as bool,
      hasPrev: map['has_prev'] as bool,
    );
  }

  factory EntityPagination.fromJson(String source) =>
      EntityPagination.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Current page number (1-indexed)
  final int page;

  /// Items per page
  final int pageSize;

  /// Total number of entities
  final int totalItems;

  /// Total number of pages
  final int totalPages;

  /// Whether there is a next page
  final bool hasNext;

  /// Whether there is a previous page
  final bool hasPrev;

  Map<String, dynamic> toMap() {
    return {
      'page': page,
      'page_size': pageSize,
      'total_items': totalItems,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_prev': hasPrev,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Paginated list of entities.
class EntityListResponse {
  EntityListResponse({
    required this.items,
    required this.pagination,
  });

  factory EntityListResponse.fromMap(Map<String, dynamic> map) {
    return EntityListResponse(
      items: (map['items'] as List)
          .map((e) => Entity.fromMap(e as Map<String, dynamic>))
          .toList(),
      pagination: EntityPagination.fromMap(
        map['pagination'] as Map<String, dynamic>,
      ),
    );
  }

  factory EntityListResponse.fromJson(String source) =>
      EntityListResponse.fromMap(json.decode(source) as Map<String, dynamic>);

  /// List of entities in this page
  final List<Entity> items;

  /// Pagination metadata
  final EntityPagination pagination;

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((e) => e.toMap()).toList(),
      'pagination': pagination.toMap(),
    };
  }

  String toJson() => json.encode(toMap());
}

/// Version history for an entity.
class EntityVersion {
  EntityVersion({
    required this.version,
    required this.transactionId,
    this.endTransactionId,
    this.operationType,
    this.label,
    this.description,
  });

  factory EntityVersion.fromMap(Map<String, dynamic> map) {
    return EntityVersion(
      version: map['version'] as int,
      transactionId: map['transaction_id'] as int,
      endTransactionId: map['end_transaction_id'] as int?,
      operationType: map['operation_type'] as String?,
      label: map['label'] as String?,
      description: map['description'] as String?,
    );
  }

  factory EntityVersion.fromJson(String source) =>
      EntityVersion.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Version number
  final int version;

  /// Transaction identifier
  final int transactionId;

  /// End of version range
  final int? endTransactionId;

  /// Type of operation (INSERT, UPDATE, DELETE)
  final String? operationType;

  /// Label in this version
  final String? label;

  /// Description in this version
  final String? description;

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'transaction_id': transactionId,
      'end_transaction_id': endTransactionId,
      'operation_type': operationType,
      'label': label,
      'description': description,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Store configuration settings.
class StoreConfig {
  StoreConfig({
    required this.guestMode,
    this.updatedAt,
    this.updatedBy,
  });

  factory StoreConfig.fromMap(Map<String, dynamic> map) {
    return StoreConfig(
      guestMode: map['guest_mode'] as bool,
      updatedAt: map['updated_at'] as int?,
      updatedBy: map['updated_by'] as String?,
    );
  }

  factory StoreConfig.fromJson(String source) =>
      StoreConfig.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Whether guest mode is enabled
  final bool guestMode;

  /// Last configuration update (milliseconds since epoch)
  final int? updatedAt;

  /// User who last updated the configuration
  final String? updatedBy;

  /// Convert updatedAt (milliseconds) to DateTime.
  DateTime? get updatedAtDatetime => updatedAt != null
      ? DateTime.fromMillisecondsSinceEpoch(updatedAt!)
      : null;

  Map<String, dynamic> toMap() {
    return {
      'guest_mode': guestMode,
      'updated_at': updatedAt,
      'updated_by': updatedBy,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Wrapper for store operation results with error handling.
class StoreOperationResult<T> {
  StoreOperationResult({
    this.success,
    this.error,
    this.data,
    this.isDuplicate = false,
    this.statusCode,
  });

  factory StoreOperationResult.fromMap(
    Map<String, dynamic> map,
    T Function(dynamic data) dataFromJson, {
    bool isDuplicate = false,
    int? statusCode,
  }) {
    return StoreOperationResult<T>(
      success: map['success'] as String?,
      error: map['error'] as String?,
      data: map['data'] != null ? dataFromJson(map['data']) : null,
      isDuplicate: isDuplicate,
      statusCode: statusCode,
    );
  }

  /// Success message if operation succeeded
  final String? success;

  /// Error message if operation failed
  final String? error;

  /// Result data (only on success)
  final T? data;

  /// Whether the operation resulted in a duplicate (e.g. for create)
  final bool isDuplicate;

  /// HTTP status code from the server
  final int? statusCode;

  bool get isSuccess => error == null && (success != null || isDuplicate);
  bool get isError => error != null;

  T valueOrThrow() {
    if (isError) {
      throw Exception('Operation failed: $error');
    }
    if (data == null) {
      throw Exception('Operation succeeded but data is None');
    }
    return data!;
  }

  Map<String, dynamic> toMap(dynamic Function(T data) dataToJson) {
    return {
      'success': success,
      'error': error,
      'data': data != null ? dataToJson(data as T) : null,
    };
  }
}

// Request models

class CreateEntityRequest {
  CreateEntityRequest({
    required this.isCollection,
    this.label,
    this.description,
    this.parentId,
  });
  final bool isCollection;
  final String? label;
  final String? description;
  final int? parentId;
}

class UpdateEntityRequest {
  UpdateEntityRequest({
    required this.isCollection,
    required this.label,
    this.description,
    this.parentId,
  });
  final bool isCollection;
  final String label;
  final String? description;
  final int? parentId;
}

class PatchEntityRequest {
  PatchEntityRequest({
    this.label,
    this.description,
    this.parentId,
    this.isDeleted,
  });
  final String? label;
  final String? description;
  final int? parentId;
  final bool? isDeleted;
}

class UpdateReadAuthRequest {
  UpdateReadAuthRequest({required this.enabled});
  final bool enabled;
}

class RootResponse {
  RootResponse({
    required this.status,
    required this.service,
    required this.version,
    required this.guestMode,
  });

  factory RootResponse.fromMap(Map<String, dynamic> map) {
    return RootResponse(
      status: map['status'] as String,
      service: map['service'] as String,
      version: map['version'] as String,
      guestMode: map['guestMode'] as String,
    );
  }

  factory RootResponse.fromJson(String source) =>
      RootResponse.fromMap(json.decode(source) as Map<String, dynamic>);
  final String status;
  final String service;
  final String version;
  final String guestMode;

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'service': service,
      'version': version,
      'guestMode': guestMode,
    };
  }

  String toJson() => json.encode(toMap());
}
