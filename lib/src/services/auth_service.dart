import 'package:http/http.dart' as http;

import '../core/http_client.dart';
import '../core/models/auth_models.dart';
import '../utils/constants.dart';

/// Client for CL Server Authentication Service (Port 8000)
class AuthService {
  AuthService({
    String? baseUrl,
    this.token,
    http.Client? httpClient,
  }) : baseUrl = baseUrl ?? authServiceBaseUrl {
    _httpClient = HttpClientWrapper(
      baseUrl: this.baseUrl,
      token: token,
      httpClient: httpClient,
    );
  }
  final String baseUrl;
  final String? token;
  late final HttpClientWrapper _httpClient;

  /// Health check endpoint
  /// GET /
  Future<Map<String, dynamic>> healthCheck() async {
    return _httpClient.get(AuthServiceEndpoints.health);
  }

  /// Generate token (login)
  /// POST /auth/token
  Future<TokenResponse> generateToken({
    required String username,
    required String password,
  }) async {
    final response = await _httpClient.post(
      AuthServiceEndpoints.generateToken,
      body: {
        'username': username,
        'password': password,
      },
      isFormData: true,
    );
    return TokenResponse.fromJson(response);
  }

  /// Get public key for token verification
  /// GET /auth/public-key
  Future<PublicKeyResponse> getPublicKey() async {
    final response = await _httpClient.get(AuthServiceEndpoints.getPublicKey);
    return PublicKeyResponse.fromJson(response);
  }

  /// Refresh access token (requires valid token)
  /// POST /auth/token/refresh
  Future<TokenResponse> refreshToken() async {
    final response = await _httpClient.post(
      AuthServiceEndpoints.refreshToken,
    );
    return TokenResponse.fromJson(response);
  }

  /// Get current user info (requires token)
  /// GET /users/me
  Future<User> getCurrentUser() async {
    final response = await _httpClient.get(AuthServiceEndpoints.getCurrentUser);
    return User.fromJson(response);
  }

  /// List all users (requires token + admin privilege)
  /// GET /users/?skip=0&limit=100
  Future<List<User>> listUsers({
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _httpClient.get(
      AuthServiceEndpoints.listUsers,
      queryParameters: {
        QueryParameters.skip: skip.toString(),
        QueryParameters.limit: limit.toString(),
      },
    );

    // Response can be a direct list or wrapped in 'data' key
    final dynamic responseList = response is List ? response : response['data'];
    if (responseList is List) {
      return responseList
          .cast<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList();
    }

    return [];
  }

  /// Get user by ID (requires token + admin privilege)
  /// GET /users/{user_id}
  Future<User> getUser(int userId) async {
    final endpoint = AuthServiceEndpoints.getUser.replaceAll(
      '{user_id}',
      userId.toString(),
    );
    final response = await _httpClient.get(endpoint);
    return User.fromJson(response);
  }

  /// Create new user (requires token + admin privilege)
  /// POST /users/
  Future<User> createUser({
    required String username,
    required String password,
    bool isAdmin = false,
    List<String> permissions = const [],
  }) async {
    final body = {
      'username': username,
      'password': password,
      'is_admin': isAdmin,
      'permissions': permissions,
    };

    final response = await _httpClient.post(
      AuthServiceEndpoints.createUser,
      body: body,
    );
    return User.fromJson(response);
  }

  /// Update user (requires token + admin privilege)
  /// PUT /users/{user_id}
  Future<User> updateUser(
    int userId, {
    String? password,
    List<String>? permissions,
    bool? isActive,
    bool? isAdmin,
  }) async {
    final endpoint = AuthServiceEndpoints.updateUser.replaceAll(
      '{user_id}',
      userId.toString(),
    );

    final body = <String, dynamic>{};
    if (password != null) body['password'] = password;
    if (permissions != null) body['permissions'] = permissions;
    if (isActive != null) body['is_active'] = isActive;
    if (isAdmin != null) body['is_admin'] = isAdmin;

    final response = await _httpClient.put(
      endpoint,
      body: body,
    );
    return User.fromJson(response);
  }

  /// Delete user (requires token + admin privilege)
  /// DELETE /users/{user_id}
  Future<void> deleteUser(int userId) async {
    final endpoint = AuthServiceEndpoints.deleteUser.replaceAll(
      '{user_id}',
      userId.toString(),
    );
    await _httpClient.delete(endpoint);
  }
}
