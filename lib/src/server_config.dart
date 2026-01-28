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
    this.mqttBroker = 'localhost',
    this.mqttPort = 1883,
  });

  /// Create ServerConfig from environment variables.
  factory ServerConfig.fromEnv() {
    final env = Platform.environment;
    const defaultConf = ServerConfig();

    return ServerConfig(
      authUrl: env['AUTH_URL'] ?? defaultConf.authUrl,
      computeUrl: env['COMPUTE_URL'] ?? defaultConf.computeUrl,
      storeUrl: env['STORE_URL'] ?? defaultConf.storeUrl,
      mqttBroker: env['MQTT_BROKER'] ?? defaultConf.mqttBroker,
      mqttPort: int.tryParse(env['MQTT_PORT'] ?? '') ?? defaultConf.mqttPort,
    );
  }

  /// Auth service URL (default: http://localhost:8000)
  final String authUrl;

  /// Compute service URL (default: http://localhost:8002)
  final String computeUrl;

  /// Store service URL (default: http://localhost:8001)
  final String storeUrl;

  /// MQTT broker host (default: localhost)
  final String mqttBroker;

  /// MQTT broker port (default: 1883)
  final int mqttPort;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          runtimeType == other.runtimeType &&
          authUrl == other.authUrl &&
          computeUrl == other.computeUrl &&
          storeUrl == other.storeUrl &&
          mqttBroker == other.mqttBroker &&
          mqttPort == other.mqttPort;

  @override
  int get hashCode =>
      authUrl.hashCode ^
      computeUrl.hashCode ^
      storeUrl.hashCode ^
      mqttBroker.hashCode ^
      mqttPort.hashCode;

  @override
  String toString() {
    return 'ServerConfig(authUrl: $authUrl, computeUrl: $computeUrl, storeUrl: $storeUrl, mqttBroker: $mqttBroker, mqttPort: $mqttPort)';
  }
}
