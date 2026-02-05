import 'dart:async';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'integration_test_utils.dart';

void main() {
  const uuid = Uuid();

  group('Concurrency Integration Tests', () {
    test('test_concurrent_collection_creation', () async {
      if (!IntegrationTestConfig.isAuthEnabled) {
        print('Skipping concurrency test: credentials not provided');
        return;
      }

      const concurrencyCount = 10;
      final createdIds = <int>[];

      // Create multiple managers to simulate different clients
      final sessions = await Future.wait(
        List.generate(
          concurrencyCount,
          (_) => IntegrationHelper.createSession(),
        ),
      );
      final managers = sessions.map((s) => s.createStoreManager()).toList();

      try {
        final results = await Future.wait(
          managers.asMap().entries.map((entry) {
            final idx = entry.key;
            final manager = entry.value;
            final label = 'ConcTest_${idx}_${uuid.v4().substring(0, 6)}';
            return manager.createEntity(label: label, isCollection: true);
          }),
        );

        for (final result in results) {
          expect(
            result.isSuccess,
            isTrue,
            reason: 'Creation failed: ${result.error}',
          );
          if (result.data != null) {
            createdIds.add(result.data!.id);
          }
        }
      } finally {
        // Cleanup
        final cleanupSession = await IntegrationHelper.createSession();
        final cleanupManager = cleanupSession.createStoreManager();
        for (final id in createdIds) {
          await cleanupManager.deleteEntity(id);
        }
        await cleanupSession.close();
        for (final s in sessions) {
          await s.close();
        }
      }
    });

    test('test_concurrent_read_operations', () async {
      const concurrencyCount = 20;

      final sessions = await Future.wait(
        List.generate(
          concurrencyCount,
          (_) => IntegrationHelper.createSession(),
        ),
      );
      final managers = sessions.map((s) => s.createStoreManager()).toList();

      try {
        final results = await Future.wait(
          managers.map((m) => m.listEntities(pageSize: 10)),
        );

        for (final result in results) {
          expect(
            result.isSuccess,
            isTrue,
            reason: 'Read failed: ${result.error}',
          );
        }
      } finally {
        for (final s in sessions) {
          await s.close();
        }
      }
    });

    test('test_mixed_concurrent_operations', () async {
      if (!IntegrationTestConfig.isAuthEnabled) {
        print('Skipping mixed concurrency test: credentials not provided');
        return;
      }

      const concurrencyCount = 10;
      final createdIds = <int>[];

      final sessions = await Future.wait(
        List.generate(
          concurrencyCount,
          (_) => IntegrationHelper.createSession(),
        ),
      );
      final managers = sessions.map((s) => s.createStoreManager()).toList();

      try {
        final results = await Future.wait(
          managers.asMap().entries.map((entry) {
            final idx = entry.key;
            final manager = entry.value;
            if (idx.isEven) {
              final label = 'MixedConcTest_${idx}_${uuid.v4().substring(0, 6)}';
              return manager.createEntity(label: label, isCollection: true);
            } else {
              return manager.listEntities(pageSize: 10);
            }
          }),
        );

        for (final result in results) {
          expect(
            result.isSuccess,
            isTrue,
            reason: 'Operation failed: ${result.error}',
          );
          if (result is StoreOperationResult<Entity> && result.data != null) {
            createdIds.add(result.data!.id);
          }
        }
      } finally {
        // Cleanup
        final cleanupSession = await IntegrationHelper.createSession();
        final cleanupManager = cleanupSession.createStoreManager();
        for (final id in createdIds) {
          await cleanupManager.deleteEntity(id);
        }
        await cleanupSession.close();
        for (final s in sessions) {
          await s.close();
        }
      }
    });
  });
}
