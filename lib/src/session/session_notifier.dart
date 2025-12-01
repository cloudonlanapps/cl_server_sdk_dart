import 'dart:async';

import 'package:solidart/solidart.dart';

import '../core/exceptions.dart';
import '../services/auth_service.dart';
import 'session_exceptions.dart';
import 'session_state.dart';
import 'token_storage.dart';
import 'utils/jwt_utils.dart';

/// Manages authentication session state using Solidart signals
///
/// This notifier handles:
/// - Login/logout with persistent token storage
/// - Automatic token refresh before expiry
/// - Secure password storage (optional, for re-login strategy)
/// - Reactive state updates via Solidart signals
class SessionNotifier {
  /// Create a new session notifier
  SessionNotifier({
    required AuthService authService,
    required TokenStorage storage,
    this.refreshStrategy = TokenRefreshStrategy.refreshEndpoint,
  }) : _authService = authService,
       _storage = storage;
  final AuthService _authService;
  final TokenStorage _storage;
  TokenRefreshStrategy refreshStrategy;

  /// Core signal holding current session state
  late final Signal<SessionState> sessionSignal = Signal<SessionState>(
    const SessionState(isLoggedIn: false),
  );

  /// Computed signal for checking if token is expired
  /// Re-computes whenever sessionSignal changes
  late final Computed<bool> isTokenExpired = Computed(() {
    final token = sessionSignal.value.token;
    if (token == null) return true;

    // Parse JWT token to get actual expiry from 'exp' claim
    final payload = JwtUtils.parseToken(token);
    if (payload == null) return true;

    // Check if token expires within 1 minute (refresh threshold)
    return payload.expiresWithin(const Duration(minutes: 1));
  });

  /// Effect: Auto-refresh token when needed
  /// Runs whenever sessionSignal or isTokenExpired changes
  // ignore: unused_field
  late final void Function() _autoRefreshEffect = Effect(
    (dispose) {
      if (sessionSignal.value.isLoggedIn && isTokenExpired.value) {
        // Trigger auto-refresh asynchronously without awaiting
        unawaited(_triggerAutoRefresh());
      }
    },
  ).call;

  /// Initialize session from persistent storage on app startup
  Future<void> initialize() async {
    try {
      final hasToken = await _storage.hasToken();
      if (hasToken) {
        final token = await _storage.getToken();
        final username = await _storage.getUsername();
        final refreshTime = await _storage.getLastRefreshTime();

        if (token != null && username != null) {
          sessionSignal.value = SessionState(
            isLoggedIn: true,
            username: username,
            token: token,
            lastRefreshTime: refreshTime,
          );
        }
      }
    } on Exception catch (e) {
      sessionSignal.value = sessionSignal.value.copyWith(
        error: 'Failed to initialize session: $e',
      );
    }
  }

  /// Login user with username and password
  Future<void> login(
    String username,
    String password, {
    String? baseUrl,
  }) async {
    try {
      final authService = AuthService(baseUrl: baseUrl);
      final tokenResponse = await authService.generateToken(
        username: username,
        password: password,
      );

      // Store token and username
      await _storage.saveToken(username, tokenResponse.accessToken);

      // Optionally store encrypted password for re-login strategy
      if (refreshStrategy == TokenRefreshStrategy.reLogin) {
        await _storage.saveEncryptedPassword(username, password);
      }

      await _storage.updateRefreshTime();

      // Update signal
      sessionSignal.value = SessionState(
        isLoggedIn: true,
        username: username,
        token: tokenResponse.accessToken,
        lastRefreshTime: DateTime.now(),
      );
    } on CLServerException catch (e) {
      sessionSignal.value = sessionSignal.value.copyWith(
        error: e.message,
      );
      rethrow;
    } catch (e) {
      sessionSignal.value = sessionSignal.value.copyWith(
        error: 'Login failed: $e',
      );
      rethrow;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      await _storage.clearToken();
      sessionSignal.value = const SessionState(isLoggedIn: false);
    } catch (e) {
      sessionSignal.value = sessionSignal.value.copyWith(
        error: 'Logout failed: $e',
      );
      rethrow;
    }
  }

  /// Refresh token before it expires
  Future<void> refreshToken({bool forceRefresh = false}) async {
    if (!sessionSignal.value.isLoggedIn) {
      throw NotLoggedInException();
    }

    if (!forceRefresh && !isTokenExpired.value) {
      return; // Token still valid, no need to refresh
    }

    try {
      final tokenResponse = await _authService.refreshToken();

      await _storage.updateToken(tokenResponse.accessToken);
      await _storage.updateRefreshTime();

      sessionSignal.value = sessionSignal.value.copyWith(
        token: tokenResponse.accessToken,
        lastRefreshTime: DateTime.now(),
      );
    } on AuthException catch (e) {
      // Token invalid, logout user
      await logout();
      throw RefreshFailedException(e.message);
    } catch (e) {
      throw RefreshFailedException('$e');
    }
  }

  /// Get valid token, auto-refreshing if needed
  Future<String> getValidToken() async {
    if (!sessionSignal.value.isLoggedIn) {
      throw NotLoggedInException();
    }

    final token = sessionSignal.value.token;
    if (token == null) {
      throw NotLoggedInException();
    }

    // Check if refresh needed before returning
    if (isTokenExpired.value) {
      await refreshToken();
    }

    return sessionSignal.value.token!;
  }

  /// Get current session state
  SessionState get currentState => sessionSignal.value;

  /// Check if user is logged in
  bool get isLoggedIn => sessionSignal.value.isLoggedIn;

  /// Get current username
  String? get currentUsername => sessionSignal.value.username;

  /// Trigger auto-refresh (called by Effect)
  Future<void> _triggerAutoRefresh() async {
    // Call refresh asynchronously without awaiting
    // This allows the Effect to complete without blocking
    await refreshToken();
  }
}
