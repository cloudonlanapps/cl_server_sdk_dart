import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('StoreService Tests', () {
    test('listEntities returns EntityListResponse', () async {
      final mockClient = MockHttpClient({
        'GET $storeServiceBaseUrl/entity/?page=1&page_size=20': http.Response(
          '''
{
            "items": [{
              "id": 1,
              "is_collection": false,
              "label": "Photo",
              "added_date": 1704067200000,
              "updated_date": 1704067200000,
              "is_deleted": false,
              "create_date": 1704067200000
            }],
            "pagination": {
              "page": 1,
              "page_size": 20,
              "total_items": 1,
              "total_pages": 1,
              "has_next": false,
              "has_prev": false
            }
          }''',
          200,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        httpClient: mockClient,
      );
      final response = await storeService.listEntities();

      expect(response.items, hasLength(1));
      expect(response.items[0].label, 'Photo');
      expect(response.pagination.page, 1);
    });

    test('getEntity returns Entity by ID', () async {
      final mockClient = MockHttpClient({
        'GET $storeServiceBaseUrl/entity/1': http.Response(
          '''
{
            "id": 1,
            "is_collection": false,
            "label": "Photo",
            "added_date": 1704067200000,
            "updated_date": 1704067200000,
            "is_deleted": false,
            "create_date": 1704067200000
          }''',
          200,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        httpClient: mockClient,
      );
      final entity = await storeService.getEntity(1);

      expect(entity.id, 1);
      expect(entity.label, 'Photo');
    });

    test('getEntity throws ResourceNotFoundException on 404', () async {
      final mockClient = MockHttpClient({
        'GET $storeServiceBaseUrl/entity/999': http.Response(
          '{"detail": "Entity not found"}',
          404,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        httpClient: mockClient,
      );

      expect(
        () => storeService.getEntity(999),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('getVersions returns list of EntityVersion', () async {
      final mockClient = MockHttpClient({
        'GET $storeServiceBaseUrl/entity/1/versions': http.Response(
          '''
[{
            "version": 1,
            "transaction_id": 1,
            "end_transaction_id": null,
            "operation_type": 0,
            "label": "Initial",
            "description": "Initial description"
          }]''',
          200,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        httpClient: mockClient,
      );
      final versions = await storeService.getVersions(1);

      expect(versions, hasLength(1));
      expect(versions[0].version, 1);
      expect(versions[0].label, 'Initial');
    });

    test('createEntity returns created Entity', () async {
      final mockClient = MockHttpClient({
        'POST $storeServiceBaseUrl/entity/': http.Response(
          '''
          {
            "id": 2,
            "is_collection": false,
            "label": "New Photo",
            "added_date": 1704067200000,
            "updated_date": 1704067200000,
            "is_deleted": false,
            "create_date": 1704067200000
          }''',
          201,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final entity = await storeService.createEntity(
        isCollection: false,
        label: 'New Photo',
      );

      expect(entity.id, 2);
      expect(entity.label, 'New Photo');
    });

    test('createEntity throws PermissionException on 403', () async {
      final mockClient = MockHttpClient({
        'POST $storeServiceBaseUrl/entity/': http.Response(
          '{"detail": "Not enough permissions"}',
          403,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        httpClient: mockClient,
      );

      expect(
        () => storeService.createEntity(isCollection: false),
        throwsA(isA<PermissionException>()),
      );
    });

    test('updateEntity returns updated Entity', () async {
      final mockClient = MockHttpClient({
        'PUT $storeServiceBaseUrl/entity/1': http.Response(
          '''
{
            "id": 1,
            "is_collection": false,
            "label": "Updated Photo",
            "added_date": 1704067200000,
            "updated_date": 1704070800000,
            "is_deleted": false,
            "create_date": 1704067200000
          }''',
          200,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final entity = await storeService.updateEntity(
        1,
        isCollection: false,
        label: 'Updated Photo',
      );

      expect(entity.label, 'Updated Photo');
    });

    test('patchEntity returns patched Entity', () async {
      final mockClient = MockHttpClient({
        'PATCH $storeServiceBaseUrl/entity/1': http.Response(
          '''
{
            "id": 1,
            "is_collection": false,
            "label": "Patched Label",
            "added_date": 1704067200000,
            "updated_date": 1704074400000,
            "is_deleted": false,
            "create_date": 1704067200000
          }''',
          200,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final entity = await storeService.patchEntity(
        1,
        label: 'Patched Label',
      );

      expect(entity.label, 'Patched Label');
    });

    test('deleteEntity completes successfully', () async {
      final mockClient = MockHttpClient({
        'DELETE $storeServiceBaseUrl/entity/1': http.Response('', 204),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );

      expect(() => storeService.deleteEntity(1), returnsNormally);
    });

    test('deleteCollection returns response', () async {
      final mockClient = MockHttpClient({
        'DELETE $storeServiceBaseUrl/entity/collection': http.Response(
          '{"message": "All entities deleted successfully"}',
          200,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final response = await storeService.deleteCollection();

      expect(response['message'], 'All entities deleted successfully');
    });

    test('getConfig returns StoreConfig', () async {
      final mockClient = MockHttpClient({
        'GET $storeServiceBaseUrl/admin/config': http.Response(
          '''
{
            "read_auth_enabled": false,
            "updated_at": 1704067200000,
            "updated_by": "admin"
          }''',
          200,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final config = await storeService.getConfig();

      expect(config.readAuthEnabled, false);
      expect(config.updatedBy, 'admin');
    });

    test('updateReadAuthConfig returns updated StoreConfig', () async {
      final mockClient = MockHttpClient({
        'PUT $storeServiceBaseUrl/admin/config/read-auth': http.Response(
          '''
{
            "read_auth_enabled": true,
            "updated_at": 1704070800000,
            "updated_by": "admin"
          }''',
          200,
        ),
      });

      final storeService = StoreService(
        storeServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final config = await storeService.updateReadAuthConfig(enabled: true);

      expect(config.readAuthEnabled, true);
    });
  });
}
