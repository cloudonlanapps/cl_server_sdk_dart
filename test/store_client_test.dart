import 'dart:convert';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(http.Request('GET', Uri()));
    registerFallbackValue(http.MultipartRequest('POST', Uri()));
  });

  group('StoreClient', () {
    late MockHttpClient mockHttpClient;
    late StoreClient client;

    setUp(() {
      mockHttpClient = MockHttpClient();
      client = StoreClient(
        client: mockHttpClient,
      );
    });

    tearDown(() {
      client.close();
    });

    group('Init', () {
      test('test_init_default', () {
        final c = StoreClient();
        expect(c.baseUrl, equals('http://localhost:8001'));
        c.close();
      });

      test('test_init_with_auth', () {
        final auth = NoAuthProvider();
        final c = StoreClient(
          baseUrl: 'http://example.com:8001',
          authProvider: auth,
          timeout: const Duration(seconds: 60),
        );
        expect(c.baseUrl, equals('http://example.com:8001'));
        expect(c.timeout.inSeconds, equals(60));
        c.close();
      });
    });

    group('ReadOperations', () {
      test('test_list_entities', () async {
        final responseBody = jsonEncode({
          'items': [
            {'id': 1, 'label': 'Entity 1'},
            {'id': 2, 'label': 'Entity 2'},
          ],
          'pagination': {
            'page': 1,
            'page_size': 20,
            'total_items': 2,
            'total_pages': 1,
            'has_next': false,
            'has_prev': false,
          },
        });

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await client.listEntities();

        expect(result.items.length, equals(2));
        expect(result.items[0].id, equals(1));
        expect(result.pagination.page, equals(1));

        verify(
          () => mockHttpClient.get(
            any(
              that: predicate(
                (Uri uri) =>
                    uri.path == '/entities' &&
                    uri.queryParameters['page'] == '1' &&
                    uri.queryParameters['page_size'] == '20',
              ),
            ),
            headers: any(named: 'headers'),
          ),
        ).called(1);
      });

      test('test_read_entity', () async {
        final responseBody = jsonEncode({
          'id': 123,
          'label': 'Test Entity',
          'description': 'Test description',
        });

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await client.readEntity(123);

        expect(result.id, equals(123));
        expect(result.label, equals('Test Entity'));

        verify(
          () => mockHttpClient.get(
            Uri.parse('http://localhost:8001/entities/123'),
            headers: any(named: 'headers'),
          ),
        ).called(1);
      });
    });

    group('WriteOperations', () {
      test('test_create_entity_collection', () async {
        final responseBody = jsonEncode({
          'id': 1,
          'label': 'New Collection',
          'is_collection': true,
        });

        when(
          () => mockHttpClient.send(any()),
        ).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
          );
        });

        final result = await client.createEntity(
          isCollection: true,
          label: 'New Collection',
        );

        expect(result.id, equals(1));
        expect(result.isCollection, isTrue);

        verify(() => mockHttpClient.send(any())).called(1);
      });

      test('test_update_entity', () async {
        final responseBody = jsonEncode({
          'id': 123,
          'label': 'Updated Label',
        });

        when(
          () => mockHttpClient.send(any()),
        ).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
          );
        });

        final result = await client.updateEntity(
          123,
          isCollection: false,
          label: 'Updated Label',
        );

        expect(result.id, equals(123));
        expect(result.label, equals('Updated Label'));

        verify(
          () => mockHttpClient.send(
            any(
              that: predicate(
                (http.BaseRequest req) =>
                    req.method == 'PUT' &&
                    req.url.path == '/entities/123' &&
                    (req as http.MultipartRequest).fields['label'] ==
                        'Updated Label' &&
                    req.fields['is_collection'] == 'false',
              ),
            ),
          ),
        ).called(1);
      });

      test('test_update_entity_with_patch', () async {
        final responseBody = jsonEncode({
          'id': 123,
          'label': 'Patched Label',
        });

        when(
          () => mockHttpClient.send(any()),
        ).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
          );
        });

        final result = await client.patchEntity(
          123,
          label: 'Patched Label',
        );

        expect(result.label, equals('Patched Label'));

        // Verify body map
        verify(
          () => mockHttpClient.send(
            any(
              that: predicate(
                (http.BaseRequest req) =>
                    req.method == 'PATCH' &&
                    req.url.path == '/entities/123' &&
                    (req as http.MultipartRequest).fields['label'] ==
                        'Patched Label',
              ),
            ),
          ),
        ).called(1);
      });
    });
  });
}
