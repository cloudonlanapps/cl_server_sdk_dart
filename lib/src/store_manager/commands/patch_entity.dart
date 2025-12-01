import '../../core/exceptions.dart';
import '../../services/store_service.dart';
import '../models/result_model.dart';

/// Command to patch an entity in store
///
/// PATCH allows partial updates: only entityId is required, plus at least one field to patch
class PatchEntityCommand {
  PatchEntityCommand(this._storeService);

  final StoreService _storeService;

  /// Execute patch entity operation
  ///
  /// Constraints (by API):
  /// - [entityId] - Required, ID of entity to patch
  /// - All other fields optional (update only provided fields)
  ///
  /// Returns StoreOperationResult with patched entity or error
  Future<StoreOperationResult<dynamic>> execute({
    required int entityId,
    String? label,
    String? description,
    int? parentId,
    bool? isDeleted,
  }) async {
    try {
      // Validate that at least one field is provided to patch
      final hasFieldsToPatch = label != null ||
          description != null ||
          parentId != null ||
          isDeleted != null;

      if (!hasFieldsToPatch) {
        return StoreOperationResult(
          error: 'At least one field is required for patch operation',
        );
      }

      // Patch entity
      final entity = await _storeService.patchEntity(
        entityId,
        label: label,
        description: description,
        parentId: parentId,
        isDeleted: isDeleted,
      );

      return StoreOperationResult(
        success: 'Entity patched successfully',
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
        error: 'Failed to patch entity: ${e.toString()}',
      );
    }
  }
}
