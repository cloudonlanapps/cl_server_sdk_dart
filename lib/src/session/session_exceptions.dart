import '../core/exceptions.dart';

/// Base exception for session-related errors
class SessionException extends CLServerException {
  /// Create a session exception with a message
  SessionException({
    required String message,
  }) : super(message: message, statusCode: null);
}

/// Exception thrown when an operation requires login but user is not
/// logged in
class NotLoggedInException extends SessionException {
  /// Create a not logged in exception
  NotLoggedInException()
      : super(
          message:
              'User is not logged in. Call SessionManager.login() first.',
        );
}

/// Exception thrown when token has expired
class TokenExpiredException extends SessionException {
  /// Create a token expired exception
  TokenExpiredException()
      : super(
          message: 'Token has expired and could not be refreshed.',
        );
}

/// Exception thrown when automatic token refresh fails
class RefreshFailedException extends SessionException {
  /// Create a refresh failed exception with details
  RefreshFailedException(String details)
      : super(message: 'Token refresh failed: $details');
}

/// Exception thrown when token storage operation fails
class TokenStorageException extends SessionException {
  /// Create a token storage exception
  TokenStorageException(String message)
      : super(message: 'Token storage error: $message');
}

/// Exception thrown when password encryption/decryption fails
class PasswordEncryptionException extends SessionException {
  /// Create a password encryption exception
  PasswordEncryptionException(String message)
      : super(message: 'Password encryption error: $message');
}
