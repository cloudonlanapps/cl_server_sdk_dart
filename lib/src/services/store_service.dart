import 'package:http/http.dart' as http;

import '../core/http_client.dart';
import '../core/models/store_models.dart';
import '../utils/constants.dart';

/// Client for CL Server Store Service (Port 8001)
class StoreService {
  StoreService(
    this.baseUrl, {
    this.token,
    http.Client? httpClient,
  }) {
    _httpClient = HttpClientWrapper(
      baseUrl: baseUrl,
      token: token,
      httpClient: httpClient,
    );
  }
  final String baseUrl;
  final String? token;
  late final HttpClientWrapper _httpClient;

  /// List entities with pagination
  /// GET /entities?page=1&page_size=20
  Future<EntityListResponse> listEntities({
    int page = 1,
    int pageSize = 20,
    String? searchQuery,
    int? version,
  }) async {
    final queryParams = <String, String>{
      QueryParameters.page: page.toString(),
      QueryParameters.pageSize: pageSize.toString(),
    };

    if (searchQuery != null) {
      queryParams[QueryParameters.searchQuery] = searchQuery;
    }
    if (version != null) {
      queryParams[QueryParameters.version] = version.toString();
    }

    final response = await _httpClient.get(
      StoreServiceEndpoints.listEntities,
      queryParameters: queryParams,
    );
    return EntityListResponse.fromJson(response);
  }

  /// Get entity by ID
  /// GET /entities/{entity_id}
  Future<Entity> getEntity(
    int entityId, {
    int? version,
    String? content,
  }) async {
    final endpoint = StoreServiceEndpoints.getEntity.replaceAll(
      '{entity_id}',
      entityId.toString(),
    );

    final queryParams = <String, String>{};
    if (version != null) {
      queryParams[QueryParameters.version] = version.toString();
    }
    if (content != null) {
      queryParams['content'] = content;
    }

    final response = await _httpClient.get(
      endpoint,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return Entity.fromJson(response);
  }

  /// Get entity versions
  /// GET /entities/{entity_id}/versions
  Future<List<EntityVersion>> getVersions(int entityId) async {
    final endpoint = StoreServiceEndpoints.getVersions.replaceAll(
      '{entity_id}',
      entityId.toString(),
    );

    final response = await _httpClient.get(endpoint);

    // Response can be a direct list or wrapped in 'data' key
    final dynamic responseList = response is List ? response : response['data'];
    if (responseList is List) {
      return responseList
          .cast<Map<String, dynamic>>()
          .map(EntityVersion.fromJson)
          .toList();
    }

    return [];
  }

  /// Create entity
  /// POST /entities
  Future<Entity> createEntity({
    required bool isCollection,
    String? label,
    String? description,
    int? parentId,
  }) async {
    final body = <String, dynamic>{
      'is_collection': isCollection,
    };

    if (label != null) body['label'] = label;
    if (description != null) body['description'] = description;
    if (parentId != null) body['parent_id'] = parentId;

    final response = await _httpClient.post(
      StoreServiceEndpoints.createEntity,
      body: body,
      isFormData: true,
    );
    return Entity.fromJson(response);
  }

  /// Update entity (PUT)
  /// PUT /entities/{entity_id}
  Future<Entity> updateEntity(
    int entityId, {
    required bool isCollection,
    required String label,
    String? description,
    int? parentId,
  }) async {
    final endpoint = StoreServiceEndpoints.updateEntity.replaceAll(
      '{entity_id}',
      entityId.toString(),
    );

    final body = <String, dynamic>{
      'is_collection': isCollection,
      'label': label,
    };

    if (description != null) body['description'] = description;
    if (parentId != null) body['parent_id'] = parentId;

    final response = await _httpClient.put(
      endpoint,
      body: body,
      isFormData: true,
    );
    return Entity.fromJson(response);
  }

  /// Patch entity (PATCH)
  /// PATCH /entities/{entity_id}
  Future<Entity> patchEntity(
    int entityId, {
    String? label,
    String? description,
    int? parentId,
    bool? isDeleted,
  }) async {
    final endpoint = StoreServiceEndpoints.patchEntity.replaceAll(
      '{entity_id}',
      entityId.toString(),
    );

    final body = <String, dynamic>{};
    if (label != null) body['label'] = label;
    if (description != null) body['description'] = description;
    if (parentId != null) body['parent_id'] = parentId;
    if (isDeleted != null) body['is_deleted'] = isDeleted;

    final response = await _httpClient.patch(
      endpoint,
      body: body,
    );
    return Entity.fromJson(response);
  }

  /// Delete entity
  /// DELETE /entities/{entity_id}
  Future<void> deleteEntity(int entityId) async {
    final endpoint = StoreServiceEndpoints.deleteEntity.replaceAll(
      '{entity_id}',
      entityId.toString(),
    );
    await _httpClient.delete(endpoint);
  }

  /// Delete collection (all entities)
  /// DELETE /entities/collection
  Future<Map<String, dynamic>> deleteCollection() async {
    return _httpClient.delete(StoreServiceEndpoints.deleteCollection);
  }

  /// Get configuration
  /// GET /config
  Future<StoreConfig> getConfig() async {
    final response = await _httpClient.get(StoreServiceEndpoints.getConfig);
    return StoreConfig.fromJson(response);
  }

  /// Update read authentication configuration
  /// PUT /config/read-auth
  Future<StoreConfig> updateReadAuthConfig({
    required bool enabled,
  }) async {
    final response = await _httpClient.put(
      StoreServiceEndpoints.updateReadAuthConfig,
      body: {'enabled': enabled},
    );
    return StoreConfig.fromJson(response);
  }
}
