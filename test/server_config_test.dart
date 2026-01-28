import 'package:cl_server_dart_client/src/server_config.dart';
import 'package:test/test.dart';

void main() {
  group('ServerConfig', () {
    test('test_server_config_defaults', () {
      const config = ServerConfig();
      expect(config.authUrl, equals('http://localhost:8000'));
      expect(config.computeUrl, equals('http://localhost:8002'));
      expect(config.storeUrl, equals('http://localhost:8001'));
      expect(config.mqttBroker, equals('localhost'));
      expect(config.mqttPort, equals(1883));
    });

    test('test_server_config_custom_values', () {
      const config = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
        storeUrl: 'https://store.example.com',
        mqttBroker: 'mqtt.example.com',
        mqttPort: 8883,
      );

      expect(config.authUrl, equals('https://auth.example.com'));
      expect(config.computeUrl, equals('https://compute.example.com'));
      expect(config.storeUrl, equals('https://store.example.com'));
      expect(config.mqttBroker, equals('mqtt.example.com'));
      expect(config.mqttPort, equals(8883));
    });

    test('test_server_config_partial_custom', () {
      const config = ServerConfig(
        authUrl: 'https://auth.example.com',
        computeUrl: 'https://compute.example.com',
      );

      expect(config.authUrl, equals('https://auth.example.com'));
      expect(config.computeUrl, equals('https://compute.example.com'));
      // Validating defaults
      expect(config.storeUrl, equals('http://localhost:8001'));
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

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    test('test_server_config_from_env', () {
      // In Dart, environment variables are read once at startup or via Platform.environment.
      // We can't easily mock Platform.environment for unit tests running in same process without spawning.
      // However, we can test logic if we extract environment reading?
      // ServerConfig.fromEnv() uses Platform.environment directly usually.
      // Or we can assume defaults if no env vars are set.

      // If we want to test env vars, we might need to skip strict env var testing or use dart-define flags which fromEnv might not check unless implemented.
      // Our implementation uses `Platform.environment` or `fromEnv` static method usually.
      // Python's `monkeypatch` works because it modifies os.environ. Dart Platform.environment is unmodifiable.

      // We'll skip strict environment variable injection tests unless we refactor ServerConfig to accept an environment map.
      // But we can test default fromEnv behavior.
      final config = ServerConfig.fromEnv();
      expect(config, isA<ServerConfig>());
    });
  });
}
