import '../../core/exceptions.dart';
import '../../services/store_service.dart';
import '../models/result_model.dart';

/// Command to update an entity in store
///
/// UPDATE follows API constraints: requires entityId, label, isCollection
class UpdateEntityCommand {
  UpdateEntityCommand(this._storeService);

  final StoreService _storeService;

  /// Execute update entity operation
  ///
  /// Constraints (required by API):
  /// - [entityId] - Required, ID of entity to update
  /// - [label] - Required, entity label
  /// - [isCollection] - Required, collection flag
  /// - [description] - Optional, entity description
  /// - [parentId] - Optional, parent collection ID
  ///
  /// Returns StoreOperationResult with updated entity or error
  Future<StoreOperationResult<dynamic>> execute({
    required int entityId,
    required String label,
    required bool isCollection,
    String? description,
    int? parentId,
  }) async {
    try {
      // Validate constraints
      if (label.isEmpty) {
        return StoreOperationResult(
          error: 'Label is required for update operation',
        );
      }

      // Update entity
      final entity = await _storeService.updateEntity(
        entityId,
        label: label,
        isCollection: isCollection,
        description: description,
        parentId: parentId,
      );

      return StoreOperationResult(
        success: 'Entity updated successfully',
        data: entity,
      );
    } on PermissionException catch (e) {
      return StoreOperationResult(
        error: 'Permission denied: media_store_write permission required',
      );
    } on ResourceNotFoundException catch (e) {
      return StoreOperationResult(
        error: 'Entity not found: ${e.message}',
      );
    } on ValidationException catch (e) {
      return StoreOperationResult(
        error: 'Validation failed: ${e.message}',
      );
    } on CLServerException catch (e) {
      return StoreOperationResult(
        error: 'Server error: ${e.message}',
      );
    } catch (e) {
      return StoreOperationResult(
        error: 'Failed to update entity: ${e.toString()}',
      );
    }
  }
}
