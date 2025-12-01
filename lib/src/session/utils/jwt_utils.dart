import 'dart:convert';

/// Parsed JWT payload containing token claims
class JwtPayload {
  const JwtPayload({
    this.expiresAt,
    this.userId,
    this.permissions = const [],
    this.isAdmin = false,
  });

  /// Token expiry time as Unix timestamp (seconds since epoch)
  final int? expiresAt;

  /// User ID from 'sub' claim
  final String? userId;

  /// User permissions from 'permissions' claim
  final List<String> permissions;

  /// Admin flag from 'is_admin' claim
  final bool isAdmin;

  /// Check if token is expired
  bool get isExpired {
    if (expiresAt == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= expiresAt!;
  }

  /// Check if token expires within given duration
  bool expiresWithin(Duration duration) {
    if (expiresAt == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final threshold = now + duration.inSeconds;
    return expiresAt! <= threshold;
  }

  /// Get remaining time before expiry
  Duration? get timeRemaining {
    if (expiresAt == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = expiresAt! - now;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: remaining);
  }
}

/// Utility class for parsing JWT tokens without verification
///
/// JWT tokens are signed by the server, so we don't verify the signature
/// on the client. We only decode the payload to extract the expiry claim
/// ('exp') for token refresh logic.
class JwtUtils {
  /// Parse JWT token and extract payload (no verification)
  ///
  /// JWT format: header.payload.signature
  /// We only decode payload without verifying signature
  /// (Server already verified token via 401/403 responses)
  ///
  /// Returns null if token format is invalid.
  static JwtPayload? parseToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode payload (base64url)
      final payload = parts[1];
      // Normalize base64url to base64 and add padding as needed
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final padding = (4 - normalized.length % 4) % 4;
      final padded = normalized + ('=' * padding);
      final decoded = utf8.decode(base64.decode(padded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      return JwtPayload(
        expiresAt: json['exp'] as int?,
        userId: json['sub'] as String?,
        permissions: List<String>.from(json['permissions'] as List? ?? []),
        isAdmin: json['is_admin'] as bool? ?? false,
      );
    } on Exception {
      // Invalid token format, return null
      return null;
    }
  }

  /// Check if token string is valid JWT format (basic structure check)
  static bool isValidJwtFormat(String token) {
    try {
      final parts = token.split('.');
      return parts.length == 3 && parts.every((part) => part.isNotEmpty);
    } on Exception {
      return false;
    }
  }
}
