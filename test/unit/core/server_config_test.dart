import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('ServerConfig Tests', () {
    test('creates config with all three base URLs', () {
      final config = ServerConfig(
        authServiceBaseUrl: 'http://localhost:8000',
        storeServiceBaseUrl: 'http://localhost:8001',
        computeServiceBaseUrl: 'http://localhost:8001',
      );

      expect(config.authServiceBaseUrl, 'http://localhost:8000');
      expect(config.storeServiceBaseUrl, 'http://localhost:8001');
      expect(config.computeServiceBaseUrl, 'http://localhost:8001');
    });

    test(
      'computeServiceBaseUrl defaults to storeServiceBaseUrl if not provided',
      () {
        final config = ServerConfig(
          authServiceBaseUrl: 'http://localhost:8000',
          storeServiceBaseUrl: 'http://localhost:8001',
        );

        expect(config.computeServiceBaseUrl, isNull);
        expect(config.getComputeServiceBaseUrl(), 'http://localhost:8001');
      },
    );

    test(
      'getComputeServiceBaseUrl returns explicit value if computeServiceBaseUrl is provided',
      () {
        final config = ServerConfig(
          authServiceBaseUrl: 'http://localhost:8000',
          storeServiceBaseUrl: 'http://localhost:8001',
          computeServiceBaseUrl: 'http://localhost:8001',
        );

        expect(config.getComputeServiceBaseUrl(), 'http://localhost:8001');
      },
    );

    test('supports remote URLs', () {
      final config = ServerConfig(
        authServiceBaseUrl: 'http://192.168.0.105:8000',
        storeServiceBaseUrl: 'http://192.168.0.105:8001',
        computeServiceBaseUrl: 'http://192.168.0.105:8001',
      );

      expect(config.authServiceBaseUrl, 'http://192.168.0.105:8000');
      expect(config.storeServiceBaseUrl, 'http://192.168.0.105:8001');
      expect(config.getComputeServiceBaseUrl(), 'http://192.168.0.105:8001');
    });

    test('supports different URLs for each service', () {
      final config = ServerConfig(
        authServiceBaseUrl: 'http://auth.example.com',
        storeServiceBaseUrl: 'http://store.example.com',
        computeServiceBaseUrl: 'http://compute.example.com',
      );

      expect(config.authServiceBaseUrl, 'http://auth.example.com');
      expect(config.storeServiceBaseUrl, 'http://store.example.com');
      expect(config.getComputeServiceBaseUrl(), 'http://compute.example.com');
    });
  });
}
