import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../clients/store_client.dart';
import '../exceptions.dart';
import '../models/intelligence_models.dart';
import '../models/store_models.dart';
import '../mqtt_monitor.dart';
import '../server_config.dart';
import '../types.dart';

/// High-level manager for store operations.
class StoreManager {
  StoreManager(this.storeClient, [this._config, MQTTJobMonitor? mqttMonitor])
    : _mqttMonitor = mqttMonitor;

  // Factory constructors

  factory StoreManager.guest({
    String baseUrl = 'http://localhost:8011',
    Duration timeout = const Duration(seconds: 30),
  }) {
    // Guest mode
    return StoreManager(StoreClient(baseUrl: baseUrl, timeout: timeout));
  }

  factory StoreManager.authenticated({
    required ServerConfig config,
    String Function()? getCachedToken,
    Future<String> Function()? getValidTokenAsync,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 30),
  }) {
    final authProvider = JWTAuthProvider(
      getCachedToken: getCachedToken,
      getValidTokenAsync: getValidTokenAsync,
    );

    return StoreManager(
      StoreClient(
        baseUrl: baseUrl ?? config.storeUrl,
        authProvider: authProvider,
        timeout: timeout,
      ),
      config,
    );
  }
  final StoreClient storeClient;
  MQTTJobMonitor? _mqttMonitor;
  ServerConfig? _config;
  final Map<String, String> _mqttSubscriptions = {};

  // MQTT related

  Future<MQTTJobMonitor> _getMqttMonitor() async {
    if (_mqttMonitor != null) return _mqttMonitor!;

    final broker = _config?.mqttBroker ?? 'localhost';
    final port = _config?.mqttPort ?? 1883;

    _mqttMonitor = getMqttMonitor(broker: broker, port: port);
    // Note: Python connects in init, but here we might want to connect lazily or explicit await?
    // MqttMonitor connect is async.
    // We should probably rely on user to connect monitor or implicitly connect?
    // Python code _connect() is called in init.
    // Dart MqttClient connect is async future.
    // We can't await in sync getter.
    // We'll rely on explicit connection or check later.

    if (!_mqttMonitor!.isConnected) {
      await _mqttMonitor!.connect();
    }

    return _mqttMonitor!;
  }

  Future<void> close() async {
    storeClient.close();
    if (_mqttMonitor != null) {
      releaseMqttMonitor(_mqttMonitor!);
      _mqttMonitor = null;
    }
  }

  StoreOperationResult<T> _handleError<T>(dynamic error) {
    String? detail;
    int? statusCode;

    if (error is HttpStatusError) {
      statusCode = error.statusCode;
      if (error.responseBody != null) {
        try {
          final data = jsonDecode(error.responseBody!) as Map<String, dynamic>;
          detail = data['detail']?.toString();
        } on Object catch (_) {
          // Fallback to error message
        }
      }
      detail ??= error.message;
    }

    if (error is AuthenticationError || statusCode == 401) {
      return StoreOperationResult<T>(
        error: 'Unauthorized: Invalid or missing token',
        statusCode: statusCode ?? 401,
      );
    } else if (error is PermissionError || statusCode == 403) {
      return StoreOperationResult<T>(
        error: 'Forbidden: Insufficient permissions',
        statusCode: statusCode ?? 403,
      );
    } else if (error is ValidationError ||
        statusCode == 422 ||
        statusCode == 400) {
      final prefix = statusCode == 400 ? 'Bad Request' : 'Validation Error';
      return StoreOperationResult<T>(
        error: '$prefix: ${detail ?? error.toString()}',
        statusCode: statusCode ?? (error is ValidationError ? 422 : 400),
      );
    } else if (error is NotFoundError || statusCode == 404) {
      return StoreOperationResult<T>(
        error: 'Not Found: ${detail ?? error.toString()}',
        statusCode: statusCode ?? 404,
      );
    } else if (error is JobNotFoundError) {
      return StoreOperationResult<T>(
        error: detail ?? error.message,
        statusCode: statusCode ?? 404, // Job not found is typically 404
      );
    } else if (error is ComputeClientError) {
      return StoreOperationResult<T>(
        error: detail ?? error.message,
        statusCode: statusCode,
      );
    } else {
      return StoreOperationResult<T>(
        error: 'Unexpected error: $error',
        statusCode: statusCode,
      );
    }
  }

  // Read operations

  Future<StoreOperationResult<EntityListResponse>> listEntities({
    int page = 1,
    int pageSize = 20,
    String? searchQuery,
    bool excludeDeleted = false,
  }) async {
    try {
      final result = await storeClient.listEntities(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        excludeDeleted: excludeDeleted,
      );
      return StoreOperationResult(
        success: 'Entities retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<Entity>> readEntity(
    int entityId, {
    int? version,
  }) async {
    try {
      final result = await storeClient.readEntity(entityId, version: version);
      return StoreOperationResult(
        success: 'Entity retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<List<EntityVersion>>> getVersions(
    int entityId,
  ) async {
    try {
      final result = await storeClient.getVersions(entityId);
      return StoreOperationResult(
        success: 'Version history retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<String> monitorEntity(
    int entityId,
    void Function(EntityStatusPayload) callback,
  ) async {
    final monitor = await _getMqttMonitor();

    // Determine store port
    var storePort = 8001;
    if (_config != null) {
      try {
        final uri = Uri.parse(_config!.storeUrl);
        if (uri.hasPort) storePort = uri.port;
      } on Object catch (_) {}
    }

    final internalSubId = monitor.subscribeEntityStatus(
      entityId,
      storePort,
      callback,
    );
    final userSubId = const Uuid().v4();
    _mqttSubscriptions[userSubId] = internalSubId;
    return userSubId;
  }

  void stopMonitoring(String subscriptionId) {
    if (_mqttSubscriptions.containsKey(subscriptionId)) {
      final internalId = _mqttSubscriptions[subscriptionId]!;
      if (_mqttMonitor != null) {
        _mqttMonitor!.unsubscribeEntityStatus(internalId);
      }
      _mqttSubscriptions.remove(subscriptionId);
    }
  }

  Future<EntityStatusPayload> waitForEntityStatus(
    int entityId, {
    String targetStatus = 'completed',
    Duration timeout = const Duration(seconds: 60),
    bool failOnError = true,
  }) async {
    // Optimization: Check current status first.
    // This allows us to return immediately for duplicates or fast jobs,
    // and avoids issues with stale retained MQTT messages from ID reuse.
    final entityResult = await readEntity(entityId);
    if (entityResult.data != null) {
      final intelligence = entityResult.data!.intelligenceData;
      if (intelligence != null) {
        if (intelligence.overallStatus == targetStatus) {
          return EntityStatusPayload(
            entityId: entityId,
            status: intelligence.overallStatus,
            timestamp: intelligence.lastUpdated,
            faceDetection: intelligence.inferenceStatus.faceDetection,
            faceCount: intelligence.faceCount,
            clipEmbedding: intelligence.inferenceStatus.clipEmbedding,
            dinoEmbedding: intelligence.inferenceStatus.dinoEmbedding,
            faceEmbeddings: intelligence.inferenceStatus.faceEmbeddings,
          );
        } else if (failOnError && intelligence.overallStatus == 'failed') {
          throw Exception(
            'Entity processing failed: ${intelligence.overallStatus}',
          );
        }
      }
    }

    final completer = Completer<EntityStatusPayload>();

    void callback(EntityStatusPayload payload) {
      if (completer.isCompleted) return;

      if (payload.status == targetStatus) {
        completer.complete(payload);
      } else if (payload.status == 'failed') {
        if (failOnError) {
          completer.completeError(
            Exception('Entity processing failed: ${payload.status}'),
          );
        } else {
          // If not failing on error, return the failed payload as a terminal state
          completer.complete(payload);
        }
      }
    }

    String? subId;
    try {
      // Use the provided timeout for the entire operation including setup
      subId = await monitorEntity(entityId, callback).timeout(timeout);
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Timeout waiting for entity $entityId to reach status $targetStatus',
            timeout,
          );
        },
      );
    } finally {
      if (subId != null) {
        stopMonitoring(subId);
      }
    }
  }

  /// Create a new entity (image or collection).
  ///
  /// For images, it triggers asynchronous intelligence processing.
  Future<StoreOperationResult<Entity>> createEntity({
    required bool isCollection,
    String? label,
    String? description,
    int? parentId,
    String? imagePath,
  }) async {
    try {
      final (entity, statusCode) = await storeClient.createEntity(
        isCollection: isCollection,
        label: label,
        description: description,
        parentId: parentId,
        imagePath: imagePath,
      );

      // 201 Created (New), 200 OK (Duplicate)
      final successMsg = statusCode == 201
          ? 'Entity created successfully'
          : 'Duplicate entity found';

      return StoreOperationResult(
        success: successMsg,
        data: entity,
        isDuplicate: statusCode == 200,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<Entity>> updateEntity(
    int entityId, {
    required String label,
    String? description,
    bool isCollection = false,
    int? parentId,
    String? imagePath,
  }) async {
    try {
      final result = await storeClient.updateEntity(
        entityId,
        isCollection: isCollection,
        label: label,
        description: description,
        parentId: parentId,
        imagePath: imagePath,
      );
      return StoreOperationResult(
        success: 'Entity updated successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<Entity>> patchEntity(
    int entityId, {
    Object? label = const Unset(),
    Object? description = const Unset(),
    Object? parentId = const Unset(),
    Object? isDeleted = const Unset(),
    Object? isCollection = const Unset(),
  }) async {
    try {
      final result = await storeClient.patchEntity(
        entityId,
        label: label,
        description: description,
        parentId: parentId,
        isDeleted: isDeleted,
        isCollection: isCollection,
      );
      return StoreOperationResult(
        success: 'Entity patched successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<void>> deleteEntity(
    int entityId, {
    bool force = true,
  }) async {
    try {
      if (force) {
        // Step 1: Ensure it's soft-deleted
        final patchRes = await patchEntity(entityId, isDeleted: true);
        if (!patchRes.isSuccess) {
          // If entity doesn't exist, patch will fail with 404
          if (patchRes.error != null &&
              (patchRes.error!.contains('Not Found') ||
                  patchRes.error!.contains('404'))) {
            return patchRes;
          }
          // For other errors, we can't proceed
          return patchRes;
        }
      }

      // Step 2: Hard delete
      await storeClient.deleteEntity(entityId);
      return StoreOperationResult(
        success: 'Entity deleted successfully',
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<void>> deleteFace(int faceId) async {
    try {
      await storeClient.deleteFace(faceId);
      return StoreOperationResult(
        success: 'Face deleted successfully',
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  // Admin

  Future<StoreOperationResult<StoreConfig>> getConfig() async {
    try {
      final result = await storeClient.getConfig();
      return StoreOperationResult(
        success: 'Configuration retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<StoreConfig>> updateGuestMode({
    required bool guestMode,
  }) async {
    try {
      final result = await storeClient.updateGuestMode(guestMode: guestMode);
      return StoreOperationResult(
        success: 'Guest mode configuration updated successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  // System/Audit

  Future<StoreOperationResult<AuditReport>> getAuditReport() async {
    try {
      final result = await storeClient.getAuditReport();
      return StoreOperationResult(
        success: 'Audit report generated successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<CleanupReport>> clearOrphans() async {
    try {
      final result = await storeClient.clearOrphans();
      return StoreOperationResult(
        success: 'Orphaned resources cleared successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<Map<String, dynamic>>> getMInsightStatus() async {
    try {
      final result = await storeClient.getMInsightStatus();
      return StoreOperationResult(
        success: 'MInsight status retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  // Intelligence

  Future<StoreOperationResult<EntityIntelligenceData?>> getEntityIntelligence(
    int entityId,
  ) async {
    try {
      final result = await storeClient.getEntityIntelligence(entityId);
      return StoreOperationResult(
        success: 'Intelligence data retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<List<FaceResponse>>> getEntityFaces(
    int entityId,
  ) async {
    try {
      final result = await storeClient.getEntityFaces(entityId);
      return StoreOperationResult(
        success: 'Faces retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<List<EntityJobResponse>>> getEntityJobs(
    int entityId,
  ) async {
    try {
      final result = await storeClient.getEntityJobs(entityId);
      return StoreOperationResult(
        success: 'Jobs retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<List<int>>> downloadEntityClipEmbedding(
    int entityId,
  ) async {
    try {
      final result = await storeClient.downloadEntityClipEmbedding(entityId);
      return StoreOperationResult(
        success: 'CLIP embedding downloaded successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<List<int>>> downloadEntityDinoEmbedding(
    int entityId,
  ) async {
    try {
      final result = await storeClient.downloadEntityDinoEmbedding(entityId);
      return StoreOperationResult(
        success: 'DINO embedding downloaded successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<List<int>>> downloadFaceEmbedding(
    int faceId,
  ) async {
    try {
      final result = await storeClient.downloadFaceEmbedding(faceId);
      return StoreOperationResult(
        success: 'Face embedding downloaded successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<List<KnownPersonResponse>>>
  getKnownPersons() async {
    try {
      final result = await storeClient.getKnownPersons();
      return StoreOperationResult(
        success: 'Known persons retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<KnownPersonResponse>> getKnownPerson(
    int personId,
  ) async {
    try {
      final result = await storeClient.getKnownPerson(personId);
      return StoreOperationResult(
        success: 'Known person details retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<List<FaceResponse>>> getPersonFaces(
    int personId,
  ) async {
    try {
      final result = await storeClient.getPersonFaces(personId);
      return StoreOperationResult(
        success: 'Person faces retrieved successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }

  Future<StoreOperationResult<KnownPersonResponse>> updateKnownPersonName(
    int personId,
    String name,
  ) async {
    try {
      final result = await storeClient.updateKnownPersonName(personId, name);
      return StoreOperationResult(
        success: 'Person name updated successfully',
        data: result,
      );
    } on Object catch (e) {
      return _handleError(e);
    }
  }
}
