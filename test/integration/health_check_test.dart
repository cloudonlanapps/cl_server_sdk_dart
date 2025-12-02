import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../server_addr.dart' show authServiceUrl, storeServiceUrl;

/// Health check utilities for integration tests
///
/// Provides conditional service availability verification
/// based on which module is being tested.

/// Check if Auth service is available
Future<bool> checkAuthServiceHealth() async {
  try {
    final authService = AuthService(baseUrl: authServiceUrl);
    await authService.getPublicKey();
    return true;
  } on Exception catch (_) {
    return false;
  }
}

/// Check if Store service is available
Future<bool> checkStoreServiceHealth() async {
  try {
    final storeService = StoreService(baseUrl: storeServiceUrl);
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
    throw Exception('Auth service not available at $authServiceUrl');
  }
}

/// Verify health check - throws exception if services unavailable
// ignore: unreachable_from_main Tests should be added
Future<void> ensureStoreServiceHealthy() async {
  if (!await checkStoreServiceHealth()) {
    throw Exception('Store service not available at $storeServiceUrl');
  }
}

/// Verify both services are healthy
Future<void> ensureBothServicesHealthy() async {
  final authHealthy = await checkAuthServiceHealth();
  final storeHealthy = await checkStoreServiceHealth();

  if (!authHealthy && !storeHealthy) {
    throw Exception(
      'Both services unavailable: '
      'Auth($authServiceUrl), Store($storeServiceUrl)',
    );
  }
  if (!authHealthy) {
    throw Exception('Auth service not available at $authServiceUrl');
  }
  if (!storeHealthy) {
    throw Exception('Store service not available at $storeServiceUrl');
  }
}

void main() {
  group('Health Checks', () {
    test('Auth service is available', () async {
      final isHealthy = await checkAuthServiceHealth();
      expect(
        isHealthy,
        isTrue,
        reason: 'Auth service should be available at $authServiceUrl',
      );
    });

    test('Store service is available', () async {
      final isHealthy = await checkStoreServiceHealth();
      expect(
        isHealthy,
        isTrue,
        reason: 'Store service should be available at $storeServiceUrl',
      );
    });

    test('Both services are available', () async {
      await expectLater(ensureBothServicesHealthy(), completes);
    });
  });
}
