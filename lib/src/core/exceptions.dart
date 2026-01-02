/// Base exception class for CL Server client errors
class CLServerException implements Exception {
  /// Creates a new [CLServerException].
  ///
  /// Parameters:
  /// - [message]: The error message
  /// - [statusCode]: Optional HTTP status code
  CLServerException({required this.message, this.statusCode});

  /// The error message.
  final String message;

  /// The HTTP status code associated with this error.
  final int? statusCode;

  @override
  String toString() => message;
}

/// Exception thrown when authentication fails (401)
class AuthException extends CLServerException {
  /// Creates a new [AuthException].
  AuthException({required super.message, super.statusCode = 401});
}

/// Exception thrown when user lacks required permissions (403)
class PermissionException extends CLServerException {
  /// Creates a new [PermissionException].
  PermissionException({required super.message, super.statusCode = 403});
}

/// Exception thrown when request validation fails (422)
class ValidationException extends CLServerException {
  /// Creates a new [ValidationException].
  ///
  /// The [details] parameter contains additional validation error information.
  ValidationException({
    required super.message,
    super.statusCode = 422,
    this.details,
  });

  /// Additional validation error details.
  final dynamic details;
}

/// Exception thrown when resource is not found (404)
class ResourceNotFoundException extends CLServerException {
  /// Creates a new [ResourceNotFoundException].
  ResourceNotFoundException({required super.message, super.statusCode = 404});
}

/// Exception thrown for server errors (5xx)
class ServerException extends CLServerException {
  /// Creates a new [ServerException].
  ServerException({required super.message, super.statusCode});
}

/// Exception thrown for network or connection errors
class NetworkException extends CLServerException {
  /// Creates a new [NetworkException].
  NetworkException({required super.message, super.statusCode});
}

/// Exception thrown when MQTT connection or operation fails
class MqttConnectionException implements Exception {
  /// Creates a new [MqttConnectionException].
  ///
  /// Parameters:
  /// - [message]: The error message describing the MQTT failure
  MqttConnectionException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'MqttConnectionException: $message';
}
