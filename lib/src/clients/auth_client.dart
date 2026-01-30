import 'dart:convert';

import 'package:http/http.dart' as http;

import '../exceptions.dart';
import '../models/auth_models.dart';
import '../server_config.dart';

/// Low-level client for auth service REST API.
class AuthClient {
  AuthClient({
    String? baseUrl,
    ServerConfig? serverConfig,
    this.timeout = const Duration(seconds: 60),
    http.Client? client,
  }) : baseUrl = baseUrl ?? (serverConfig ?? ServerConfig.fromEnv()).authUrl,
       _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  /// Close HTTP client resources.
  void close() {
    _client.close();
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return json.decode(response.body);
      }
      return null;
    } else if (response.statusCode == 400) {
      throw ValidationError(response.body);
    } else if (response.statusCode == 401) {
      throw AuthenticationError();
    } else if (response.statusCode == 403) {
      throw PermissionError();
    } else if (response.statusCode == 404) {
      throw NotFoundError(response.body);
    } else {
      throw ComputeClientError('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // ========================================================================
  // Token Management
  // ========================================================================

  /// Login with username and password.
  Future<TokenResponse> login(String username, String password) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'username': username, 'password': password},
        )
        .timeout(timeout);

    final json = await _handleResponse(response);
    return TokenResponse.fromMap(json as Map<String, dynamic>);
  }

  /// Refresh access token.
  Future<TokenResponse> refreshToken(String token) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/token/refresh'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(timeout);

    final json = await _handleResponse(response);
    return TokenResponse.fromMap(json as Map<String, dynamic>);
  }

  /// Get public key for token verification.
  Future<PublicKeyResponse> getPublicKey() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/auth/public-key'),
        )
        .timeout(timeout);

    final json = await _handleResponse(response);
    return PublicKeyResponse.fromMap(json as Map<String, dynamic>);
  }

  // ========================================================================
  // User Management
  // ========================================================================

  /// Get current authenticated user info.
  Future<UserResponse> getCurrentUser(String token) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(timeout);

    final json = await _handleResponse(response);
    return UserResponse.fromMap(json as Map<String, dynamic>);
  }

  // ========================================================================
  // Admin User Management
  // ========================================================================

  /// Create new user (admin only).
  Future<UserResponse> createUser(
    String token,
    UserCreateRequest userCreate,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/users/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: userCreate.toApiPayload().map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        )
        .timeout(timeout);

    final json = await _handleResponse(response);
    return UserResponse.fromMap(json as Map<String, dynamic>);
  }

  /// List all users (admin only).
  Future<List<UserResponse>> listUsers(
    String token, {
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/users/').replace(
            queryParameters: {
              'skip': skip.toString(),
              'limit': limit.toString(),
            },
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(timeout);

    final jsonList = (await _handleResponse(response)) as List<dynamic>;
    return jsonList
        .map((e) => UserResponse.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Get user by ID (admin only).
  Future<UserResponse> getUser(String token, int userId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/users/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(timeout);

    final json = await _handleResponse(response);
    return UserResponse.fromMap(json as Map<String, dynamic>);
  }

  /// Update user (admin only).
  Future<UserResponse> updateUser(
    String token,
    int userId,
    UserUpdateRequest userUpdate,
  ) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/users/$userId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: userUpdate.toApiPayload().map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        )
        .timeout(timeout);

    final json = await _handleResponse(response);
    return UserResponse.fromMap(json as Map<String, dynamic>);
  }

  /// Delete user (admin only).
  Future<void> deleteUser(String token, int userId) async {
    final response = await _client
        .delete(
          Uri.parse('$baseUrl/users/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(timeout);

    await _handleResponse(response);
  }
}
