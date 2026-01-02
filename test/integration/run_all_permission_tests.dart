import 'package:test/test.dart';

import 'health_check_test.dart' as health_check;
import 'read_auth_scenarios_test.dart' as read_auth;
import 'store_integration_test.dart' as store_integration;
import 'user_management_integration_test.dart' as user_management;

/// Consolidated test runner for all permission level integration tests
///
/// This runner orchestrates execution of all test suites in sequence:
/// 1. Health Checks - Verifies both services are available
/// 2. User Management Integration - Tests admin operations
/// 3. Store Integration - Tests store operations with auth modes
/// 4. ReadAuth Scenarios - Tests guest access with ReadAuth enabled/disabled
///
/// NOTE: These tests now use parametrized auth modes via testWithAuthMode.
/// Set TEST_AUTH_MODE environment variable to run specific auth mode:
///   TEST_AUTH_MODE=admin dart test test/integration/run_all_permission_tests.dart
///   TEST_AUTH_MODE=user-with-permission dart test ...
///   TEST_AUTH_MODE=user-no-permission dart test ...
///   TEST_AUTH_MODE=no-auth dart test ...
///
/// Or run the full test matrix with run_all_tests.sh
///
/// Requirements:
/// - Auth service running at configured URL (default: localhost:8010)
/// - Store service running at configured URL (default: localhost:8011)
/// - Compute service running at configured URL (default: localhost:8012)

void main() {
  group('Comprehensive Permission Test Suite', () {
    group('1. Health Checks', health_check.main);
    group('2. User Management Integration', user_management.main);
    group('3. Store Integration', store_integration.main);
    group('4. ReadAuth Scenarios - Guest Access Control', read_auth.main);
  });
}
