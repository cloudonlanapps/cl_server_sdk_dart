import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockStoreClient extends Mock implements StoreClient {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('StoreClient Missing Tests', () {
    late StoreClient storeClient;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      storeClient = StoreClient(
        baseUrl: 'http://localhost:8011',
        client: mockHttpClient,
      );
      registerFallbackValue(Uri.parse('http://localhost:8011'));
    });

    test('test_client_not_initialized', () async {
      // In Dart, client is initialized in constructor.
      // We'll simulate "not ready" by closing it.
      storeClient.close();
      expect(
        () => storeClient.healthCheck(),
        throwsA(anyOf(isA<http.ClientException>(), isA<TypeError>())),
      );
    });

    test('test_store_client_uninitialized_errors', () async {
      final client = StoreClient(baseUrl: 'http://localhost:8011');
      client.close();
      expect(() => client.listEntities(), throwsA(isA<http.ClientException>()));
    });
  });

  group('StoreManager Missing Tests', () {
    late StoreManager storeManager;
    late MockStoreClient mockStoreClient;

    setUp(() {
      mockStoreClient = MockStoreClient();
      storeManager = StoreManager(mockStoreClient);
      registerFallbackValue(UserCreateRequest(username: 'test', password: 'p'));
      registerFallbackValue(UserUpdateRequest());
    });

    test('test_guest_mode', () {
      final manager = StoreManager.guest(
        baseUrl: 'http://example.com:8001',
        mqttBroker: 'localhost',
        mqttPort: 1883,
      );
      expect(manager.storeClient.baseUrl, equals('http://example.com:8001'));
      expect(manager.storeClient.authProvider, isNull);
    });

    test('test_authenticated_mode', () async {
      final config = ServerConfig(
        authUrl: 'http://localhost:8000',
        computeUrl: 'http://localhost:8002',
        storeUrl: 'http://localhost:8001',
        mqttBroker: 'localhost',
        mqttPort: 1883,
      );

      final manager = StoreManager.authenticated(
        config: config,
        getCachedToken: () => 'test_token',
      );

      expect(manager.storeClient.baseUrl, equals('http://localhost:8001'));
      expect(manager.storeClient.authProvider, isNotNull);
    });

    test('test_generic_http_error', () async {
      when(
        () => mockStoreClient.deleteEntity(any()),
      ).thenThrow(ComputeClientError('HTTP 500: Internal Server Error'));

      final result = await storeManager.deleteEntity(123, force: false);

      expect(result.isError, isTrue);
      expect(result.error, contains('500'));
    });

    test('test_context_manager', () async {
      // Dart doesn't have same async context manager syntax, but we can verify close
      final manager = StoreManager(mockStoreClient);
      await manager.close();
      verify(() => mockStoreClient.close()).called(1);
    });

    test('test_context_manager_with_exception', () async {
      final manager = StoreManager(mockStoreClient);
      try {
        throw Exception('Test exception');
      } catch (_) {
        await manager.close();
      }
      verify(() => mockStoreClient.close()).called(1);
    });

    test('test_store_manager_http_error_handling', () async {
      when(
        () => mockStoreClient.listEntities(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenThrow(ComputeClientError('Bad Request'));

      final result = await storeManager.listEntities();

      expect(result.isError, isTrue);
      expect(result.error, equals('Bad Request'));
    });

    test('test_store_manager_unexpected_error_handling', () async {
      when(
        () => mockStoreClient.readEntity(any()),
      ).thenThrow(Exception('Unexpected'));

      final result = await storeManager.readEntity(123);

      expect(result.isError, isTrue);
      expect(result.error, contains('Unexpected'));
    });

    test('test_store_manager_json_decode_error_handling', () async {
      // This is usually handled at Client level, but Manager should catch it
      when(
        () => mockStoreClient.getVersions(any()),
      ).thenThrow(FormatException('Invalid JSON'));

      final result = await storeManager.getVersions(123);

      expect(result.isError, isTrue);
      expect(result.error, contains('Unexpected error'));
    });
  });
}
