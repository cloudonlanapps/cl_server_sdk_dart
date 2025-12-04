import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';

/// Health check utilities for integration tests
///
/// Provides conditional service availability verification
/// based on which module is being tested.

/// Check if Auth service is available
Future<bool> checkAuthServiceHealth() async {
  try {
    final authService = AuthService(authServiceBaseUrl);
    await authService.getPublicKey();
    return true;
  } on Exception catch (_) {
    return false;
  }
}

/// Check if Store service is available
Future<bool> checkStoreServiceHealth() async {
  try {
    final storeService = StoreService(storeServiceBaseUrl);
    await storeService.listEntities(pageSize: 1);
    return true;
  } on Exception catch (_) {
    return false;
  }
}

/// Verify health check - throws exception if services unavailable
// ignore: unreachable_from_main Tests should be added
Future<void> ensureAuthServiceHealthy() async {
  if (!await checkAuthServiceHealth()) {
    throw Exception('Auth service not available at $authServiceBaseUrl');
  }
}

/// Verify health check - throws exception if services unavailable
// ignore: unreachable_from_main Tests should be added
Future<void> ensureStoreServiceHealthy() async {
  if (!await checkStoreServiceHealth()) {
    throw Exception('Store service not available at $storeServiceBaseUrl');
  }
}

/// Verify both services are healthy
Future<void> ensureBothServicesHealthy() async {
  final authHealthy = await checkAuthServiceHealth();
  final storeHealthy = await checkStoreServiceHealth();

  if (!authHealthy && !storeHealthy) {
    throw Exception(
      'Both services unavailable: '
      'Auth($authServiceBaseUrl), Store($storeServiceBaseUrl)',
    );
  }
  if (!authHealthy) {
    throw Exception('Auth service not available at $authServiceBaseUrl');
  }
  if (!storeHealthy) {
    throw Exception('Store service not available at $storeServiceBaseUrl');
  }
}

void main() {
  group('Health Checks', () {
    test('Auth service is available', () async {
      final isHealthy = await checkAuthServiceHealth();
      expect(
        isHealthy,
        isTrue,
        reason: 'Auth service should be available at $authServiceBaseUrl',
      );
    });

    test('Store service is available', () async {
      final isHealthy = await checkStoreServiceHealth();
      expect(
        isHealthy,
        isTrue,
        reason: 'Store service should be available at $storeServiceBaseUrl',
      );
    });

    test('Both services are available', () async {
      await expectLater(ensureBothServicesHealthy(), completes);
    });
  });
}
