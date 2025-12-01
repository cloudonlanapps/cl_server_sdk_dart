import '../services/store_service.dart';
import '../session/session_manager.dart';
import 'commands/create_entity.dart';
import 'commands/delete_entity.dart';
import 'commands/list_entities.dart';
import 'commands/patch_entity.dart';
import 'commands/read_entity.dart';
import 'commands/update_entity.dart';
import 'models/result_model.dart';

/// Store Manager module for managing store entities
///
/// Provides both guest (unauthenticated) and authenticated modes.
/// All operations return StoreOperationResult with success/error information.
///
/// Example:
/// ```dart
/// // Guest mode
/// final manager = StoreManager.guest();
/// final result = await manager.listEntities();
///
/// // Authenticated mode
/// final sessionManager = await SessionManager.initialize();
/// await sessionManager.login('user', 'password');
/// final manager = await StoreManager.authenticated(
///   sessionManager: sessionManager,
/// );
/// final result = await manager.createEntity(label: 'My Entity');
/// ```
class StoreManager {
  StoreManager({required StoreService storeService})
    : _storeService = storeService;

  final StoreService _storeService;

  /// Create guest mode store manager (no authentication)
  ///
  /// [baseUrl] - Store service base URL (default: http://localhost:8001)
  factory StoreManager.guest({String? baseUrl}) {
    final storeService = StoreService(
      baseUrl: baseUrl ?? 'http://localhost:8001',
    );
    return StoreManager(storeService: storeService);
  }

  /// Create authenticated mode store manager
  ///
  /// Requires an authenticated SessionManager instance.
  /// [sessionManager] - Authenticated session manager
  /// [baseUrl] - Store service base URL (optional, overrides session config)
  ///
  /// Returns StoreManager instance with authenticated StoreService
  static Future<StoreManager> authenticated({
    required SessionManager sessionManager,
    String? baseUrl,
  }) async {
    final storeService = await sessionManager.createStoreService(
      baseUrl: baseUrl,
    );
    return StoreManager(storeService: storeService);
  }

  /// List entities from store
  ///
  /// [page] - Page number (default: 1)
  /// [pageSize] - Items per page (default: 20)
  /// [searchQuery] - Optional search query
  ///
  /// Returns StoreOperationResult with EntityListResponse or error
  Future<StoreOperationResult<dynamic>> listEntities({
    int? page,
    int? pageSize,
    String? searchQuery,
  }) =>
    ListEntitiesCommand(_storeService).execute(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
    );

  /// Create a new entity
  ///
  /// [label] - Optional entity label
  /// [description] - Optional entity description
  /// [isCollection] - Whether to create as collection (default: false)
  /// [collectionId] - Optional numeric ID of parent collection
  /// [parentLabel] - Optional unique label of parent collection
  ///
  /// If [parentLabel] is provided, resolves collection by label or creates new one.
  /// If [collectionId] is provided, uses it directly.
  ///
  /// Returns StoreOperationResult with created Entity or error
  Future<StoreOperationResult<dynamic>> createEntity({
    String? label,
    String? description,
    bool isCollection = false,
    String? collectionId,
    String? parentLabel,
  }) =>
    CreateEntityCommand(_storeService).execute(
      label: label,
      description: description,
      isCollection: isCollection,
      collectionId: collectionId,
      parentLabel: parentLabel,
    );

  /// Read a single entity by ID
  ///
  /// [entityId] - ID of entity to read
  ///
  /// Returns StoreOperationResult with Entity or error
  Future<StoreOperationResult<dynamic>> readEntity({
    required int entityId,
  }) =>
    ReadEntityCommand(_storeService).execute(entityId: entityId);

  /// Update an entity (full update, requires label and isCollection)
  ///
  /// API constraint: requires entityId, label, and isCollection
  ///
  /// [entityId] - ID of entity to update (required)
  /// [label] - Entity label (required)
  /// [isCollection] - Whether entity is collection (required)
  /// [description] - Optional entity description
  /// [parentId] - Optional parent collection ID
  ///
  /// Returns StoreOperationResult with updated Entity or error
  Future<StoreOperationResult<dynamic>> updateEntity({
    required int entityId,
    required String label,
    required bool isCollection,
    String? description,
    int? parentId,
  }) =>
    UpdateEntityCommand(_storeService).execute(
      entityId: entityId,
      label: label,
      isCollection: isCollection,
      description: description,
      parentId: parentId,
    );

  /// Patch an entity (partial update)
  ///
  /// API constraint: requires entityId only, plus at least one field to patch
  ///
  /// [entityId] - ID of entity to patch (required)
  /// [label] - Optional new label
  /// [description] - Optional new description
  /// [parentId] - Optional new parent collection ID
  /// [isDeleted] - Optional deletion flag
  ///
  /// Returns StoreOperationResult with patched Entity or error
  Future<StoreOperationResult<dynamic>> patchEntity({
    required int entityId,
    String? label,
    String? description,
    int? parentId,
    bool? isDeleted,
  }) =>
    PatchEntityCommand(_storeService).execute(
      entityId: entityId,
      label: label,
      description: description,
      parentId: parentId,
      isDeleted: isDeleted,
    );

  /// Delete an entity by ID
  ///
  /// [entityId] - ID of entity to delete
  ///
  /// Returns StoreOperationResult with success or error
  Future<StoreOperationResult<dynamic>> deleteEntity({
    required int entityId,
  }) =>
    DeleteEntityCommand(_storeService).execute(entityId: entityId);
}
