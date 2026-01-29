import 'dart:async';

import 'package:cl_server_dart_client/src/clients/store_client.dart';
import 'package:cl_server_dart_client/src/managers/store_manager.dart';
import 'package:cl_server_dart_client/src/models/store_models.dart';
import 'package:cl_server_dart_client/src/exceptions.dart';
import 'package:cl_server_dart_client/src/mqtt_monitor.dart';
import 'package:cl_server_dart_client/src/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockStoreClient extends Mock implements StoreClient {}

// MockServerConfig removed

class MockMQTTJobMonitor extends Mock implements MQTTJobMonitor {}

void main() {
  group('StoreManager', () {
    late MockStoreClient mockStoreClient;
    late StoreManager manager;

    setUp(() {
      mockStoreClient = MockStoreClient();
      manager = StoreManager(mockStoreClient);
    });

    test('test_list_entities_success', () async {
      final response = EntityListResponse(
        items: [
          Entity(
            id: 1,
            label: 'Test',
            isCollection: false,
            isDeleted: false,
            addedDate: 0,
            updatedDate: 0,
          ),
        ],
        pagination: EntityPagination(
          page: 1,
          pageSize: 20,
          totalItems: 1,
          totalPages: 1,
          hasNext: false,
          hasPrev: false,
        ),
      );

      when(
        () => mockStoreClient.listEntities(),
      ).thenAnswer((_) async => response);

      final result = await manager.listEntities();

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(response));
      verify(
        () => mockStoreClient.listEntities(),
      ).called(1);
    });

    test('test_list_entities_with_search', () async {
      final response = EntityListResponse(
        items: [],
        pagination: EntityPagination(
          page: 1,
          pageSize: 10,
          totalItems: 0,
          totalPages: 0,
          hasNext: false,
          hasPrev: false,
        ),
      );

      when(
        () => mockStoreClient.listEntities(
          page: 1,
          pageSize: 10,
          searchQuery: 'test query',
        ),
      ).thenAnswer((_) async => response);

      final result = await manager.listEntities(
        page: 1,
        pageSize: 10,
        searchQuery: 'test query',
      );

      expect(result.isSuccess, isTrue);
      verify(
        () => mockStoreClient.listEntities(
          page: 1,
          pageSize: 10,
          searchQuery: 'test query',
        ),
      ).called(1);
    });

    test('test_read_entity_success', () async {
      final entity = Entity(
        id: 123,
        label: 'Test Entity',
        isCollection: false,
        isDeleted: false,
        addedDate: 0,
        updatedDate: 0,
      );
      when(
        () => mockStoreClient.readEntity(123),
      ).thenAnswer((_) async => entity);

      final result = await manager.readEntity(123);

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(entity));
      verify(() => mockStoreClient.readEntity(123)).called(1);
    });

    test('test_read_entity_with_version', () async {
      final entity = Entity(
        id: 123,
        label: 'Old Label',
        isCollection: false,
        isDeleted: false,
        addedDate: 0,
        updatedDate: 0,
      );
      when(
        () => mockStoreClient.readEntity(123, version: 2),
      ).thenAnswer((_) async => entity);

      final result = await manager.readEntity(123, version: 2);

      expect(result.isSuccess, isTrue);
      verify(() => mockStoreClient.readEntity(123, version: 2)).called(1);
    });

    test('test_get_versions_success', () async {
      final versions = [
        EntityVersion(version: 1, transactionId: 100),
        EntityVersion(version: 2, transactionId: 101),
      ];
      when(
        () => mockStoreClient.getVersions(123),
      ).thenAnswer((_) async => versions);

      final result = await manager.getVersions(123);

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(versions));
      verify(() => mockStoreClient.getVersions(123)).called(1);
    });

    test('test_create_entity_with_file', () async {
      final entity = Entity(
        id: 2,
        label: 'Photo',
        isCollection: false,
        isDeleted: false,
        addedDate: 0,
        updatedDate: 0,
      );
      when(
        () => mockStoreClient.createEntity(
          isCollection: false,
          label: 'Photo',
          description: 'Test photo',
          imagePath: '/tmp/test.jpg',
        ),
      ).thenAnswer((_) async => (entity, 201));

      final result = await manager.createEntity(
        label: 'Photo',
        description: 'Test photo',
        isCollection: false,
        imagePath: '/tmp/test.jpg',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.id, equals(2));
    });

    test('test_update_entity_success', () async {
      final entity = Entity(
        id: 123,
        label: 'Updated Label',
        isCollection: false,
        isDeleted: false,
        addedDate: 0,
        updatedDate: 0,
      );
      when(
        () => mockStoreClient.updateEntity(
          123,
          isCollection: false,
          label: 'Updated Label',
        ),
      ).thenAnswer((_) async => entity);

      final result = await manager.updateEntity(123, label: 'Updated Label');

      expect(result.isSuccess, isTrue);
      expect(result.data?.label, equals('Updated Label'));
    });

    test('test_patch_entity_success', () async {
      final entity = Entity(
        id: 123,
        label: 'Patched Label',
        isCollection: false,
        isDeleted: false,
        addedDate: 0,
        updatedDate: 0,
      );
      when(
        () => mockStoreClient.patchEntity(123, label: 'Patched Label'),
      ).thenAnswer((_) async => entity);

      final result = await manager.patchEntity(123, label: 'Patched Label');

      expect(result.isSuccess, isTrue);
      verify(
        () => mockStoreClient.patchEntity(123, label: 'Patched Label'),
      ).called(1);
    });

    test('test_patch_entity_soft_delete', () async {
      final entity = Entity(
        id: 123,
        isDeleted: true,
        label: 'Deleted',
        isCollection: false,
        addedDate: 0,
        updatedDate: 0,
      );
      when(
        () => mockStoreClient.patchEntity(123, isDeleted: true),
      ).thenAnswer((_) async => entity);

      final result = await manager.patchEntity(123, isDeleted: true);

      expect(result.isSuccess, isTrue);
      expect(result.data?.isDeleted, isTrue);
    });

    test('test_delete_entity_success', () async {
      when(
        () => mockStoreClient.patchEntity(
          any(),
          isDeleted: any(named: 'isDeleted'),
        ),
      ).thenAnswer(
        (_) async => Entity(
          id: 123,
          isDeleted: true,
          addedDate: 0,
          updatedDate: 0,
          isCollection: false,
          label: '',
        ),
      );
      when(() => mockStoreClient.deleteEntity(123)).thenAnswer((_) async {});

      final result = await manager.deleteEntity(123);

      expect(result.isSuccess, isTrue);
      verify(() => mockStoreClient.deleteEntity(123)).called(1);
    });

    test('test_get_config_success', () async {
      final config = StoreConfig(
        guestMode: false,
        updatedAt: 0,
        updatedBy: 'admin',
      );
      when(() => mockStoreClient.getConfig()).thenAnswer((_) async => config);

      final result = await manager.getConfig();

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(config));
    });

    test('test_update_guest_mode_success', () async {
      final config = StoreConfig(
        guestMode: true,
        updatedAt: 0,
        updatedBy: 'admin',
      );
      when(
        () => mockStoreClient.updateGuestMode(guestMode: true),
      ).thenAnswer((_) async => config);

      final result = await manager.updateGuestMode(guestMode: true);

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(config));
    });

    group('ErrorHandling', () {
      test('test_unauthorized_error', () async {
        when(
          () => mockStoreClient.listEntities(),
        ).thenThrow(AuthenticationError());

        final result = await manager.listEntities();

        expect(result.isError, isTrue);
        expect(result.error, contains('Unauthorized'));
      });

      test('test_forbidden_error', () async {
        when(
          () =>
              mockStoreClient.createEntity(isCollection: false, label: 'Test'),
        ).thenThrow(PermissionError('Forbidden'));

        final result = await manager.createEntity(
          isCollection: false,
          label: 'Test',
        );

        expect(result.isError, isTrue);
        expect(result.error, contains('Forbidden'));
      });

      test('test_not_found_error', () async {
        when(
          () => mockStoreClient.readEntity(999),
        ).thenThrow(JobNotFoundError('Not Found'));

        final result = await manager.readEntity(999);

        expect(result.isError, isTrue);
        expect(result.error, contains('Not Found'));
      });

      test('test_validation_error', () async {
        when(
          () => mockStoreClient.listEntities(),
        ).thenThrow(ComputeClientError('HTTP 422: Validation Error'));

        final result = await manager.listEntities();

        expect(result.isError, isTrue);
        expect(result.error, contains('Validation Error'));
      });

      test('test_error_response_without_json', () async {
        when(
          () => mockStoreClient.listEntities(),
        ).thenThrow(ComputeClientError('HTTP 500: Internal Server Error'));

        final result = await manager.listEntities();

        expect(result.isError, isTrue);
        expect(result.error, contains('Internal Server Error'));
      });

      test('test_unexpected_exception', () async {
        when(
          () => mockStoreClient.listEntities(),
        ).thenThrow(Exception('Unexpected'));

        final result = await manager.listEntities();

        expect(result.isError, isTrue);
        expect(result.error, contains('Unexpected error'));
      });
    });

    test('test_monitor_entity', () async {
      final monitor = MockMQTTJobMonitor();
      manager = StoreManager(mockStoreClient, const ServerConfig(), monitor);

      when(
        () => monitor.subscribeEntityStatus(any(), any(), any()),
      ).thenReturn('sub_id');
      when(() => monitor.isConnected).thenReturn(true);

      // Need to configure server config to avoid null dereference or defaults?
      // Check implementation: _config?.storeUrl. If null, defaults port 8001.

      await manager.monitorEntity(123, (p) {});

      verify(() => monitor.subscribeEntityStatus(123, any(), any())).called(1);
    });

    test('test_wait_for_entity_status_success', () async {
      final monitor = MockMQTTJobMonitor();
      manager = StoreManager(mockStoreClient, const ServerConfig(), monitor);
      // completer removed

      when(() => monitor.isConnected).thenReturn(true);
      when(() => monitor.subscribeEntityStatus(any(), any(), any())).thenAnswer(
        (invocation) {
          final callback =
              invocation.positionalArguments[2]
                  as void Function(EntityStatusPayload);
          // Simulate callback immediately or after delay
          Future.delayed(const Duration(milliseconds: 10), () {
            callback(
              EntityStatusPayload(
                entityId: 123,
                status: 'completed',
                timestamp: 123,
              ),
            );
          });
          return 'sub_id';
        },
      );
      when(() => monitor.unsubscribeEntityStatus(any())).thenAnswer((_) {});

      final result = await manager.waitForEntityStatus(
        123,
      );

      expect(result.status, equals('completed'));
    });

    test('test_wait_for_entity_status_timeout', () async {
      final monitor = MockMQTTJobMonitor();
      const config = ServerConfig();
      manager = StoreManager(mockStoreClient, config, monitor);

      when(() => monitor.isConnected).thenReturn(true);
      when(
        () => monitor.subscribeEntityStatus(any(), any(), any()),
      ).thenReturn('sub_id');
      when(() => monitor.unsubscribeEntityStatus(any())).thenAnswer((_) {});

      // No callback fired

      expect(
        () => manager.waitForEntityStatus(
          123,
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
