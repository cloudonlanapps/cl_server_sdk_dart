import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth.dart';
import '../exceptions.dart';
import '../http_utils.dart';
import '../models/intelligence_models.dart';
import '../models/store_models.dart';
import '../types.dart';

/// Low-level HTTP client for store service operations.
class StoreClient {
  StoreClient({
    String baseUrl = 'http://localhost:8001',
    this.authProvider,
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  }) : baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _client = client ?? http.Client();
  final String baseUrl;
  final AuthProvider? authProvider;
  final http.Client _client;
  final Duration timeout;

  /// Close HTTP client resources.
  void close() {
    _client.close();
  }

  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{};
    if (authProvider != null) {
      await authProvider!.refreshTokenIfNeeded();
      headers.addAll(authProvider!.getHeaders());
    }
    return headers;
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        try {
          return json.decode(response.body);
        } on Object catch (_) {
          // For endpoints returning bytes, handling is different,
          // but this helper assumes JSON.
          return null;
        }
      }
      return null;
    } else if (response.statusCode == 401) {
      throw AuthenticationError();
    } else if (response.statusCode == 403) {
      throw PermissionError('Forbidden: Insufficient permissions');
    } else if (response.statusCode == 404) {
      // Extract detail if possible
      try {
        final body = json.decode(response.body) as Map<String, dynamic>;
        throw JobNotFoundError((body['detail'] as String?) ?? 'Not Found');
      } on Object catch (_) {
        throw JobNotFoundError('Not Found');
      }
    } else {
      throw ComputeClientError('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // Health check

  Future<RootResponse> healthCheck() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return RootResponse.fromMap(jsonMap);
  }

  // Read operations

  Future<EntityListResponse> listEntities({
    int page = 1,
    int pageSize = 20,
    String? searchQuery,
    int? version,
    bool excludeDeleted = false,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'search_query': ?searchQuery,
      if (version != null) 'version': version.toString(),
      if (excludeDeleted) 'exclude_deleted': 'true',
    };

    final uri = Uri.parse(
      '$baseUrl/entities',
    ).replace(queryParameters: queryParams);

    // NOTE: http package does not automatically url encode query params correctly?
    // Uri.replace(queryParameters) DOES encode them.

    final response = await _client
        .get(
          uri,
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return EntityListResponse.fromMap(jsonMap);
  }

  Future<Entity> readEntity(int entityId, {int? version}) async {
    final queryParams = version != null
        ? {'version': version.toString()}
        : null;
    final uri = Uri.parse(
      '$baseUrl/entities/$entityId',
    ).replace(queryParameters: queryParams);

    final response = await _client
        .get(
          uri,
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return Entity.fromMap(jsonMap);
  }

  Future<List<EntityVersion>> getVersions(int entityId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/entities/$entityId/versions'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonList = await _handleResponse(response) as List<dynamic>;
    return jsonList
        .map((e) => EntityVersion.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Write operations

  Future<Entity> createEntity({
    required bool isCollection,
    String? label,
    String? description,
    int? parentId,
    String? imagePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/entities'),
    );
    request.headers.addAll(await _getHeaders());

    request.fields['is_collection'] = isCollection.toString().toLowerCase();
    if (label != null) request.fields['label'] = label;
    if (description != null) request.fields['description'] = description;
    if (parentId != null) request.fields['parent_id'] = parentId.toString();

    if (imagePath != null) {
      request.files.add(
        await HttpUtils.createMultipartFile('image', File(imagePath)),
      );
    }

    final streamResponse = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamResponse);
    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return Entity.fromMap(jsonMap);
  }

  Future<Entity> updateEntity(
    int entityId, {
    required bool isCollection,
    required String label,
    String? description,
    int? parentId,
    String? imagePath,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/entities/$entityId'),
    );
    request.headers.addAll(await _getHeaders());

    request.fields['is_collection'] = isCollection.toString().toLowerCase();
    request.fields['label'] = label;
    if (description != null) request.fields['description'] = description;
    if (parentId != null) request.fields['parent_id'] = parentId.toString();

    if (imagePath != null) {
      request.files.add(
        await HttpUtils.createMultipartFile('image', File(imagePath)),
      );
    }

    final streamResponse = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamResponse);
    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return Entity.fromMap(jsonMap);
  }

  Future<Entity> patchEntity(
    int entityId, {
    Object? label = const Unset(),
    Object? description = const Unset(),
    Object? isDeleted = const Unset(),
    Object? isCollection = const Unset(),
    Object? parentId = const Unset(),
  }) async {
    // Note: Use http.MultipartRequest for patching as server expects form data for some logic,
    // though usually PATCH can be json. Python SDK uses form data implicitly?
    // Python StoreClient docstring: "All write operations (create, update, patch, update_read_auth) use multipart/form-data, NOT JSON."
    // So we use MultipartRequest or just x-www-form-url-encoded if no file.
    // http.MultipartRequest works for both.

    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse('$baseUrl/entities/$entityId'),
    );
    request.headers.addAll(await _getHeaders());

    // We don't send file in patch usually.

    if (label is! Unset) {
      request.fields['label'] = label == null ? '' : label.toString();
    }
    if (description is! Unset) {
      request.fields['description'] = description == null
          ? ''
          : description.toString();
    }
    if (isDeleted is! Unset) {
      if (isDeleted != null) {
        request.fields['is_deleted'] = isDeleted.toString().toLowerCase();
      }
    }
    if (isCollection is! Unset) {
      if (isCollection != null) {
        request.fields['is_collection'] = isCollection.toString().toLowerCase();
      }
    }
    if (parentId is! Unset) {
      request.fields['parent_id'] = parentId == null ? '' : parentId.toString();
    }

    final streamResponse = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamResponse);
    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return Entity.fromMap(jsonMap);
  }

  Future<void> deleteEntity(int entityId) async {
    final response = await _client
        .delete(
          Uri.parse('$baseUrl/entities/$entityId'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    await _handleResponse(response);
  }

  Future<void> deleteAllEntities() async {
    final response = await _client
        .delete(
          Uri.parse('$baseUrl/entities'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    await _handleResponse(response);
  }

  // Admin operations

  Future<StoreConfig> getConfig() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/admin/config'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return StoreConfig.fromMap(jsonMap);
  }

  Future<StoreConfig> updateGuestMode({required bool guestMode}) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/admin/config/guest-mode'),
          body: {'guest_mode': guestMode.toString().toLowerCase()},
          headers: {
            ...(await _getHeaders()),
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        )
        .timeout(timeout);

    // Response might be empty or config? Python returns await get_config() after update.
    // Python code calls `get_config()` at the end.

    await _handleResponse(response);
    return getConfig();
  }

  Future<Map<String, dynamic>> getMInsightStatus() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/m_insight/status'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    return await _handleResponse(response) as Map<String, dynamic>;
  }

  // Intelligence operations

  Future<List<FaceResponse>> getEntityFaces(int entityId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/intelligence/entities/$entityId/faces'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonList = await _handleResponse(response) as List<dynamic>;
    return jsonList
        .map((e) => FaceResponse.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EntityJobResponse>> getEntityJobs(int entityId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/intelligence/entities/$entityId/jobs'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonList = await _handleResponse(response) as List<dynamic>;
    return jsonList
        .map((e) => EntityJobResponse.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<int>> downloadEntityClipEmbedding(int entityId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/intelligence/entities/$entityId/clip_embedding'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await _handleResponse(response); // Will throw
    throw Exception('Unreachable');
  }

  Future<List<int>> downloadEntityDinoEmbedding(int entityId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/intelligence/entities/$entityId/dino_embedding'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await _handleResponse(response); // Will throw
    throw Exception('Unreachable');
  }

  Future<List<int>> downloadFaceEmbedding(int faceId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/intelligence/faces/$faceId/embedding'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await _handleResponse(response); // Will throw
    throw Exception('Unreachable');
  }

  Future<List<KnownPersonResponse>> getKnownPersons() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/intelligence/known-persons'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonList = await _handleResponse(response) as List<dynamic>;
    return jsonList
        .map((e) => KnownPersonResponse.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<KnownPersonResponse> getKnownPerson(int personId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/intelligence/known-persons/$personId'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return KnownPersonResponse.fromMap(jsonMap);
  }

  Future<List<FaceResponse>> getPersonFaces(int personId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/intelligence/known-persons/$personId/faces'),
          headers: await _getHeaders(),
        )
        .timeout(timeout);

    final jsonList = await _handleResponse(response) as List<dynamic>;
    return jsonList
        .map((e) => FaceResponse.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<KnownPersonResponse> updateKnownPersonName(
    int personId,
    String name,
  ) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/intelligence/known-persons/$personId'),
          headers: {
            ...(await _getHeaders()),
            'Content-Type': 'application/json', // This one uses JSON!
          },
          body: json.encode({'name': name}),
        )
        .timeout(timeout);

    final jsonMap = await _handleResponse(response) as Map<String, dynamic>;
    return KnownPersonResponse.fromMap(jsonMap);
  }
}
