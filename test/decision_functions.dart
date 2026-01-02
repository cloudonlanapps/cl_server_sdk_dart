import 'auth_test_context.dart';

/// Type of operation being tested
enum OperationType {
  /// Compute plugin operations (job submission)
  plugin,

  /// Admin operations (user management, config)
  admin,

  /// Store read operations (list, get entities)
  storeRead,

  /// Store write operations (create, update, delete entities)
  storeWrite,
}

/// Determine if an operation should succeed based on auth context
///
/// This function encapsulates the authorization logic for all operations
/// across different auth modes and server configurations.
///
/// Returns `true` if the operation is expected to succeed, `false` if it
/// should fail with an authorization error.
bool shouldSucceed(AuthTestContext context, OperationType operation) {
  switch (operation) {
    case OperationType.storeRead:
      // Store read logic
      // Guest mode enabled - everyone can read (public access)
      if (context.storeGuestMode == 'on') {
        return true;
      }

      // Guest mode disabled - need authentication + permission
      if (context.mode == AuthMode.noAuth) {
        return false; // No credentials provided
      }

      // Authenticated - check permission
      return context.isAdmin ||
          context.permissions.contains('media_store_read');

    case OperationType.storeWrite:
      // Store write logic (always requires auth)
      if (context.mode == AuthMode.noAuth) {
        return false; // Write always needs authentication
      }

      // Authenticated - check permission
      return context.isAdmin ||
          context.permissions.contains('media_store_write');

    case OperationType.admin:
      // Admin operations logic
      if (context.shouldFailWithAuthError) {
        return false; // Server requires auth but we have no credentials
      }

      // Must be admin user
      return context.isAdmin;

    case OperationType.plugin:
      // Compute plugin logic
      if (context.shouldFailWithAuthError) {
        return false; // Server requires auth but we have no credentials
      }

      // If server requires auth, check permissions
      if (context.serverAuthEnabled) {
        return context.hasPermissions;
      }

      // Server doesn't require auth - all operations succeed
      return true;
  }
}

/// Get expected HTTP error code for failed operations
///
/// Returns:
/// - `401` (Unauthorized) if no authentication provided when required
/// - `403` (Forbidden) if authenticated but lacking permissions
/// - `null` if operation is expected to succeed
int? getExpectedError(AuthTestContext context, OperationType operation) {
  // If operation should succeed, no error expected
  if (shouldSucceed(context, operation)) {
    return null;
  }

  switch (operation) {
    case OperationType.storeRead:
      // Guest mode disabled and no auth
      if (context.mode == AuthMode.noAuth) {
        return 401; // No credentials provided
      }
      // Authenticated but no permission
      return 403;

    case OperationType.storeWrite:
      // No auth
      if (context.mode == AuthMode.noAuth) {
        return 401; // No credentials provided
      }
      // Authenticated but no permission
      return 403;

    case OperationType.admin:
      // Server requires auth but we have none
      if (context.shouldFailWithAuthError) {
        return 401;
      }
      // Authenticated but not admin
      if (!context.isAdmin) {
        return 403;
      }
      return null;

    case OperationType.plugin:
      // Server requires auth but we have none
      if (context.shouldFailWithAuthError) {
        return 401;
      }
      // Authenticated but no permissions
      if (!context.hasPermissions) {
        return 403;
      }
      return null;
  }
}

/// Get expected error message pattern for failed operations
///
/// Useful for verifying error messages in tests
String? getExpectedErrorMessage(
  AuthTestContext context,
  OperationType operation,
) {
  final errorCode = getExpectedError(context, operation);

  if (errorCode == null) {
    return null;
  }

  switch (errorCode) {
    case 401:
      return 'Unauthorized';
    case 403:
      return 'Forbidden';
    default:
      return null;
  }
}
