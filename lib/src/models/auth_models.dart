import 'dart:convert';

/// Response from /auth/token and /auth/token/refresh endpoints.
class TokenResponse {
  TokenResponse({
    required this.accessToken,
    required this.tokenType,
  });

  factory TokenResponse.fromMap(Map<String, dynamic> map) {
    return TokenResponse(
      accessToken: map['access_token'] as String,
      tokenType: map['token_type'] as String,
    );
  }

  factory TokenResponse.fromJson(String source) =>
      TokenResponse.fromMap(json.decode(source) as Map<String, dynamic>);

  /// JWT access token
  final String accessToken;

  /// Token type (always 'bearer')
  final String tokenType;

  Map<String, dynamic> toMap() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Response from /auth/public-key endpoint.
class PublicKeyResponse {
  PublicKeyResponse({
    required this.publicKey,
    required this.algorithm,
  });

  factory PublicKeyResponse.fromMap(Map<String, dynamic> map) {
    return PublicKeyResponse(
      publicKey: map['public_key'] as String,
      algorithm: map['algorithm'] as String,
    );
  }

  factory PublicKeyResponse.fromJson(String source) =>
      PublicKeyResponse.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Public key for token verification (PEM format)
  final String publicKey;

  /// JWT algorithm (ES256)
  final String algorithm;

  Map<String, dynamic> toMap() {
    return {
      'public_key': publicKey,
      'algorithm': algorithm,
    };
  }

  String toJson() => json.encode(toMap());
}

/// User information from /users/* endpoints.
class UserResponse {
  UserResponse({
    required this.id,
    required this.username,
    required this.createdAt,
    this.isAdmin = false,
    this.isActive = true,
    this.permissions = const [],
  });

  factory UserResponse.fromMap(Map<String, dynamic> map) {
    return UserResponse(
      id: map['id'] as int,
      username: map['username'] as String,
      isAdmin: map['is_admin'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      permissions: List<String>.from(map['permissions'] as List? ?? []),
    );
  }

  factory UserResponse.fromJson(String source) =>
      UserResponse.fromMap(json.decode(source) as Map<String, dynamic>);

  /// User ID
  final int id;

  /// Username
  final String username;

  /// Whether user has admin privileges
  final bool isAdmin;

  /// Whether user account is active
  final bool isActive;

  /// Account creation timestamp
  final DateTime createdAt;

  /// User permissions
  final List<String> permissions;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'is_admin': isAdmin,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'permissions': permissions,
    };
  }

  String toJson() => json.encode(toMap());
}

/// Request body for POST /users/.
class UserCreateRequest {
  UserCreateRequest({
    required this.username,
    required this.password,
    this.isAdmin = false,
    this.isActive = true,
    this.permissions = const [],
  });

  factory UserCreateRequest.fromMap(Map<String, dynamic> map) {
    return UserCreateRequest(
      username: map['username'] as String,
      password: map['password'] as String,
      isAdmin: map['is_admin'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
      permissions: List<String>.from(map['permissions'] as List? ?? []),
    );
  }

  factory UserCreateRequest.fromJson(String source) =>
      UserCreateRequest.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Username (must be unique)
  final String username;

  /// User password (will be hashed)
  final String password;

  /// Grant admin privileges
  final bool isAdmin;

  /// Set account active status
  final bool isActive;

  /// Initial permissions
  final List<String> permissions;

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'is_admin': isAdmin,
      'is_active': isActive,
      'permissions': permissions,
    };
  }

  /// Converts to API payload format where permissions are comma-separated string
  Map<String, dynamic> toApiPayload() {
    return {
      'username': username,
      'password': password,
      'is_admin': isAdmin,
      'is_active': isActive,
      'permissions': permissions.join(','),
    };
  }

  String toJson() => json.encode(toMap());
}

/// Request body for PUT /users/{user_id}.
class UserUpdateRequest {
  UserUpdateRequest({
    this.password,
    this.permissions,
    this.isActive,
    this.isAdmin,
  });

  factory UserUpdateRequest.fromMap(Map<String, dynamic> map) {
    return UserUpdateRequest(
      password: map['password'] as String?,
      permissions: map['permissions'] != null
          ? List<String>.from(map['permissions'] as List)
          : null,
      isActive: map['is_active'] as bool?,
      isAdmin: map['is_admin'] as bool?,
    );
  }

  factory UserUpdateRequest.fromJson(String source) =>
      UserUpdateRequest.fromMap(json.decode(source) as Map<String, dynamic>);

  /// New password (optional)
  final String? password;

  /// Update permissions (optional)
  final List<String>? permissions;

  /// Update active status (optional)
  final bool? isActive;

  /// Update admin status (optional)
  final bool? isAdmin;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (password != null) map['password'] = password;
    if (permissions != null) map['permissions'] = permissions;
    if (isActive != null) map['is_active'] = isActive;
    if (isAdmin != null) map['is_admin'] = isAdmin;
    return map;
  }

  /// Converts to API payload format
  Map<String, dynamic> toApiPayload() {
    final map = <String, dynamic>{};
    if (password != null) map['password'] = password;
    if (permissions != null) map['permissions'] = permissions!.join(',');
    if (isActive != null) map['is_active'] = isActive;
    if (isAdmin != null) map['is_admin'] = isAdmin;
    return map;
  }

  String toJson() => json.encode(toMap());
}
