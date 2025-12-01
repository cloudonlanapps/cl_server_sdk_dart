/// Base exception for store manager operations
abstract class StoreManagerException implements Exception {
  StoreManagerException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
