import 'dart:io';

/// Configuration for CL Server service URLs.
///
/// Centralizes URL management for auth, compute, and future services.
import 'package:meta/meta.dart';

@immutable
class ServerConfig {
  const ServerConfig({
    this.authUrl = 'http://localhost:8010',
    this.computeUrl = 'http://localhost:8012',
    this.storeUrl = 'http://localhost:8011',
    this.mqttUrl,
  });

  /// Create ServerConfig from environment variables.
  factory ServerConfig.fromEnv([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    const defaultConf = ServerConfig();

    return ServerConfig(
      authUrl: env['AUTH_URL'] ?? defaultConf.authUrl,
      computeUrl: env['COMPUTE_URL'] ?? defaultConf.computeUrl,
      storeUrl: env['STORE_URL'] ?? defaultConf.storeUrl,
      // Note: MQTT_URL is read from environment in Dart, unlike Python
      mqttUrl: env['MQTT_URL'] ?? defaultConf.mqttUrl,
    );
  }

  /// Auth service URL (default: http://localhost:8010)
  final String authUrl;

  /// Compute service URL (default: http://localhost:8012)
  final String computeUrl;

  /// Store service URL (default: http://localhost:8011)
  final String storeUrl;

  /// MQTT broker URL (e.g., mqtt://localhost:1883)
  /// null means MQTT is disabled
  final String? mqttUrl;

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
      (mqttUrl?.hashCode ?? 0);

  @override
  String toString() {
    return 'ServerConfig(authUrl: $authUrl, computeUrl: $computeUrl, storeUrl: $storeUrl, mqttUrl: $mqttUrl)';
  }
}
