/// Store operation result wrapper
///
/// All responses from the store_manager module use this result type.
/// Either contains a success message and data, or an error message.
class StoreOperationResult<T> {
  StoreOperationResult({
    this.success,
    this.error,
    this.data,
  });

  /// Success message from operation
  final String? success;

  /// Error message if operation failed
  final String? error;

  /// Result data (entity, list of entities, etc.)
  final T? data;

  /// Check if operation was successful
  bool get isSuccess => success != null && error == null;

  /// Check if operation failed
  bool get isError => error != null;

  /// Get success value or throw if error
  T get valueOrThrow {
    if (isError) {
      throw StoreOperationException(error ?? 'Unknown error');
    }
    return data as T;
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'StoreOperationResult.success($success)';
    } else {
      return 'StoreOperationResult.error($error)';
    }
  }
}

/// Exception thrown when accessing valueOrThrow on error result
class StoreOperationException implements Exception {
  StoreOperationException(this.message);

  final String message;

  @override
  String toString() => 'StoreOperationException: $message';
}
