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
    required this.mqttBroker,
    required this.mqttPort,
  });

  /// Create ServerConfig from environment variables.
  factory ServerConfig.fromEnv([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;

    final authUrl = env['AUTH_URL'];
    final computeUrl = env['COMPUTE_URL'];
    final storeUrl = env['STORE_URL'];
    final mqttBroker = env['MQTT_BROKER'];
    final mqttPortStr = env['MQTT_PORT'];

    if (authUrl == null ||
        computeUrl == null ||
        storeUrl == null ||
        mqttBroker == null ||
        mqttPortStr == null) {
      throw StateError(
        'Missing required environment variables for ServerConfig. '
        'REQUIRED: AUTH_URL, COMPUTE_URL, STORE_URL, MQTT_BROKER, MQTT_PORT',
      );
    }

    final mqttPort = int.tryParse(mqttPortStr);
    if (mqttPort == null) {
      throw StateError('Invalid MQTT_PORT: $mqttPortStr');
    }

    return ServerConfig(
      authUrl: authUrl,
      computeUrl: computeUrl,
      storeUrl: storeUrl,
      mqttBroker: mqttBroker,
      mqttPort: mqttPort,
    );
  }

  /// Auth service URL (default: http://localhost:8010)
  final String authUrl;

  /// Compute service URL (default: http://localhost:8012)
  final String computeUrl;

  /// Store service URL (default: http://localhost:8011)
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
