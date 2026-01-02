import 'dart:io';

import 'server_capabilities.dart';
import 'test_config_loader.dart';

/// Authentication modes for testing
enum AuthMode {
  noAuth('no-auth'),
  admin('admin'),
  userWithPermission('user-with-permission'),
  userNoPermission('user-no-permission');

  const AuthMode(this.value);
  final String value;

  static AuthMode fromString(String value) {
    return AuthMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => throw ArgumentError('Invalid auth mode: $value'),
    );
  }
}

/// Authentication context for parametrized tests
class AuthTestContext {
  const AuthTestContext({
    required this.mode,
    required this.authUrl,
    required this.computeUrl,
    required this.storeUrl,
    required this.serverAuthEnabled,
    required this.storeGuestMode,
    this.username,
    this.password,
    required this.isAdmin,
    required this.permissions,
  });

  final AuthMode mode;
  final String authUrl;
  final String computeUrl;
  final String storeUrl;
  final bool serverAuthEnabled;
  final String storeGuestMode;
  final String? username;
  final String? password;
  final bool isAdmin;
  final List<String> permissions;

  /// Whether this context has any permissions
  bool get hasPermissions => isAdmin || permissions.isNotEmpty;

  /// Whether requests should fail with auth error
  bool get shouldFailWithAuthError {
    if (mode == AuthMode.noAuth && serverAuthEnabled) {
      return true; // Server requires auth but we have no credentials
    }
    return false;
  }

  /// Create auth context for a specific mode
  factory AuthTestContext.forMode({
    required AuthMode mode,
    required ServerCapabilities capabilities,
    required TestConfig config,
  }) {
    String? username;
    String? password;
    bool isAdmin = false;
    List<String> permissions = [];

    if (mode != AuthMode.noAuth) {
      final user = config.testUsers[mode.value];
      if (user == null) {
        throw ArgumentError('Test user not found for mode: ${mode.value}');
      }

      username = user.username;
      password = user.password;
      isAdmin = user.isAdmin;
      permissions = List.from(user.permissions);
    }

    return AuthTestContext(
      mode: mode,
      authUrl: config.authUrl,
      computeUrl: config.computeUrl,
      storeUrl: config.storeUrl,
      serverAuthEnabled: capabilities.authRequired,
      storeGuestMode: capabilities.guestMode,
      username: username,
      password: password,
      isAdmin: isAdmin,
      permissions: permissions,
    );
  }

  /// Get current auth mode from environment or use default
  static Future<AuthMode> getCurrentMode(TestConfig config) async {
    final envMode = Platform.environment['TEST_AUTH_MODE'];
    if (envMode != null && envMode.isNotEmpty) {
      try {
        return AuthMode.fromString(envMode);
      } catch (e) {
        print('Warning: Invalid TEST_AUTH_MODE: $envMode, using default');
      }
    }

    // Use default from config
    return AuthMode.fromString(config.defaultAuthMode);
  }

  @override
  String toString() {
    return 'AuthTestContext('
        'mode: ${mode.value}, '
        'user: ${username ?? "none"}, '
        'isAdmin: $isAdmin, '
        'permissions: $permissions, '
        'serverAuth: $serverAuthEnabled, '
        'storeGuest: $storeGuestMode'
        ')';
  }
}
