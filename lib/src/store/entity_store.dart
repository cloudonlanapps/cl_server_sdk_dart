import 'dart:io';

import 'package:cl_basic_types/cl_basic_types.dart';
import 'package:cl_extensions/cl_extensions.dart' show CLLogger, NotNullValue;
import 'package:meta/meta.dart';
import 'package:store/store.dart';

import '../managers/store_manager.dart';
import '../models/cl_server.dart';
import '../models/remote_service_location_config.dart';
import '../models/store_models.dart';
import 'entity_mapper.dart';
import 'query_filter_adapter.dart';

@immutable
class OnlineEntityStore extends EntityStore with CLLogger {
  const OnlineEntityStore({required super.config, required this.server});

  final CLServer server;

  @override
  bool get isAlive => server.connected;

  /// Helper to get StoreManager with proper error messages.
  StoreManager _requireStoreManager() {
    final storeManager = server.storeManager;
    if (storeManager != null) return storeManager;

    // Provide helpful error message
    if (!server.connected) {
      throw Exception('Server not connected');
    } else if (!server.isAuthenticated) {
      throw Exception('Not authenticated - please login');
    } else {
      throw Exception('StoreManager not available');
    }
  }

  @override
  Future<CLEntity?> get({String? md5, String? label}) async {
    final storeManager = _requireStoreManager();

    try {
      // Use new lookupEntity endpoint (added in Phase 1)
      final result = await storeManager.lookupEntity(md5: md5, label: label);

      if (!result.isSuccess || result.data == null) return null;

      return EntityMapper.fromSdkEntity(result.data!);
    } on Exception {
      return null;
    }
  }

  @override
  Future<CLEntity?> getByID(int id) async {
    final storeManager = _requireStoreManager();

    try {
      final result = await storeManager.readEntity(id);
      if (!result.isSuccess || result.data == null) return null;

      return EntityMapper.fromSdkEntity(result.data!);
    } on Exception {
      return null;
    }
  }

  @override
  Future<PagedResult<CLEntity>> getAll([StoreQuery<CLEntity>? query]) async {
    // Handle isHidden filter (client-side only, server doesn't support)
    if (query?.map['isHidden'] == 1) {
      return const PagedResult(
        items: [],
        pagination: PaginationMetadata(
          page: 1,
          pageSize: 20,
          totalItems: 0,
          totalPages: 1,
          hasNext: false,
          hasPrev: false,
        ),
      );
    }

    final storeManager = _requireStoreManager();

    try {
      // Adapt query to SDK parameters
      final adapted = QueryFilterAdapter.adaptQuery(query);

      // Special case: direct ID lookup
      if (adapted.idFilter != null) {
        final entity = await getByID(adapted.idFilter!);
        return PagedResult(
          items: entity != null ? [entity] : [],
          pagination: const PaginationMetadata(
            page: 1,
            pageSize: 20,
            totalItems: 1,
            totalPages: 1,
            hasNext: false,
            hasPrev: false,
          ),
        );
      }

      // Special case: exact label match with no other filters
      if (adapted.labelFilter != null && adapted.otherFilters.isEmpty) {
        final entity = await get(label: adapted.labelFilter);
        return PagedResult(
          items: entity != null ? [entity] : [],
          pagination: const PaginationMetadata(
            page: 1,
            pageSize: 20,
            totalItems: 1,
            totalPages: 1,
            hasNext: false,
            hasPrev: false,
          ),
        );
      }

      // Fetch entities - all filters are server-side now!
      log(
        'OnlineEntityStore.getAll: parentId=${adapted.parentId}, isCollection=${adapted.isCollection}, page=${query?.page}',
      );
      final result = await storeManager.listEntities(
        page: query?.page ?? 1,
        pageSize: query?.pageSize ?? 20,
        md5: adapted.md5,
        mimeType: adapted.mimeType,
        type: adapted.type,
        width: adapted.width,
        height: adapted.height,
        fileSizeMin: adapted.fileSizeMin,
        fileSizeMax: adapted.fileSizeMax,
        dateFrom: adapted.dateFrom,
        dateTo: adapted.dateTo,
        excludeDeleted: adapted.excludeDeleted ?? true,
        parentId: adapted.parentId, // ✅ Phase 1 complete
        isCollection: adapted.isCollection, // ✅ Phase 1 complete
      );

      if (!result.isSuccess || result.data == null) {
        log('OnlineEntityStore.getAll failed: ${result.error}');
        return PagedResult(
          items: const [],
          pagination: PaginationMetadata(
            page: query?.page ?? 1,
            pageSize: query?.pageSize ?? 20,
            totalItems: 0,
            totalPages: 1,
            hasNext: false,
            hasPrev: false,
          ),
        );
      }

      log(
        'OnlineEntityStore.getAll successful: ${result.data!.items.length} items returned',
      );
      var entities = EntityMapper.fromSdkEntities(result.data!.items);

      // Apply client-side filters ONLY for client-side fields (pin)
      if (adapted.pinFilter != null) {
        entities = entities.where((e) {
          return adapted.pinFilter == NotNullValue
              ? e.pin != null
              : e.pin == null;
        }).toList();
      }

      return PagedResult(
        items: entities,
        pagination: PaginationMetadata(
          page: result.data!.pagination.page,
          pageSize: result.data!.pagination.pageSize,
          totalItems: result.data!.pagination.totalItems,
          totalPages: result.data!.pagination.totalPages,
          hasNext: result.data!.pagination.hasNext,
          hasPrev: result.data!.pagination.hasPrev,
        ),
      );
    } on Exception catch (e) {
      log('OnlineEntityStore.getAll error: $e');
      return PagedResult(
        items: const [],
        pagination: PaginationMetadata(
          page: query?.page ?? 1,
          pageSize: query?.pageSize ?? 20,
          totalItems: 0,
          totalPages: 1,
          hasNext: false,
          hasPrev: false,
        ),
      );
    }
  }

  @override
  Future<CLEntity?> upsert(CLEntity curr, {String? path}) async {
    final storeManager = _requireStoreManager();

    try {
      final StoreOperationResult<Entity> result;

      if (curr.id == null) {
        // Create new entity
        result = await storeManager.createEntity(
          isCollection: curr.isCollection,
          label: curr.label,
          description: curr.description,
          parentId: curr.parentId,
          mediaPath: path,
        );
      } else {
        // Update existing entity
        if (path != null) {
          // If media file is provided, we MUST use updateEntity (PUT)
          // because patchEntity doesn't support file upload
          result = await storeManager.updateEntity(
            curr.id!,
            label: curr.label ?? '',
            description: curr.description,
            isCollection: curr.isCollection,
            parentId: curr.parentId,
            mediaPath: path,
          );
        } else {
          // If no media file, use patchEntity (PATCH) for metadata updates
          // This supports partial updates and is safer for moves/renames
          result = await storeManager.patchEntity(
            curr.id!,
            label: curr.label,
            description: curr.description,
            isCollection: curr.isCollection,
            parentId: curr.parentId,
            isDeleted: curr.isDeleted,
          );
        }
      }

      if (!result.isSuccess) {
        throw Exception(result.error ?? 'Upsert failed');
      }

      return EntityMapper.fromSdkEntity(result.data!);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> delete(CLEntity item) async {
    if (item.id == null) return false;

    final storeManager = _requireStoreManager();

    try {
      final result = await storeManager.deleteEntity(item.id!);
      return result.isSuccess;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> download(CLEntity item, File targetFile) async {
    if (item.id == null) {
      log('Download failed: Entity ID is null');
      return false;
    }

    final storeManager = _requireStoreManager();

    try {
      log('Downloading media for entity ${item.id} from remote...');
      final result = await storeManager.downloadMedia(item.id!);
      if (result.isSuccess && result.data != null) {
        await targetFile.writeAsBytes(result.data!);
        log(
          'Download successful: ${result.data!.length} bytes written to ${targetFile.path}',
        );
        return true;
      }
      log('Download failed: ${result.error}');
      return false;
    } on Exception catch (e) {
      log('Download exception: $e');
      return false;
    }
  }

  @override
  Uri? mediaUri(CLEntity item) {
    if (item.id == null) return null;

    return Uri.parse(
      '${(config as RemoteServiceLocationConfig).storeUrl}/entities/${item.id}/media',
    );
  }

  @override
  Uri? previewUri(CLEntity item) {
    if (item.id == null) return null;
    return Uri.parse(
      '${(config as RemoteServiceLocationConfig).storeUrl}/entities/${item.id}/preview?force=1',
    );
  }

  static Future<EntityStore> createStore({
    required RemoteServiceLocationConfig config,
    required CLServer server,
  }) async {
    return OnlineEntityStore(config: config, server: server);
  }

  @override
  String get logPrefix => 'OnlineEntityStore';
}

Future<EntityStore> createOnlineEntityStore({
  required RemoteServiceLocationConfig config,
  required CLServer server,
  required String storePath,
}) async {
  return OnlineEntityStore.createStore(server: server, config: config);
}
