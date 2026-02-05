import 'dart:io';

/// Configuration for CL Server service URLs.
///
/// Centralizes URL management for auth, compute, and future services.
import 'package:meta/meta.dart';

@immutable
class ServerConfig {
  const ServerConfig({
    required this.authUrl,
    required this.computeUrl,
    required this.storeUrl,
    required this.mqttUrl,
  });

  /// Create ServerConfig from environment variables.
  factory ServerConfig.fromEnv([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;

    final authUrl = env['CL_AUTH_URL'];
    final computeUrl = env['CL_COMPUTE_URL'];
    final storeUrl = env['CL_STORE_URL'];
    final mqttUrl = env['CL_MQTT_URL'];

    if (authUrl == null ||
        computeUrl == null ||
        storeUrl == null ||
        mqttUrl == null) {
      throw StateError(
        'Missing required environment variables for ServerConfig. '
        'REQUIRED: CL_AUTH_URL, CL_COMPUTE_URL, CL_STORE_URL, CL_MQTT_URL',
      );
    }

    return ServerConfig(
      authUrl: authUrl,
      computeUrl: computeUrl,
      storeUrl: storeUrl,
      mqttUrl: mqttUrl,
    );
  }

  /// Auth service URL (e.g., http://auth.example.com:8010)
  final String authUrl;

  /// Compute service URL (e.g., http://compute.example.com:8012)
  final String computeUrl;

  /// Store service URL (e.g., http://store.example.com:8011)
  final String storeUrl;

  /// MQTT URL (e.g., mqtt://mqtt.example.com:1883)
  final String mqttUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          runtimeType == other.runtimeType &&
          authUrl == other.authUrl &&
          computeUrl == other.computeUrl &&
          storeUrl == other.storeUrl &&
          mqttUrl == other.mqttUrl;

  @override
  int get hashCode =>
      authUrl.hashCode ^
      computeUrl.hashCode ^
      storeUrl.hashCode ^
      mqttUrl.hashCode;

  @override
  String toString() {
    return 'ServerConfig(authUrl: $authUrl, computeUrl: $computeUrl, storeUrl: $storeUrl, mqttUrl: $mqttUrl)';
  }
}
