import 'dart:async';
import 'dart:convert';

/// Abstract base class for auth providers.
abstract class AuthProvider {
  /// Get authentication headers for HTTP requests.
  Map<String, String> getHeaders();

  /// Refresh token if needed (async).
  Future<void> refreshTokenIfNeeded() async {}
}

/// No authentication (Phase 1).
class NoAuthProvider extends AuthProvider {
  @override
  Map<String, String> getHeaders() => {};
}

/// JWT token authentication with automatic refresh support.
///
/// Supports two modes:
/// 1. Direct token mode: Initialized with a static token string
/// 2. SessionManager mode: Integrated with SessionManager for automatic token refresh
class JWTAuthProvider extends AuthProvider {
  JWTAuthProvider({
    String? token,
    this.getCachedToken,
    this.getValidTokenAsync,
  }) : _token = token {
    if (_token == null && getCachedToken == null) {
      throw ArgumentError('Either token or getCachedToken must be provided');
    }
  }
  final String? _token;
  final String Function()? getCachedToken;
  final Future<String> Function()? getValidTokenAsync;

  /// Parse JWT token to extract expiry time.
  DateTime? _parseTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      var payload = parts[1];
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          payload += '==';
        case 3:
          payload += '=';
        default:
          return null;
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final payloadMap = json.decode(decoded) as Map<String, dynamic>;

      final exp = payloadMap['exp'];
      if (exp == null) return null;

      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      } else if (exp is double) {
        return DateTime.fromMillisecondsSinceEpoch(
          (exp * 1000).round(),
          isUtc: true,
        );
      }
      return null;
    } on Object catch (_) {
      return null;
    }
  }

  /// Check if token should be refreshed (< 60 seconds until expiry).
  bool shouldRefresh(String token) {
    final expiry = _parseTokenExpiry(token);
    if (expiry == null) {
      return false;
    }

    final now = DateTime.now().toUtc();
    final timeUntilExpiry = expiry.difference(now);

    return timeUntilExpiry.inSeconds < 60;
  }

  String getToken() {
    if (_token != null) {
      return _token;
    }
    if (getCachedToken != null) {
      return getCachedToken!();
    }
    throw StateError('No token available');
  }

  @override
  Future<void> refreshTokenIfNeeded() async {
    if (getValidTokenAsync != null) {
      try {
        await getValidTokenAsync!();
      } catch (e) {
        // SessionManager should handle re-login logic.
        rethrow;
      }
    }
  }

  @override
  Map<String, String> getHeaders() {
    final token = getToken();
    return {'Authorization': 'Bearer $token'};
  }
}

/// Get default auth provider (no-auth for Phase 1).
AuthProvider getDefaultAuth() {
  return NoAuthProvider();
}
