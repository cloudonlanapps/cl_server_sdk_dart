import '../../core/exceptions.dart';
import '../../services/store_service.dart';
import '../models/result_model.dart';

/// Command to create an entity in store
class CreateEntityCommand {
  CreateEntityCommand(this._storeService);

  final StoreService _storeService;

  /// Execute create entity operation
  ///
  /// [label] - Optional entity label
  /// [description] - Optional entity description
  /// [isCollection] - Whether to create as collection (default: false)
  /// [collectionId] - Numeric ID of parent collection
  /// [parentLabel] - Unique label of parent collection
  ///
  /// If [parentLabel] is provided, resolves collection by label or creates new one.
  /// If [collectionId] is provided, uses it directly.
  ///
  /// Returns StoreOperationResult with created entity or error
  Future<StoreOperationResult<dynamic>> execute({
    String? label,
    String? description,
    bool isCollection = false,
    String? collectionId,
    String? parentLabel,
  }) async {
    try {
      // Resolve parent collection
      int? resolvedParentId;

      if (parentLabel != null) {
        // Find collection by label (unique) or create if not exists
        resolvedParentId = await _resolveOrCreateCollection(parentLabel);
      } else if (collectionId != null) {
        // Use provided collection ID directly
        resolvedParentId = int.tryParse(collectionId);
      }

      // Create entity
      final entity = await _storeService.createEntity(
        isCollection: isCollection,
        label: label,
        description: description,
        parentId: resolvedParentId,
      );

      return StoreOperationResult(
        success: 'Entity created successfully',
        data: entity,
      );
    } on PermissionException catch (e) {
      return StoreOperationResult(
        error: 'Permission denied: media_store_write permission required',
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
        error: 'Failed to create entity: ${e.toString()}',
      );
    }
  }

  /// Resolve collection by label or create if not exists
  ///
  /// [label] - Unique collection label
  ///
  /// Returns collection ID or null if resolution fails
  Future<int?> _resolveOrCreateCollection(String label) async {
    try {
      // List collections to find by label
      final response = await _storeService.listEntities();

      // Find collection with matching label
      final existingList = response.items.where(
        (e) => e.isCollection && e.label == label,
      );

      if (existingList.isNotEmpty) {
        return existingList.first.id;
      }

      // Create new collection if not found
      final newCollection = await _storeService.createEntity(
        isCollection: true,
        label: label,
      );
      return newCollection.id;
    } on Exception {
      // If can't resolve, return null and let caller handle
      return null;
    }
  }
}
