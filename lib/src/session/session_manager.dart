import 'package:solidart/solidart.dart';

import '../core/server_config.dart';
import '../services/auth_service.dart';
import '../services/compute_service.dart';
import '../services/store_service.dart';
import 'session_notifier.dart';
import 'session_state.dart';
import 'token_storage.dart';

/// High-level API for session management
///
/// Provides convenient methods for login/logout and creates
/// pre-authenticated service instances that automatically inject tokens.
///
/// Usage:
/// ```dart
/// final manager = SessionManager.initialize();
/// await manager.login('username', 'password');
/// final storeService = await manager.createStoreService();
/// await storeService.listEntities();
/// ```
class SessionManager {
  /// Private constructor
  SessionManager._({
    required SessionNotifier notifier,
    required TokenStorage storage,
    required ServerConfig serverConfig,
  }) : _notifier = notifier,
       _storage = storage,
       _serverConfig = serverConfig;

  /// Factory to initialize SessionManager with dependencies
  factory SessionManager.initialize(ServerConfig serverConfig) {
    final storage = TokenStorage();
    final authService = AuthService(serverConfig.authServiceBaseUrl);
    final notifier = SessionNotifier(
      authService: authService,
      storage: storage,
    );

    return SessionManager._(
      notifier: notifier,
      storage: storage,
      serverConfig: serverConfig,
    );
  }
  final SessionNotifier _notifier;
  final TokenStorage _storage;
  final ServerConfig _serverConfig;

  /// Login user with username and password
  Future<void> login(
    String username,
    String password,
  ) async {
    await _notifier.login(
      username,
      password,
      baseUrl: _serverConfig.authServiceBaseUrl,
    );
  }

  /// Logout current user and clear session data
  Future<void> logout() async {
    await _notifier.logout();
  }

  /// Refresh current token
  Future<void> refreshToken({bool forceRefresh = false}) async {
    await _notifier.refreshToken(forceRefresh: forceRefresh);
  }

  /// Get a valid token, auto-refreshing if needed
  Future<String> getValidToken() async {
    return _notifier.getValidToken();
  }

  /// Get current token refresh strategy
  TokenRefreshStrategy get refreshStrategy => _notifier.refreshStrategy;

  /// Set token refresh strategy
  set refreshStrategy(TokenRefreshStrategy strategy) {
    _notifier.refreshStrategy = strategy;
  }

  /// Create a pre-authenticated StoreService
  Future<StoreService> createStoreService() async {
    final token = await getValidToken();
    return StoreService(_serverConfig.storeServiceBaseUrl, token: token);
  }

  /// Create a pre-authenticated ComputeService
  Future<ComputeService> createComputeService() async {
    final token = await getValidToken();
    return ComputeService(
      _serverConfig.getComputeServiceBaseUrl(),
      token: token,
    );
  }

  /// Create a pre-authenticated AuthService
  Future<AuthService> createAuthService() async {
    final token = await getValidToken();
    return AuthService(_serverConfig.authServiceBaseUrl, token: token);
  }

  // Accessors for session state

  /// Check if user is logged in
  bool get isLoggedIn => _notifier.isLoggedIn;

  /// Get current logged-in username
  String? get currentUsername => _notifier.currentUsername;

  /// Get current session state
  SessionState get currentState => _notifier.currentState;

  /// Get signal for reactive updates
  Signal<SessionState> get sessionSignal => _notifier.sessionSignal;

  /// Listen to session state changes
  void onSessionStateChanged(void Function(SessionState) callback) {
    Effect((_) {
      callback(_notifier.sessionSignal.value);
    });
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _storage.clearToken();
  }
}
