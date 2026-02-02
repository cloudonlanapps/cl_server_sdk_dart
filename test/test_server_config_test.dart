import 'package:cl_server_dart_client/src/server_config.dart';
import 'package:test/test.dart';

void main() {
  group('TestServerConfig', () {
    test('test_server_config_defaults', () {
      const config = ServerConfig();

      expect(config.authUrl, equals('http://localhost:8010'));
      expect(config.computeUrl, equals('http://localhost:8012'));
      expect(config.storeUrl, equals('http://localhost:8011'));
      expect(config.mqttUrl, isNull);
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

    test('test_server_config_partial_custom', () {
      const config = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
      );

      // Custom values
      expect(config.authUrl, equals('https://auth.example.com'));
      expect(config.computeUrl, equals('https://compute.example.com'));

      // Default values
      expect(config.storeUrl, equals('http://localhost:8011'));
      expect(config.mqttUrl, isNull);
    });

    test('test_server_config_from_env_all_vars', () {
      final env = {
        'AUTH_URL': 'https://auth.prod.example.com',
        'COMPUTE_URL': 'https://compute.prod.example.com',
        'STORE_URL': 'https://store.prod.example.com',
        'MQTT_URL': 'mqtt://mqtt.prod.example.com:8883',
      };

      final config = ServerConfig.fromEnv(env);

      expect(config.authUrl, equals('https://auth.prod.example.com'));
      expect(config.computeUrl, equals('https://compute.prod.example.com'));
      expect(config.storeUrl, equals('https://store.prod.example.com'));
      expect(config.mqttUrl, equals('mqtt://mqtt.prod.example.com:8883'));
    });

    test('test_server_config_from_env_partial_vars', () {
      final env = {
        'AUTH_URL': 'https://auth.example.com',
        'MQTT_URL': 'mqtt://custom-broker:9883',
      };

      final config = ServerConfig.fromEnv(env);

      // From environment
      expect(config.authUrl, equals('https://auth.example.com'));
      expect(config.mqttUrl, equals('mqtt://custom-broker:9883'));

      // From defaults
      expect(config.computeUrl, equals('http://localhost:8012'));
      expect(config.storeUrl, equals('http://localhost:8011'));
    });

    test('test_server_config_from_env_no_vars', () {
      final config = ServerConfig.fromEnv({});

      // Should use all defaults
      expect(config.authUrl, equals('http://localhost:8010'));
      expect(config.computeUrl, equals('http://localhost:8012'));
      expect(config.storeUrl, equals('http://localhost:8011'));
      expect(config.mqttUrl, isNull);
    });

    test('test_server_config_equality', () {
      const config1 = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
      );
      const config2 = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
      );
      const config3 = ServerConfig(
        authUrl: 'https://different.example.com',
        computeUrl: 'https://compute.example.com',
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
      );

      final reprStr = config.toString();

      // Should contain class name and field values
      expect(reprStr, contains('ServerConfig'));
      expect(reprStr, contains('authUrl')); // Dart uses authUrl not auth_url
      expect(reprStr, contains('https://auth.example.com'));
    });

    test('test_server_config_immutable', () {
      // In Dart, if fields are final and the constructor is const, it's effectively immutable.
      // We can't actually "assign" to a final field to test it fails at runtime in a way that passes compilation,
      // but we can verify it's marked as @immutable or just conceptually matches the Python test's intent
      // which was to check if it's a dataclass-like structure.
      // However, Python test actually tested MUTABILITY.
      // In Dart SDK, ServerConfig fields ARE final (immutable).

      const config = ServerConfig(authUrl: 'https://auth.example.com');
      // config.authUrl = 'new'; // This would be a compile-time error.
      expect(config.authUrl, equals('https://auth.example.com'));
    });
  });
}
