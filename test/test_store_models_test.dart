import 'package:cl_server_dart_client/src/models/store_models.dart';
import 'package:test/test.dart';

void main() {
  group('TestEntity', () {
    test('test_entity_creation', () {
      final entity = Entity(
        id: 1,
        label: 'Test Entity',
        description: 'Test description',
        isCollection: false,
        addedDate: 1704067200000, // 2024-01-01 00:00:00
        updatedDate: 1704153600000, // 2024-01-02 00:00:00
        createDate: 1704067200000,
        fileSize: 1024,
        height: 800,
        width: 600,
        mimeType: 'image/jpeg',
        md5: 'abc123',
      );

      expect(entity.id, equals(1));
      expect(entity.label, equals('Test Entity'));
      expect(entity.description, equals('Test description'));
      expect(entity.isCollection, isFalse);
      expect(entity.fileSize, equals(1024));
    });

    test('test_entity_datetime_conversion', () {
      final entity = Entity(
        id: 1,
        addedDate: 1704067200000, // 2024-01-01 00:00:00 UTC
        updatedDate: 1704153600000, // 2024-01-02 00:00:00 UTC
        createDate: 1704067200000,
      );

      expect(entity.addedDateDatetime, isNotNull);
      expect(entity.addedDateDatetime!.year, equals(2024));
      expect(entity.addedDateDatetime!.month, equals(1));
      expect(entity.addedDateDatetime!.day, equals(1));

      expect(entity.updatedDateDatetime, isNotNull);
      expect(entity.updatedDateDatetime!.year, equals(2024));
      expect(entity.updatedDateDatetime!.month, equals(1));
      expect(entity.updatedDateDatetime!.day, equals(2));
    });

    test('test_entity_none_datetime', () {
      final entity = Entity(
        id: 1,
      );

      expect(entity.addedDateDatetime, isNull);
      expect(entity.updatedDateDatetime, isNull);
      expect(entity.createDateDatetime, isNull);
    });

    test('test_entity_optional_fields', () {
      final entity = Entity(id: 1);

      expect(entity.id, equals(1));
      expect(entity.label, isNull);
      expect(entity.description, isNull);
      expect(entity.isCollection, isNull);
    });
  });

  group('TestEntityPagination', () {
    test('test_pagination_creation', () {
      final pagination = EntityPagination(
        page: 1,
        pageSize: 20,
        totalItems: 100,
        totalPages: 5,
        hasNext: true,
        hasPrev: false,
      );

      expect(pagination.page, equals(1));
      expect(pagination.pageSize, equals(20));
      expect(pagination.totalItems, equals(100));
      expect(pagination.totalPages, equals(5));
      expect(pagination.hasNext, isTrue);
      expect(pagination.hasPrev, isFalse);
    });
  });

  group('TestEntityListResponse', () {
    test('test_entity_list_response', () {
      final entities = [
        Entity(id: 1, label: 'Entity 1'),
        Entity(id: 2, label: 'Entity 2'),
      ];
      final pagination = EntityPagination(
        page: 1,
        pageSize: 20,
        totalItems: 2,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );

      final response = EntityListResponse(
        items: entities,
        pagination: pagination,
      );

      expect(response.items.length, equals(2));
      expect(response.items[0].id, equals(1));
      expect(response.pagination.totalItems, equals(2));
    });
  });

  group('TestEntityVersion', () {
    test('test_entity_version_creation', () {
      final version = EntityVersion(
        version: 1,
        transactionId: 100,
        endTransactionId: 200,
        operationType: 'INSERT',
        label: 'Original Label',
        description: 'Original description',
      );

      expect(version.version, equals(1));
      expect(version.transactionId, equals(100));
      expect(version.endTransactionId, equals(200));
      expect(version.operationType, equals('INSERT'));
      expect(version.label, equals('Original Label'));
    });
  });

  group('TestStorePref', () {
    test('test_store_config_creation', () {
      final config = StorePref(
        guestMode: false,
        updatedAt: 1704067200000,
        updatedBy: 'admin',
      );

      expect(config.guestMode, isFalse);
      expect(config.updatedAt, equals(1704067200000));
      expect(config.updatedBy, equals('admin'));
    });

    test('test_store_config_datetime', () {
      final config = StorePref(
        guestMode: true,
        updatedAt: 1704067200000,
      );

      expect(config.updatedAtDatetime, isNotNull);
      expect(config.updatedAtDatetime!.year, equals(2024));
    });
  });

  group('TestStoreOperationResult', () {
    test('test_success_result', () {
      final entity = Entity(id: 1, label: 'Test');
      final result = StoreOperationResult<Entity>(
        success: 'Entity created successfully',
        data: entity,
      );

      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.data, isNotNull);
      expect(result.data!.id, equals(1));
      expect(result.success, equals('Entity created successfully'));
      expect(result.error, isNull);
    });

    test('test_error_result', () {
      final result = StoreOperationResult<Entity>(
        error: 'Unauthorized: Invalid token',
      );

      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.data, isNull);
      expect(result.error, equals('Unauthorized: Invalid token'));
      expect(result.success, isNull);
    });

    test('test_value_or_throw_success', () {
      final entity = Entity(id: 1, label: 'Test');
      final result = StoreOperationResult<Entity>(
        success: 'Success',
        data: entity,
      );

      final value = result.valueOrThrow();
      expect(value.id, equals(1));
      expect(value.label, equals('Test'));
    });

    test('test_value_or_throw_error', () {
      final result = StoreOperationResult<Entity>(
        error: 'Operation failed',
      );

      expect(
        result.valueOrThrow,
        throwsA(predicate((e) => e.toString().contains('Operation failed'))),
      );
    });

    test('test_value_or_throw_no_data', () {
      final result = StoreOperationResult<Entity>(
        success: 'Success',
      );

      expect(
        result.valueOrThrow,
        throwsA(
          predicate((e) => e.toString().contains('succeeded but data is None')),
        ),
      );
    });

    test('test_result_with_list_type', () {
      final versions = [
        EntityVersion(version: 1, transactionId: 100),
        EntityVersion(version: 2, transactionId: 101),
      ];
      final result = StoreOperationResult<List<EntityVersion>>(
        success: 'Versions retrieved',
        data: versions,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.length, equals(2));
      expect(result.data![0].version, equals(1));
    });

    test('test_result_json_serialization', () {
      final entity = Entity(id: 1, label: 'Test');
      final result = StoreOperationResult<Entity>(
        success: 'Success',
        data: entity,
      );

      // Should be able to convert to dict
      final resultDict = result.toMap((e) => e.toMap());
      expect(resultDict['success'], equals('Success'));
      expect((resultDict['data'] as Map<String, dynamic>)['id'], equals(1));
      expect(resultDict['error'], isNull);
    });
  });
}
