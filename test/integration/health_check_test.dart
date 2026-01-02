import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';

/// Health check utilities for integration tests
///
/// Provides conditional service availability verification
/// based on which module is being tested.

/// Check if Auth service is available
Future<bool> checkAuthServiceHealth() async {
  try {
    final response = await http.get(Uri.parse(authServiceBaseUrl));
    return response.statusCode == 200;
  } on Exception catch (_) {
    return false;
  }
}

/// Check if Store service is available
Future<bool> checkStoreServiceHealth() async {
  try {
    final response = await http.get(Uri.parse(storeServiceBaseUrl));
    return response.statusCode == 200;
  } on Exception catch (_) {
    return false;
  }
}

/// Check if Compute service is available
Future<bool> checkComputeServiceHealth() async {
  try {
    final response = await http.get(Uri.parse(computeServiceBaseUrl));
    return response.statusCode == 200;
  } on Exception catch (_) {
    return false;
  }
}

/// Check if MQTT broker is available
///
/// Attempts to connect to MQTT broker at localhost:1883.
/// Returns true if connection succeeds, false otherwise.
Future<bool> checkMqttBrokerHealth() async {
  try {
    final client = MqttServerClient(
      'localhost',
      'health_check_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 20;

    await client.connect();

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      client.disconnect();
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}

/// Verify health check - throws exception if services unavailable
// ignore: unreachable_from_main Tests should be added
Future<void> ensureAuthServiceHealthy() async {
  if (!await checkAuthServiceHealth()) {
    throw Exception('Auth service not available at $authServiceBaseUrl');
  }
}

/// Verify health check - throws exception if services unavailable
// ignore: unreachable_from_main Tests should be added
Future<void> ensureStoreServiceHealthy() async {
  if (!await checkStoreServiceHealth()) {
    throw Exception('Store service not available at $storeServiceBaseUrl');
  }
}

/// Verify health check - throws exception if compute service unavailable
// ignore: unreachable_from_main Tests should be added
Future<void> ensureComputeServiceHealthy() async {
  if (!await checkComputeServiceHealth()) {
    throw Exception('Compute service not available at $computeServiceBaseUrl');
  }
}

/// Verify both services are healthy
Future<void> ensureBothServicesHealthy() async {
  final authHealthy = await checkAuthServiceHealth();
  final storeHealthy = await checkStoreServiceHealth();

  if (!authHealthy && !storeHealthy) {
    throw Exception(
      'Both services unavailable: '
      'Auth($authServiceBaseUrl), Store($storeServiceBaseUrl)',
    );
  }
  if (!authHealthy) {
    throw Exception('Auth service not available at $authServiceBaseUrl');
  }
  if (!storeHealthy) {
    throw Exception('Store service not available at $storeServiceBaseUrl');
  }
}

void main() {
  group('Health Checks', () {
    test('Auth service is available', () async {
      final isHealthy = await checkAuthServiceHealth();
      expect(
        isHealthy,
        isTrue,
        reason: 'Auth service should be available at $authServiceBaseUrl',
      );
    });

    test('Store service is available', () async {
      final isHealthy = await checkStoreServiceHealth();
      expect(
        isHealthy,
        isTrue,
        reason: 'Store service should be available at $storeServiceBaseUrl',
      );
    });

    test('Compute service is available', () async {
      final isHealthy = await checkComputeServiceHealth();
      expect(
        isHealthy,
        isTrue,
        reason: 'Compute service should be available at $computeServiceBaseUrl',
      );
    });

    test('Both services are available', () async {
      await expectLater(ensureBothServicesHealthy(), completes);
    });
  });
}
