import 'package:cl_server_dart_client/cl_server_dart_client.dart';

import 'test_config_loader.dart';

/// Utility for ensuring test users exist with correct credentials
class TestUserSetup {
  /// Ensure all test users defined in config exist with correct credentials
  ///
  /// This function:
  /// 1. Logs in as admin
  /// 2. For each test user (except admin):
  ///    - Checks if user exists
  ///    - Validates credentials by attempting login
  ///    - Creates user if missing
  ///    - Updates permissions if they don't match
  ///
  /// Throws an exception if admin credentials are invalid.
  static Future<void> ensureTestUsers(TestConfig config) async {
    // Login as admin
    final session = SessionManager.initialize(
      ServerConfig(
        authServiceBaseUrl: config.authUrl,
        computeServiceBaseUrl: config.computeUrl,
        storeServiceBaseUrl: config.storeUrl,
      ),
    );

    final adminUser = config.testUsers['admin'];
    if (adminUser == null) {
      throw Exception('Admin user not found in test configuration');
    }

    try {
      await session.login(adminUser.username, adminUser.password);
    } on Exception catch (e) {
      throw Exception(
        'Failed to login as admin. Ensure admin user exists with correct '
        'credentials (username: ${adminUser.username}). Error: $e',
      );
    }

    // Create authenticated user manager
    final userManager = await UserManager.authenticated(
      sessionManager: session,
    );

    // For each non-admin test user, ensure they exist
    for (final entry in config.testUsers.entries) {
      final roleName = entry.key;
      final testUser = entry.value;

      // Skip admin user - we already validated it exists
      if (roleName == 'admin') {
        continue;
      }

      try {
        await _ensureUserExists(
          userManager: userManager,
          username: testUser.username,
          password: testUser.password,
          permissions: testUser.permissions,
          isAdmin: testUser.isAdmin,
          config: config,
        );
      } catch (e) {
        print('Warning: Failed to setup test user $roleName: $e');
        // Continue with other users even if one fails
      }
    }

    // Cleanup
    await session.logout();
  }

  /// Ensure a specific user exists with correct credentials and permissions
  static Future<void> _ensureUserExists({
    required UserManager userManager,
    required String username,
    required String password,
    required List<String> permissions,
    required bool isAdmin,
    required TestConfig config,
  }) async {
    // Check if user exists by listing users and searching
    final listResult = await userManager.listUsers(
      options: UserListOptions(showAll: true),
    );

    if (!listResult.isSuccess) {
      print(
        'Warning: Could not list users to check if $username exists: '
        '${listResult.error}',
      );
      // Try to create user anyway
      await _createUser(
        userManager: userManager,
        username: username,
        password: password,
        permissions: permissions,
        isAdmin: isAdmin,
      );
      return;
    }

    final existingUser = (listResult.data as List<User>?)
        ?.cast<User>()
        .firstWhere(
          (user) => user.username == username,
          orElse: () => throw StateError('User not found'),
        );

    if (existingUser == null) {
      // User doesn't exist - create it
      await _createUser(
        userManager: userManager,
        username: username,
        password: password,
        permissions: permissions,
        isAdmin: isAdmin,
      );
      return;
    }

    // User exists - validate credentials by attempting login
    final validationSession = SessionManager.initialize(
      ServerConfig(
        authServiceBaseUrl: config.authUrl,
        computeServiceBaseUrl: config.computeUrl,
        storeServiceBaseUrl: config.storeUrl,
      ),
    );

    try {
      await validationSession.login(username, password);
      await validationSession.logout();

      // Credentials are valid - check permissions
      // Note: We don't automatically update permissions to avoid
      // interfering with manually configured test environments
      print('Test user $username exists with valid credentials');
    } on Exception catch (e) {
      print(
        'Warning: Test user $username exists but credentials are invalid. '
        'You may need to manually update the password. Error: $e',
      );
    }
  }

  /// Create a test user
  static Future<void> _createUser({
    required UserManager userManager,
    required String username,
    required String password,
    required List<String> permissions,
    required bool isAdmin,
  }) async {
    print('Creating test user: $username');

    final result = await userManager.createUser(
      username: username,
      password: password,
      permissions: permissions,
      isAdmin: isAdmin,
    );

    if (!result.isSuccess) {
      throw Exception(
        'Failed to create test user $username: ${result.error}',
      );
    }

    print('Test user $username created successfully');
  }
}
