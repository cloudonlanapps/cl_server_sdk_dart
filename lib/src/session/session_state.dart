import 'package:meta/meta.dart';

/// Enumeration for token refresh strategies
enum TokenRefreshStrategy {
  /// Refresh token using dedicated /auth/token/refresh endpoint
  refreshEndpoint,

  /// Re-login using stored encrypted password (fallback)
  reLogin,
}

/// Immutable session state model
///
/// Holds the current authentication state: whether user is logged in,
/// their username, their JWT token, any error messages, and when the
/// token was last refreshed.
@immutable
class SessionState {
  /// Create a new session state
  const SessionState({
    required this.isLoggedIn,
    this.username,
    this.token,
    this.error,
    this.lastRefreshTime,
  });

  /// True if user is currently logged in
  final bool isLoggedIn;

  /// Username of logged-in user (stored for UI display)
  final String? username;

  /// JWT access token (null if not logged in)
  final String? token;

  /// Last error message (if any)
  final String? error;

  /// When the token was last refreshed or obtained
  final DateTime? lastRefreshTime;

  /// Create a copy with optional field overrides
  SessionState copyWith({
    bool? isLoggedIn,
    String? username,
    String? token,
    String? error,
    DateTime? lastRefreshTime,
  }) {
    return SessionState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
      token: token ?? this.token,
      error: error ?? this.error,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          runtimeType == other.runtimeType &&
          isLoggedIn == other.isLoggedIn &&
          username == other.username &&
          token == other.token &&
          error == other.error &&
          lastRefreshTime == other.lastRefreshTime;

  @override
  int get hashCode =>
      isLoggedIn.hashCode ^
      username.hashCode ^
      token.hashCode ^
      error.hashCode ^
      lastRefreshTime.hashCode;

  @override
  String toString() =>
      'SessionState('
      'isLoggedIn: $isLoggedIn, '
      'username: $username, '
      // ignore: lines_longer_than_80_chars lets look into this later
      'token: ${token != null ? '${token!.length > 20 ? token!.substring(0, 20) : token}...' : 'null'}, '
      'error: $error, '
      'lastRefreshTime: $lastRefreshTime)';
}
