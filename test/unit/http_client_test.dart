import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../server_addr.dart' show authServiceUrl;

class MockHttpClient extends http.BaseClient {
  MockHttpClient(this.responses);
  final Map<String, http.Response> responses;
  late http.Request lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request as http.Request;
    final key = '${request.method} ${request.url}';
    final response = responses[key];

    if (response != null) {
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }

    return http.StreamedResponse(
      Stream.value([]),
      404,
      request: request,
    );
  }
}

void main() {
  group('HttpClientWrapper Tests', () {
    group('GET requests', () {
      test('GET returns response on 200', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/test': http.Response(
            '{"data": "test"}',
            200,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        final response = await client.get('/test');
        expect(response['data'], 'test');
      });

      test('GET includes authorization header when token provided', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/test': http.Response(
            '{"data": "test"}',
            200,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          token: 'test-token',
          httpClient: mockClient,
        );

        await client.get('/test');
        expect(
          mockClient.lastRequest.headers['authorization'],
          'Bearer test-token',
        );
      });

      test('GET throws AuthException on 401', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/test': http.Response(
            '{"detail": "Not authenticated"}',
            401,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        expect(
          () => client.get('/test'),
          throwsA(isA<AuthException>()),
        );
      });

      test('GET throws PermissionException on 403', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/test': http.Response(
            '{"detail": "Not enough permissions"}',
            403,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        expect(
          () => client.get('/test'),
          throwsA(isA<PermissionException>()),
        );
      });

      test('GET throws ResourceNotFoundException on 404', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/test': http.Response(
            '{"detail": "Not found"}',
            404,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        expect(
          () => client.get('/test'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('GET throws ValidationException on 422', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/test': http.Response(
            '{"detail": [{"loc": ["body"], "msg": "invalid"}]}',
            422,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        expect(
          () => client.get('/test'),
          throwsA(isA<ValidationException>()),
        );
      });

      test('GET throws ServerException on 500', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/test': http.Response(
            '{"detail": "Internal server error"}',
            500,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        expect(
          () => client.get('/test'),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('POST requests', () {
      test('POST returns response on 201', () async {
        final mockClient = MockHttpClient({
          'POST $authServiceUrl/test': http.Response(
            '{"id": 1, "name": "test"}',
            201,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        final response = await client.post('/test', body: {'name': 'test'});
        expect(response['id'], 1);
        expect(response['name'], 'test');
      });

      test('POST sends JSON body correctly', () async {
        final mockClient = MockHttpClient({
          'POST $authServiceUrl/test': http.Response(
            '{"success": true}',
            201,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        await client.post('/test', body: {'key': 'value'});
        expect(mockClient.lastRequest.body, contains('"key":"value"'));
      });
    });

    group('PUT requests', () {
      test('PUT returns response on 200', () async {
        final mockClient = MockHttpClient({
          'PUT $authServiceUrl/test': http.Response(
            '{"updated": true}',
            200,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        final response = await client.put('/test', body: {'id': 1});
        expect(response['updated'], true);
      });
    });

    group('PATCH requests', () {
      test('PATCH returns response on 200', () async {
        final mockClient = MockHttpClient({
          'PATCH $authServiceUrl/test': http.Response(
            '{"patched": true}',
            200,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        final response = await client.patch('/test', body: {'field': 'value'});
        expect(response['patched'], true);
      });
    });

    group('DELETE requests', () {
      test('DELETE completes on 204', () async {
        final mockClient = MockHttpClient({
          'DELETE $authServiceUrl/test': http.Response('', 204),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        final response = await client.delete('/test');
        expect(response['statusCode'], 204);
      });
    });

    group('Query parameters', () {
      test('GET includes query parameters in URL', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/test?page=1&limit=10': http.Response(
            '{"data": []}',
            200,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        await client.get(
          '/test',
          queryParameters: {'page': '1', 'limit': '10'},
        );

        expect(mockClient.lastRequest.url.query, contains('page=1'));
        expect(mockClient.lastRequest.url.query, contains('limit=10'));
      });
    });

    group('Base URL handling', () {
      test('Correctly builds full URL from base and endpoint', () async {
        final mockClient = MockHttpClient({
          'GET $authServiceUrl/api/users': http.Response(
            '[]',
            200,
          ),
        });

        final client = HttpClientWrapper(
          baseUrl: authServiceUrl,
          httpClient: mockClient,
        );

        await client.get('/api/users');
        expect(
          mockClient.lastRequest.url.toString(),
          '$authServiceUrl/api/users',
        );
      });
    });
  });
}
