import 'dart:convert';
import 'dart:io';

/// Test user credentials and permissions
class TestUser {
  const TestUser({
    required this.username,
    required this.password,
    required this.isAdmin,
    required this.permissions,
  });

  factory TestUser.fromJson(Map<String, dynamic> json) {
    return TestUser(
      username: json['username'] as String,
      password: json['password'] as String,
      isAdmin: json['is_admin'] as bool,
      permissions: (json['permissions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  final String username;
  final String password;
  final bool isAdmin;
  final List<String> permissions;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'is_admin': isAdmin,
      'permissions': permissions,
    };
  }
}

/// Test configuration loaded from test_config.json with environment overrides
class TestConfig {
  const TestConfig({
    required this.authUrl,
    required this.computeUrl,
    required this.storeUrl,
    required this.defaultAuthMode,
    required this.testUsers,
  });

  factory TestConfig.fromJson(Map<String, dynamic> json) {
    final testUsersMap = <String, TestUser>{};
    final usersJson = json['test_users'] as Map<String, dynamic>;

    for (final entry in usersJson.entries) {
      testUsersMap[entry.key] =
          TestUser.fromJson(entry.value as Map<String, dynamic>);
    }

    return TestConfig(
      authUrl: json['auth_url'] as String,
      computeUrl: json['compute_url'] as String,
      storeUrl: json['store_url'] as String,
      defaultAuthMode: json['default_auth_mode'] as String,
      testUsers: testUsersMap,
    );
  }

  final String authUrl;
  final String computeUrl;
  final String storeUrl;
  final String defaultAuthMode;
  final Map<String, TestUser> testUsers;

  /// Load config from test/config/test_config.json with environment variable overrides
  static Future<TestConfig> load() async {
    // Read config file
    final configFile = File('test/config/test_config.json');
    if (!await configFile.exists()) {
      throw Exception(
        'Test configuration file not found: ${configFile.path}',
      );
    }

    final contents = await configFile.readAsString();
    final json = jsonDecode(contents) as Map<String, dynamic>;

    // Apply environment variable overrides
    final authUrl = Platform.environment['TEST_AUTH_URL'] ??
        json['auth_url'] as String;
    final computeUrl = Platform.environment['TEST_COMPUTE_URL'] ??
        json['compute_url'] as String;
    final storeUrl = Platform.environment['TEST_STORE_URL'] ??
        json['store_url'] as String;

    // Load test users
    final testUsersMap = <String, TestUser>{};
    final usersJson = json['test_users'] as Map<String, dynamic>;

    for (final entry in usersJson.entries) {
      final userJson = entry.value as Map<String, dynamic>;

      // Override admin password from environment if set
      if (entry.key == 'admin') {
        final envPassword = Platform.environment['TEST_ADMIN_PASSWORD'];
        if (envPassword != null) {
          userJson['password'] = envPassword;
        }
      }

      testUsersMap[entry.key] = TestUser.fromJson(userJson);
    }

    return TestConfig(
      authUrl: authUrl,
      computeUrl: computeUrl,
      storeUrl: storeUrl,
      defaultAuthMode: json['default_auth_mode'] as String,
      testUsers: testUsersMap,
    );
  }

  Map<String, dynamic> toJson() {
    final usersJson = <String, dynamic>{};
    for (final entry in testUsers.entries) {
      usersJson[entry.key] = entry.value.toJson();
    }

    return {
      'auth_url': authUrl,
      'compute_url': computeUrl,
      'store_url': storeUrl,
      'default_auth_mode': defaultAuthMode,
      'test_users': usersJson,
    };
  }
}
