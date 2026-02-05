import 'package:cl_server_dart_client/src/server_config.dart';
import 'package:test/test.dart';

void main() {
  group('TestServerConfig', () {
    test('test_server_config_all_required_values', () {
      const config = ServerConfig(
        authUrl: 'http://auth.local:8010',
        computeUrl: 'http://compute.local:8012',
        storeUrl: 'http://store.local:8011',
        mqttUrl: 'mqtt://mqtt.local:1883',
      );

      expect(config.authUrl, equals('http://auth.local:8010'));
      expect(config.computeUrl, equals('http://compute.local:8012'));
      expect(config.storeUrl, equals('http://store.local:8011'));
      expect(config.mqttUrl, equals('mqtt://mqtt.local:1883'));
    });

    test('test_server_config_custom_values', () {
      const config = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
        storeUrl: 'https://store.example.com',
        mqttUrl: 'mqtt://mqtt.example.com:8883',
      );

      expect(config.authUrl, equals('https://auth.example.com'));
      expect(config.computeUrl, equals('https://compute.example.com'));
      expect(config.storeUrl, equals('https://store.example.com'));
      expect(config.mqttUrl, equals('mqtt://mqtt.example.com:8883'));
    });

    test('test_server_config_from_env_all_vars', () {
      final env = {
        'CL_AUTH_URL': 'https://auth.prod.example.com',
        'CL_COMPUTE_URL': 'https://compute.prod.example.com',
        'CL_STORE_URL': 'https://store.prod.example.com',
        'CL_MQTT_URL': 'mqtt://mqtt.prod.example.com:8883',
      };

      final config = ServerConfig.fromEnv(env);

      expect(config.authUrl, equals('https://auth.prod.example.com'));
      expect(config.computeUrl, equals('https://compute.prod.example.com'));
      expect(config.storeUrl, equals('https://store.prod.example.com'));
      expect(config.mqttUrl, equals('mqtt://mqtt.prod.example.com:8883'));
    });

    test('test_server_config_from_env_missing_required_vars', () {
      final env = {
        'CL_AUTH_URL': 'https://auth.example.com',
        'CL_COMPUTE_URL': 'https://compute.example.com',
        // Missing CL_STORE_URL and CL_MQTT_URL
      };

      expect(
        () => ServerConfig.fromEnv(env),
        throwsA(isA<StateError>()),
      );
    });

    test('test_server_config_from_env_missing_all_vars', () {
      expect(
        () => ServerConfig.fromEnv(const {}),
        throwsA(isA<StateError>()),
      );
    });

    test('test_server_config_equality', () {
      const config1 = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
        storeUrl: 'https://store.example.com',
        mqttUrl: 'mqtt://mqtt.example.com:1883',
      );
      const config2 = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
        storeUrl: 'https://store.example.com',
        mqttUrl: 'mqtt://mqtt.example.com:1883',
      );
      const config3 = ServerConfig(
        authUrl: 'https://different.example.com',
        computeUrl: 'https://compute.example.com',
        storeUrl: 'https://store.example.com',
        mqttUrl: 'mqtt://mqtt.example.com:1883',
      );

      // Same values should be equal
      expect(config1, equals(config2));

      // Different values should not be equal
      expect(config1, isNot(equals(config3)));
    });

    test('test_server_config_repr', () {
      const config = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
        storeUrl: 'https://store.example.com',
        mqttUrl: 'mqtt://mqtt.example.com:1883',
      );

      final reprStr = config.toString();

      // Should contain class name and field values
      expect(reprStr, contains('ServerConfig'));
      expect(reprStr, contains('authUrl'));
      expect(reprStr, contains('https://auth.example.com'));
      expect(reprStr, contains('mqttUrl'));
    });

    test('test_server_config_immutable', () {
      const config = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
        storeUrl: 'https://store.example.com',
        mqttUrl: 'mqtt://mqtt.example.com:1883',
      );
      // config.authUrl = 'new'; // This would be a compile-time error.
      expect(config.authUrl, equals('https://auth.example.com'));
    });
  });
}
