import '../../core/exceptions.dart';
import '../../services/store_service.dart';
import '../models/result_model.dart';

/// Command to delete an entity from store
class DeleteEntityCommand {
  DeleteEntityCommand(this._storeService);

  final StoreService _storeService;

  /// Execute delete entity operation
  ///
  /// [entityId] - ID of entity to delete
  ///
  /// Returns StoreOperationResult with success or error
  Future<StoreOperationResult<dynamic>> execute({
    required int entityId,
  }) async {
    try {
      await _storeService.deleteEntity(entityId);

      return StoreOperationResult(
        success: 'Entity deleted successfully',
        data: null,
      );
    } on PermissionException catch (e) {
      return StoreOperationResult(
        error: 'Permission denied: ${e.message}',
      );
    } on ResourceNotFoundException catch (e) {
      return StoreOperationResult(
        error: 'Entity not found: ${e.message}',
      );
    } on CLServerException catch (e) {
      return StoreOperationResult(
        error: 'Server error: ${e.message}',
      );
    } catch (e) {
      return StoreOperationResult(
        error: 'Failed to delete entity: ${e.toString()}',
      );
    }
  }
}
