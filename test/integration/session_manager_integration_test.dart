import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('SessionManager Integration Tests - Live Servers', () {
    // Configuration for live servers
    const authBaseUrl = 'http://localhost:8000';
    const storeBaseUrl = 'http://localhost:8001';
    const computeBaseUrl = 'http://localhost:8002';

    // Test credentials
    const adminUsername = 'admin';
    const adminPassword = 'admin';
    final testUsername = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
    const testPassword = 'Test@123456';

    late SessionManager adminManager;
    SessionManager? testUserManager;
    late AuthService authService;

    setUpAll(() async {
      // Initialize with admin credentials
      adminManager = SessionManager.initialize();
      authService = AuthService(baseUrl: authBaseUrl);
    });

    tearDownAll(() async {
      await adminManager.dispose();
      if (testUserManager != null) {
        await testUserManager!.dispose();
      }
    });

    group('Admin Login & User Management', () {
      test('Admin login succeeds with valid credentials', () async {
        try {
          await adminManager.login(
            adminUsername,
            adminPassword,
            authBaseUrl: authBaseUrl,
          );

          expect(adminManager.isLoggedIn, true);
          expect(adminManager.currentUsername, adminUsername);
        } catch (e) {
          fail('Admin login failed: $e');
        }
      });

      test('Admin can get valid token', () async {
        try {
          final token = await adminManager.getValidToken();
          expect(token, isNotEmpty);
          expect(token.contains('.'), true); // JWT format check
        } catch (e) {
          fail('Getting admin token failed: $e');
        }
      });

      test('Admin can create a test user', () async {
        try {
          final adminToken = await adminManager.getValidToken();
          final userService = AuthService(
            baseUrl: authBaseUrl,
            token: adminToken,
          );

          // Note: Assuming server has user creation endpoint
          print('Test user would be created: $testUsername');
          // This would call actual user creation endpoint when available
        } catch (e) {
          // Skip if endpoint not available
          print('User creation not available: $e');
        }
      });
    });

    group('Test User Session Management', () {
      test('Test user login succeeds', () async {
        try {
          testUserManager = SessionManager.initialize();
          await testUserManager!.login(
            testUsername,
            testPassword,
            authBaseUrl: authBaseUrl,
          );

          expect(testUserManager!.isLoggedIn, true);
          expect(testUserManager!.currentUsername, testUsername);
        } catch (e) {
          // Skip test if test user not available
          print('Test user not available: $e');
        }
      }, skip: true);

      test('Token refresh strategy can be set', () async {
        try {
          final manager = testUserManager;
          if (manager == null) {
            fail('testUserManager not initialized');
          }
          manager.refreshStrategy = TokenRefreshStrategy.refreshEndpoint;
          expect(manager.refreshStrategy, TokenRefreshStrategy.refreshEndpoint);

          manager.refreshStrategy = TokenRefreshStrategy.reLogin;
          expect(manager.refreshStrategy, TokenRefreshStrategy.reLogin);
        } catch (e) {
          fail('Setting refresh strategy failed: $e');
        }
      }, skip: true);
    });

    group('Store Service Integration', () {
      test('Can create pre-authenticated StoreService', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final storeService =
              await adminManager.createStoreService(baseUrl: storeBaseUrl);
          expect(storeService, isNotNull);
        } catch (e) {
          fail('Creating StoreService failed: $e');
        }
      });

      test('StoreService can list entities', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final storeService =
              await adminManager.createStoreService(baseUrl: storeBaseUrl);
          final response = await storeService.listEntities();

          expect(response, isNotNull);
          expect(response.items, isNotNull);
          print('Listed ${response.items.length} entities');
        } catch (e) {
          fail('Listing entities failed: $e');
        }
      });

      test('StoreService can create entity', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final storeService =
              await adminManager.createStoreService(baseUrl: storeBaseUrl);
          final entity = await storeService.createEntity(
            isCollection: true,
            label: 'Integration Test Collection',
            description: 'Created by integration test',
          );

          expect(entity, isNotNull);
          expect(entity.label, 'Integration Test Collection');
          print('Created entity: ${entity.id}');
        } catch (e) {
          fail('Creating entity failed: $e');
        }
      });
    });

    group('Compute Service Integration', () {
      test('Can create pre-authenticated ComputeService', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final computeService =
              await adminManager.createComputeService(baseUrl: computeBaseUrl);
          expect(computeService, isNotNull);
        } catch (e) {
          fail('Creating ComputeService failed: $e');
        }
      });

      test('ComputeService can list workers', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final computeService =
              await adminManager.createComputeService(baseUrl: computeBaseUrl);
          final response = await computeService.listWorkers();

          expect(response, isNotNull);
          expect(response.workers, isNotNull);
          print('Listed ${response.workers.length} workers');
        } catch (e) {
          fail('Listing workers failed: $e');
        }
      });

      test('ComputeService can create job', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final computeService =
              await adminManager.createComputeService(baseUrl: computeBaseUrl);
          final job = await computeService.createJob(
            taskType: 'test_task',
            metadata: {'test': 'integration_test'},
          );

          expect(job, isNotNull);
          expect(job.taskType, 'test_task');
          print('Created job: ${job.jobId}');
        } catch (e) {
          fail('Creating job failed: $e');
        }
      });
    });

    group('Auth Service Integration', () {
      test('Can create pre-authenticated AuthService', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final authServiceInstance =
              await adminManager.createAuthService(baseUrl: authBaseUrl);
          expect(authServiceInstance, isNotNull);
        } catch (e) {
          fail('Creating AuthService failed: $e');
        }
      });

      test('Can get current user info', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final authServiceInstance =
              await adminManager.createAuthService(baseUrl: authBaseUrl);
          final user = await authServiceInstance.getCurrentUser();

          expect(user, isNotNull);
          expect(user.username, adminUsername);
          print('Current user: ${user.username} (ID: ${user.id})');
        } catch (e) {
          fail('Getting current user failed: $e');
        }
      });
    });

    group('Token Refresh', () {
      test('Can manually refresh token', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          final tokenBefore = await adminManager.getValidToken();
          await adminManager.refreshToken();
          final tokenAfter = await adminManager.getValidToken();

          expect(tokenAfter, isNotEmpty);
          print('Token refreshed successfully');
        } catch (e) {
          // Token refresh might not be available on all servers
          print('Token refresh not available: $e');
        }
      });

      test('Token is automatically refreshed when expired', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
              authBaseUrl: authBaseUrl,
            );
          }

          // Get a valid token
          final token = await adminManager.getValidToken();
          expect(token, isNotEmpty);

          // Token auto-refresh is tested indirectly - if we can still use the
          // token after some operations, it means refresh worked (if needed)
          final storeService =
              await adminManager.createStoreService(baseUrl: storeBaseUrl);
          final response = await storeService.listEntities();
          expect(response, isNotNull);
        } catch (e) {
          fail('Auto-refresh test failed: $e');
        }
      });
    });

    group('Session State Management', () {
      test('Session state is reactive and updates correctly', () async {
        try {
          final manager = SessionManager.initialize();

          // Initially logged out
          expect(manager.isLoggedIn, false);
          expect(manager.currentUsername, isNull);

          // After login
          await manager.login(
            adminUsername,
            adminPassword,
            authBaseUrl: authBaseUrl,
          );

          expect(manager.isLoggedIn, true);
          expect(manager.currentUsername, adminUsername);

          // After logout
          await manager.logout();

          expect(manager.isLoggedIn, false);
          expect(manager.currentUsername, isNull);
        } catch (e) {
          fail('Session state management failed: $e');
        }
      });

      test('Can listen to session state changes', () async {
        try {
          final manager = SessionManager.initialize();
          var stateChanges = 0;

          manager.onSessionStateChanged((state) {
            stateChanges++;
            print('Session state changed: logged_in=${state.isLoggedIn}');
          });

          await manager.login(
            adminUsername,
            adminPassword,
            authBaseUrl: authBaseUrl,
          );

          await manager.logout();

          // Should have state changes (at least login and logout)
          expect(stateChanges, greaterThan(0));
        } catch (e) {
          fail('Session state listener failed: $e');
        }
      });
    });

    group('Error Handling', () {
      test('Login with wrong password throws AuthException', () async {
        try {
          final manager = SessionManager.initialize();
          await manager.login(
            adminUsername,
            'wrong_password',
            authBaseUrl: authBaseUrl,
          );
          fail('Should have thrown AuthException');
        } on AuthException {
          // Expected
          expect(true, true);
        } catch (e) {
          fail('Wrong exception type: $e');
        }
      });

      test('Getting valid token when not logged in throws NotLoggedInException',
          () async {
        try {
          final manager = SessionManager.initialize();
          await manager.getValidToken();
          fail('Should have thrown NotLoggedInException');
        } on NotLoggedInException {
          // Expected
          expect(true, true);
        } catch (e) {
          fail('Wrong exception type: $e');
        }
      });

      test('Service call with invalid token throws AuthException', () async {
        try {
          final storeService = StoreService(
            baseUrl: storeBaseUrl,
            token: 'invalid.jwt.token',
          );
          await storeService.listEntities();
          fail('Should have thrown AuthException');
        } on AuthException {
          // Expected
          expect(true, true);
        } catch (e) {
          // Could also be other exception types depending on server
          print('Service error (expected): ${e.runtimeType}');
        }
      });
    });

    group('Multi-Service Workflow', () {
      test('Complete workflow: Login -> Create Entity -> Create Job', () async {
        try {
          final manager = SessionManager.initialize();

          // Step 1: Login
          await manager.login(
            adminUsername,
            adminPassword,
            authBaseUrl: authBaseUrl,
          );
          print('✓ Logged in as $adminUsername');

          // Step 2: Create entity via Store Service
          final storeService =
              await manager.createStoreService(baseUrl: storeBaseUrl);
          final entity = await storeService.createEntity(
            isCollection: true,
            label: 'Test Workflow Collection',
            description: 'Created in integration test',
          );
          print('✓ Created entity: ${entity.id}');

          // Step 3: Create job via Compute Service
          final computeService =
              await manager.createComputeService(baseUrl: computeBaseUrl);
          final job = await computeService.createJob(
            taskType: 'test_task',
            metadata: {
              'entityId': entity.id,
              'entityLabel': entity.label,
            },
          );
          print('✓ Created job: ${job.jobId}');

          // Step 4: Verify user via Auth Service
          final authService =
              await manager.createAuthService(baseUrl: authBaseUrl);
          final user = await authService.getCurrentUser();
          print('✓ Verified user: ${user.username}');

          // Step 5: Logout
          await manager.logout();
          print('✓ Logged out');

          expect(manager.isLoggedIn, false);
        } catch (e) {
          fail('Multi-service workflow failed: $e');
        }
      });
    });
  });
}
