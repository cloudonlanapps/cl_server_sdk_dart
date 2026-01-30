import 'dart:convert';
import 'dart:io';

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
        expect(c.baseUrl, equals('http://localhost:8011'));
        c.close();
      });

      test('test_init_with_auth', () {
        final auth = NoAuthProvider();
        final c = StoreClient(
          baseUrl: 'http://example.com:8011',
          authProvider: auth,
          timeout: const Duration(seconds: 60),
        );
        expect(c.baseUrl, equals('http://example.com:8011'));
        expect(c.timeout.inSeconds, equals(60));
        c.close();
      });
    });

    group('ReadOperations', () {
      test('test_list_entities_with_search', () async {
        final responseBody = jsonEncode(<String, dynamic>{
          'items': <Map<String, dynamic>>[],
          'pagination': <String, dynamic>{
            'page': 1,
            'page_size': 10,
            'total_items': 0,
            'total_pages': 0,
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

        await client.listEntities(page: 1, pageSize: 10, searchQuery: 'test');

        verify(
          () => mockHttpClient.get(
            any(
              that: predicate(
                (Uri uri) => uri.queryParameters['search_query'] == 'test',
              ),
            ),
            headers: any(named: 'headers'),
          ),
        ).called(1);
      });

      test('test_read_entity_with_version', () async {
        final responseBody = jsonEncode({'id': 123, 'label': 'Old Label'});

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        await client.readEntity(123, version: 2);

        verify(
          () => mockHttpClient.get(
            any(
              that: predicate(
                (Uri uri) => uri.queryParameters['version'] == '2',
              ),
            ),
            headers: any(named: 'headers'),
          ),
        ).called(1);
      });

      test('test_get_versions', () async {
        final responseBody = jsonEncode([
          {'version': 1, 'transaction_id': 100, 'label': 'V1'},
          {'version': 2, 'transaction_id': 101, 'label': 'V2'},
        ]);

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await client.getVersions(123);

        expect(result.length, equals(2));
        expect(result[0].version, equals(1));
        expect(result[1].version, equals(2));
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

        final (result, statusCode) = await client.createEntity(
          isCollection: true,
          label: 'New Collection',
        );

        expect(result.id, equals(1));
        expect(result.isCollection, isTrue);
        expect(statusCode, equals(200));

        verify(() => mockHttpClient.send(any())).called(1);
      });

      test('test_create_entity_with_file', () async {
        final responseBody = jsonEncode({
          'id': 2,
          'label': 'Photo',
          'file_path': '/media/test.jpg',
        });

        when(
          () => mockHttpClient.send(any()),
        ).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
          );
        });

        // Use a dummy file path since we mock HttpUtils/MultipartRequest
        // But StoreClient calls File(imagePath), so it might fail if path doesn't exist during request build
        // OR we can just mock the send and check the request.
        // In StoreClient, it does request.files.add(await HttpUtils.createMultipartFile('image', File(imagePath)));
        // This requires the file to exist.
        final tempFile = File('temp_test.jpg')..writeAsBytesSync([1, 2, 3]);

        try {
          final (result, statusCode) = await client.createEntity(
            isCollection: false,
            label: 'Photo',
            imagePath: tempFile.path,
          );

          expect(result.id, equals(2));
          expect(statusCode, equals(200));
          verify(
            () => mockHttpClient.send(
              any(
                that: predicate(
                  (http.BaseRequest req) =>
                      req is http.MultipartRequest && req.files.isNotEmpty,
                ),
              ),
            ),
          ).called(1);
        } finally {
          if (tempFile.existsSync()) tempFile.deleteSync();
        }
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

      test('test_patch_entity', () async {
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

      test('test_patch_entity_with_unset', () async {
        final responseBody = jsonEncode({'id': 123, 'label': 'Original'});

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
          ),
        );

        // Test with UNSET (no fields should be in request)
        await client.patchEntity(123);
        verify(
          () => mockHttpClient.send(
            any(
              that: predicate(
                (http.BaseRequest req) =>
                    (req as http.MultipartRequest).fields.isEmpty,
              ),
            ),
          ),
        ).called(1);

        // Test explicitly null (should be empty string in request per StoreClient logic)
        await client.patchEntity(123, label: null);
        verify(
          () => mockHttpClient.send(
            any(
              that: predicate(
                (http.BaseRequest req) =>
                    (req as http.MultipartRequest).fields['label'] == '',
              ),
            ),
          ),
        ).called(1);
      });

      test('test_patch_entity_soft_delete', () async {
        final responseBody = jsonEncode({'id': 123, 'is_deleted': true});

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
          ),
        );

        final result = await client.patchEntity(123, isDeleted: true);

        expect(result.isDeleted, isTrue);
        verify(
          () => mockHttpClient.send(
            any(
              that: predicate(
                (http.BaseRequest req) =>
                    (req as http.MultipartRequest).fields['is_deleted'] ==
                    'true',
              ),
            ),
          ),
        ).called(1);
      });

      test('test_delete_entity', () async {
        when(
          () => mockHttpClient.delete(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('', 204));

        await client.deleteEntity(123);

        verify(
          () => mockHttpClient.delete(
            Uri.parse('http://localhost:8011/entities/123'),
            headers: any(named: 'headers'),
          ),
        ).called(1);
      });
    });

    group('AdminOperations', () {
      test('test_get_config', () async {
        final responseBody = jsonEncode({
          'guest_mode': false,
          'updated_at': 1704067200000,
          'updated_by': 'admin',
        });

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await client.getConfig();

        expect(result.guestMode, isFalse);
        expect(result.updatedBy, equals('admin'));
      });

      test('test_update_guest_mode', () async {
        final responseBody = jsonEncode({
          'guest_mode': true,
          'updated_at': 1704067200000,
          'updated_by': 'admin',
        });

        // Mock PUT then GET (as updateGuestMode calls getConfig)
        when(
          () => mockHttpClient.put(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('', 204));

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await client.updateGuestMode(guestMode: true);

        expect(result.guestMode, isTrue);
        verify(
          () => mockHttpClient.put(
            Uri.parse('http://localhost:8011/admin/config/guest-mode'),
            body: {'guest_mode': 'true'},
            headers: any(named: 'headers'),
          ),
        ).called(1);
      });
    });

    group('ErrorHandling', () {
      test('test_http_error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not Found', 404));

        expect(() => client.readEntity(999), throwsA(isA<HttpStatusError>()));
      });
    });

    group('AuthIntegration', () {
      test('test_auth_headers_applied', () async {
        final auth = JWTAuthProvider(token: 'test-token');
        final c = StoreClient(client: mockHttpClient, authProvider: auth);

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('{}', 200));

        // We need a proper response for healthCheck or listEntities
        // but it doesn't matter if we just check verify
        try {
          await c.healthCheck();
        } on Object catch (_) {}

        verify(
          () => mockHttpClient.get(
            any(),
            headers: any(
              named: 'headers',
              that: containsPair('Authorization', 'Bearer test-token'),
            ),
          ),
        ).called(1);
        c.close();
      });
    });

    group('IntelligenceOperations', () {
      test('test_download_entity_clip_embedding', () async {
        final bytes = [1, 2, 3, 4];
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response.bytes(bytes, 200));

        final result = await client.downloadEntityClipEmbedding(123);

        expect(result, equals(bytes));
        verify(
          () => mockHttpClient.get(
            Uri.parse(
              'http://localhost:8011/intelligence/entities/123/clip_embedding',
            ),
            headers: any(named: 'headers'),
          ),
        ).called(1);
      });

      test('test_download_entity_dino_embedding', () async {
        final bytes = [5, 6, 7, 8];
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response.bytes(bytes, 200));

        final result = await client.downloadEntityDinoEmbedding(123);

        expect(result, equals(bytes));
      });

      test('test_update_known_person_name', () async {
        final responseBody = jsonEncode({
          'id': 1,
          'name': 'New Name',
          'created_at': 1000,
          'updated_at': 2000,
        });

        when(
          () => mockHttpClient.patch(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await client.updateKnownPersonName(1, 'New Name');

        expect(result.id, equals(1));
        expect(result.name, equals('New Name'));
        verify(
          () => mockHttpClient.patch(
            any(),
            body: jsonEncode({'name': 'New Name'}),
            headers: any(
              named: 'headers',
              that: containsPair('Content-Type', 'application/json'),
            ),
          ),
        ).called(1);
      });
    });
  });
}
