import 'dart:async';

import 'auth.dart';
import 'clients/auth_client.dart';
import 'clients/compute_client.dart';
import 'managers/store_manager.dart';
import 'models/auth_models.dart';
import 'mqtt_monitor.dart';
import 'server_config.dart';

/// High-level session management for authentication.
class SessionManager {
  SessionManager({
    String? baseUrl,
    ServerConfig? serverConfig,
    AuthClient? authClient,
  }) : _config = serverConfig ?? ServerConfig.fromEnv(),
       _authClient =
           authClient ??
           AuthClient(
             baseUrl: baseUrl,
             serverConfig: serverConfig ?? ServerConfig.fromEnv(),
           );
  final ServerConfig _config;
  final AuthClient _authClient;

  String? _currentToken;
  UserResponse? _currentUser;

  ServerConfig get serverConfig => _config;
  AuthClient get authClient => _authClient;

  // Auth Lifecycle

  Future<TokenResponse> login(String username, String password) async {
    final tokenResponse = await _authClient.login(username, password);

    _currentToken = tokenResponse.accessToken;
    try {
      _currentUser = await _authClient.getCurrentUser(_currentToken!);
    } on Object catch (_) {
      // Ignore if fetch user fails, just login success
    }

    return tokenResponse;
  }

  Future<void> logout() async {
    _currentToken = null;
    _currentUser = null;
  }

  bool get isAuthenticated => _currentToken != null;

  Future<UserResponse?> getCurrentUser() async {
    if (!isAuthenticated) return null;

    if (_currentUser != null) return _currentUser;

    return _currentUser = await _authClient.getCurrentUser(_currentToken!);
  }

  // Token Management

  String getToken() {
    if (_currentToken == null) {
      throw StateError('Not authenticated - call login() first');
    }
    return _currentToken!;
  }

  Future<String> getValidToken() async {
    if (_currentToken == null) {
      throw StateError('Not authenticated - call login() first');
    }

    final provider = JWTAuthProvider(token: _currentToken);
    if (provider.shouldRefresh(_currentToken!)) {
      try {
        final response = await _authClient.refreshToken(_currentToken!);
        _currentToken = response.accessToken;
      } on Object catch (_) {
        // Refresh failed? Token might be invalid or network error.
        // Retain old token? Or throw?
      }
    }

    return _currentToken!;
  }

  // Factories

  ComputeClient createComputeClient({MQTTJobMonitor? mqttMonitor}) {
    AuthProvider authProvider;
    if (isAuthenticated) {
      authProvider = JWTAuthProvider(
        getCachedToken: getToken,
        getValidTokenAsync: getValidToken,
      );
    } else {
      authProvider = NoAuthProvider();
    }

    return ComputeClient(
      baseUrl: _config.computeUrl,
      mqttUrl: _config.mqttUrl,
      authProvider: authProvider,
      serverConfig: _config,
      mqttMonitor: mqttMonitor,
    );
  }

  StoreManager createStoreManager({
    Duration timeout = const Duration(seconds: 30),
  }) {
    if (!isAuthenticated) {
      throw StateError('Not authenticated. Call login() first.');
    }

    return StoreManager.authenticated(
      config: _config,
      getCachedToken: getToken,
      getValidTokenAsync: getValidToken,
      baseUrl: _config.storeUrl,
      timeout: timeout,
    );
  }

  Future<void> close() async {
    _authClient.close();
  }
}
