import 'package:cl_server_dart_client/src/models/store_models.dart';
import 'package:test/test.dart';

void main() {
  group('Entity', () {
    test('test_entity_serialization', () {
      final json = {
        'id': 1,
        'label': 'Test',
        'is_collection': false,
        'is_deleted': false,
        'created_at': 1234567890,
        'updated_at': 1234567890,
        'versions': <dynamic>[],
      };

      final entity = Entity.fromMap(json);
      expect(entity.id, equals(1));
      expect(entity.label, equals('Test'));
      expect(entity.isCollection, isFalse);

      final map = entity.toMap();
      expect(map['id'], equals(1));
      expect(map['label'], equals('Test'));
    });
  });

  group('EntityListResponse', () {
    test('test_list_response_serialization', () {
      final json = {
        'items': [
          {
            'id': 1,
            'label': 'Test',
            'is_collection': false,
            'is_deleted': false,
            'created_at': 1234567890,
            'updated_at': 1234567890,
            'versions': <dynamic>[],
          },
        ],
        'pagination': {
          'total_items': 1,
          'total_pages': 1,
          'page': 1,
          'page_size': 20,
          'has_next': false,
          'has_prev': false,
        },
      };

      final response = EntityListResponse.fromMap(json);
      expect(response.items.length, equals(1));
      expect(response.pagination.totalItems, equals(1));
    });
  });

  // Add other model tests as needed (EntityVersion, etc)
}
