/// Configuration for all server base URLs
/// Used to inject URLs at runtime instead of hardcoding them
class ServerConfig {
  final String authServiceBaseUrl;
  final String storeServiceBaseUrl;
  final String? computeServiceBaseUrl;

  /// Creates a ServerConfig instance
  ///
  /// [authServiceBaseUrl] - The base URL for the authentication service (e.g., http://localhost:8000)
  /// [storeServiceBaseUrl] - The base URL for the store service (e.g., http://localhost:8001)
  /// [computeServiceBaseUrl] - Optional base URL for the compute service. If not provided,
  ///                           defaults to [storeServiceBaseUrl] since compute jobs are
  ///                           managed through the store service
  ServerConfig({
    required this.authServiceBaseUrl,
    required this.storeServiceBaseUrl,
    this.computeServiceBaseUrl,
  });

  /// Returns the compute service base URL
  /// Defaults to [storeServiceBaseUrl] if [computeServiceBaseUrl] is null
  String getComputeServiceBaseUrl() =>
      computeServiceBaseUrl ?? storeServiceBaseUrl;
}
