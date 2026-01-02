import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../session/session_manager.dart';
import 'commands/create_user.dart';
import 'commands/delete_user.dart';
import 'commands/get_store_config.dart';
import 'commands/get_user.dart';
import 'commands/get_user_permissions.dart';
import 'commands/list_users.dart';
import 'commands/update_read_auth.dart';
import 'commands/update_user.dart';
import 'models/result_model.dart';
import 'models/user_filter.dart';

/// User Manager module for managing user operations
///
/// Provides both authenticated modes through SessionManager.
/// All operations require admin authentication.
///
/// Example:
/// ```dart
/// final sessionManager = await SessionManager.initialize();
/// await sessionManager.login('admin', 'password');
/// final manager = await UserManager.authenticated(
///   sessionManager: sessionManager,
/// );
/// final result = await manager.createUser(
///   username: 'alice',
///   password: 'pass123',
/// );
/// ```
class UserManager {
  UserManager({
    required AuthService authService,
    required StoreService storeService,
    String prefix = 't#',
  }) : _authService = authService,
       _storeService = storeService,
       _prefix = prefix;

  final AuthService _authService;
  final StoreService _storeService;
  final String _prefix;

  /// Create authenticated mode user manager
  ///
  /// Requires an authenticated SessionManager instance.
  /// [sessionManager] - Authenticated session manager
  /// [prefix] - User prefix for this utility (default: 't#')
  ///
  /// Returns UserManager instance with authenticated services
  static Future<UserManager> authenticated({
    required SessionManager sessionManager,
    String prefix = 't#',
  }) async {
    final authService = await sessionManager.createAuthService();
    final storeService = await sessionManager.createStoreService();
    return UserManager(
      authService: authService,
      storeService: storeService,
      prefix: prefix,
    );
  }

  /// Create a new user
  ///
  /// [username] - Username (will be prefixed internally)
  /// [password] - User password
  /// [isAdmin] - Whether user is admin (default: false)
  /// [permissions] - Optional list of permissions
  ///
  /// Returns UserOperationResult with created user or error
  Future<UserOperationResult<dynamic>> createUser({
    required String username,
    required String password,
    bool isAdmin = false,
    List<String>? permissions,
  }) => CreateUserCommand(_authService, _prefix).execute(
    username: username,
    password: password,
    isAdmin: isAdmin,
    permissions: permissions,
  );

  /// Get a single user by ID
  ///
  /// [userId] - ID of user to retrieve
  ///
  /// Returns UserOperationResult with user details or error
  Future<UserOperationResult<dynamic>> getUser({
    required int userId,
  }) => GetUserCommand(_authService).execute(userId: userId);

  /// List users with optional filtering
  ///
  /// [options] - Filtering and pagination options
  ///
  /// Returns UserOperationResult with list of users or error
  Future<UserOperationResult<dynamic>> listUsers({
    UserListOptions? options,
  }) => ListUsersCommand(_authService, _prefix).execute(
    options: options ?? UserListOptions(),
  );

  /// Update a user (partial updates allowed)
  ///
  /// [userId] - ID of user to update
  /// [password] - New password (optional)
  /// [permissions] - New permissions (optional)
  /// [isAdmin] - Update admin status (optional)
  /// [isActive] - Update active status (optional)
  ///
  /// Returns UserOperationResult with updated user or error
  Future<UserOperationResult<dynamic>> updateUser({
    required int userId,
    String? password,
    List<String>? permissions,
    bool? isAdmin,
    bool? isActive,
  }) => UpdateUserCommand(_authService).execute(
    userId: userId,
    password: password,
    permissions: permissions,
    isAdmin: isAdmin,
    isActive: isActive,
  );

  /// Delete a user by ID
  ///
  /// [userId] - ID of user to delete
  ///
  /// Returns UserOperationResult with success message or error
  Future<UserOperationResult<void>> deleteUser({
    required int userId,
  }) => DeleteUserCommand(_authService).execute(userId: userId);

  /// Get permissions for a user
  ///
  /// [userId] - ID of user to get permissions for
  ///
  /// Returns UserOperationResult with list of permissions or error
  Future<UserOperationResult<dynamic>> getUserPermissions({
    required int userId,
  }) => GetUserPermissionsCommand(_authService).execute(userId: userId);

  /// Get store configuration
  ///
  /// Returns UserOperationResult with store config or error
  Future<UserOperationResult<dynamic>> getStoreConfig() =>
      GetStoreConfigCommand(_storeService).execute();

  /// Update store read authentication configuration
  ///
  /// [enabled] - Whether to enable read authentication
  ///
  /// Returns UserOperationResult with updated config or error
  Future<UserOperationResult<dynamic>> updateReadAuth({
    required bool enabled,
  }) => UpdateReadAuthCommand(_storeService).execute(enabled: enabled);
}
