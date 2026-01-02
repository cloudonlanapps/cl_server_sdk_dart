import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'auth_test_context.dart';
import 'server_capabilities.dart';
import 'test_config_loader.dart';

// Legacy constants for backward compatibility with existing tests
// TODO: Remove after all tests are migrated to use getTestConfig()
const String authServiceBaseUrl = 'http://localhost:8010';
const String storeServiceBaseUrl = 'http://localhost:8011';
const String computeServiceBaseUrl = 'http://localhost:8012';

// Cached configuration for efficiency
TestConfig? _cachedConfig;
ServerCapabilities? _cachedCapabilities;

/// Get cached test configuration (loads once per test run)
Future<TestConfig> getTestConfig() async {
  _cachedConfig ??= await TestConfig.load();
  return _cachedConfig!;
}

/// Get cached server capabilities (detects once per test run)
Future<ServerCapabilities> getServerCapabilities() async {
  if (_cachedCapabilities == null) {
    final config = await getTestConfig();
    _cachedCapabilities = await ServerCapabilities.detect(config);
  }
  return _cachedCapabilities!;
}

/// Get auth context for current test mode
Future<AuthTestContext> getAuthContext([AuthMode? mode]) async {
  final config = await getTestConfig();
  final capabilities = await getServerCapabilities();

  final authMode = mode ?? await AuthTestContext.getCurrentMode(config);

  return AuthTestContext.forMode(
    mode: authMode,
    capabilities: capabilities,
    config: config,
  );
}

/// Reusable mock HTTP client for unit testing
class MockHttpClient extends http.BaseClient {
  MockHttpClient(this.responses);

  final Map<String, http.Response> responses;
  late http.BaseRequest lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final key = '${request.method} ${request.url}';
    final response = responses[key];

    if (response != null) {
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }

    return http.StreamedResponse(
      Stream.value([]),
      404,
      request: request,
    );
  }
}

/// Create ServerConfig from test configuration
Future<ServerConfig> createTestServerConfig([TestConfig? config]) async {
  final cfg = config ?? await getTestConfig();

  return ServerConfig(
    authServiceBaseUrl: cfg.authUrl,
    storeServiceBaseUrl: cfg.storeUrl,
    computeServiceBaseUrl: cfg.computeUrl,
  );
}

/// Create authenticated session for test user
Future<SessionManager> createTestSession(AuthTestContext context) async {
  if (context.mode == AuthMode.noAuth) {
    throw ArgumentError('Cannot create session for no-auth mode');
  }

  final config = await createTestServerConfig();
  final session = SessionManager.initialize(config);

  await session.login(context.username!, context.password!);

  return session;
}

/// Create compute client for test context (auth-aware)
Future<ComputeService> createTestComputeClient(
  AuthTestContext context,
) async {
  final config = await createTestServerConfig();

  if (context.mode == AuthMode.noAuth) {
    // No authentication
    return ComputeService(config.getComputeServiceBaseUrl());
  }

  // Authenticated - create via session
  final session = await createTestSession(context);
  return session.createComputeService();
}

/// Create store manager for test context (auth-aware)
Future<StoreManager> createTestStoreManager(AuthTestContext context) async {
  final config = await createTestServerConfig();

  if (context.mode == AuthMode.noAuth) {
    // Guest mode
    return StoreManager.guest(config.storeServiceBaseUrl);
  }

  // Authenticated - create via session
  final session = await createTestSession(context);
  return StoreManager.authenticated(sessionManager: session);
}

/// Create user manager for test context (auth-aware)
///
/// Note: User management always requires authentication
Future<UserManager> createTestUserManager(AuthTestContext context) async {
  if (context.mode == AuthMode.noAuth) {
    throw ArgumentError('User management requires authentication');
  }

  final session = await createTestSession(context);
  return UserManager.authenticated(sessionManager: session);
}

/// Run a test function with the current auth mode from environment
///
/// This matches pytest's approach where the shell script handles
/// server configuration and auth mode iteration. Each test run uses
/// ONE auth mode (from TEST_AUTH_MODE environment variable).
///
/// The test runner script (run_all_tests.sh) handles the 4x4 matrix:
/// - 4 server configurations (auth_required x guestMode combinations)
/// - 4 auth modes (admin, user-with-permission, user-no-permission, no-auth)
/// - Total: 16 test runs
void testWithAuthMode(
  String description,
  Future<void> Function(AuthTestContext) testFn,
) {
  test(description, () async {
    final context = await getAuthContext();
    await testFn(context);
  });
}
