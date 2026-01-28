import 'dart:async';

import 'package:cl_server_dart_client/src/clients/store_client.dart';
import 'package:cl_server_dart_client/src/managers/store_manager.dart';
import 'package:cl_server_dart_client/src/models/store_models.dart';
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

    test('test_create_entity', () async {
      final entity = Entity(
        id: 1,
        label: 'New',
        isCollection: false,
        isDeleted: false,
        addedDate: 0,
        updatedDate: 0,
      );

      when(
        () => mockStoreClient.createEntity(isCollection: false, label: 'New'),
      ).thenAnswer((_) async => entity);

      final result = await manager.createEntity(label: 'New');

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(entity));
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
