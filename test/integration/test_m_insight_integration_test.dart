import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('MInsight Integration Tests', () {
    test('test_get_m_insight_status', () async {
      final store = await IntegrationHelper.createStoreManager();
      
      final result = await store.getMInsightStatus();

      if (IntegrationTestConfig.isAuthEnabled) {
        // Should succeed for admin
        expect(result.isSuccess, isTrue, reason: 'Expected success for admin: ${result.error}');
        expect(result.data, isNotNull);
        expect(result.data, isA<Map<String, dynamic>>());
      } else {
        // Should fail for non-admin (guest mode or unauthenticated)
        expect(result.isError, isTrue, reason: 'Expected error for non-admin');
        expect(result.error, isNotNull);
      }

      await store.close();
    });
  });
}
