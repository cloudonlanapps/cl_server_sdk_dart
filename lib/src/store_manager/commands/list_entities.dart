import '../../core/exceptions.dart';
import '../../services/store_service.dart';
import '../models/result_model.dart';

/// Command to list entities from store
class ListEntitiesCommand {
  ListEntitiesCommand(this._storeService);

  final StoreService _storeService;

  /// Execute list entities operation
  ///
  /// [page] - Page number (1-indexed, default: 1)
  /// [pageSize] - Items per page (default: 20)
  /// [searchQuery] - Optional search query
  ///
  /// Returns StoreOperationResult with entity list or error
  Future<StoreOperationResult<dynamic>> execute({
    int? page,
    int? pageSize,
    String? searchQuery,
  }) async {
    try {
      final response = await _storeService.listEntities(
        page: page ?? 1,
        pageSize: pageSize ?? 20,
        searchQuery: searchQuery,
      );

      return StoreOperationResult(
        success: 'Listed ${response.items.length} entities',
        data: response,
      );
    } on PermissionException catch (e) {
      return StoreOperationResult(
        error: 'Permission denied: ${e.message}',
      );
    } on ResourceNotFoundException catch (e) {
      return StoreOperationResult(
        error: 'Not found: ${e.message}',
      );
    } on CLServerException catch (e) {
      return StoreOperationResult(
        error: 'Server error: ${e.message}',
      );
    } catch (e) {
      return StoreOperationResult(
        error: 'Failed to list entities: ${e.toString()}',
      );
    }
  }
}
