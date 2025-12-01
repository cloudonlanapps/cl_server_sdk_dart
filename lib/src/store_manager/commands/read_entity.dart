import '../../core/exceptions.dart';
import '../../services/store_service.dart';
import '../models/result_model.dart';

/// Command to read a single entity from store
class ReadEntityCommand {
  ReadEntityCommand(this._storeService);

  final StoreService _storeService;

  /// Execute read entity operation
  ///
  /// [entityId] - ID of entity to read
  ///
  /// Returns StoreOperationResult with entity data or error
  Future<StoreOperationResult<dynamic>> execute({
    required int entityId,
  }) async {
    try {
      final entity = await _storeService.getEntity(entityId);

      return StoreOperationResult(
        success: 'Entity retrieved successfully',
        data: entity,
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
        error: 'Failed to read entity: ${e.toString()}',
      );
    }
  }
}
