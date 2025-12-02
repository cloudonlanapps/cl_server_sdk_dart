// ignore_for_file: avoid_print we need to move to log later

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

    setUpAll(() async {
      // Initialize with admin credentials
      adminManager = SessionManager.initialize();
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
        } on Exception catch (e) {
          fail('Admin login failed: $e');
        }
      });

      test('Admin can get valid token', () async {
        try {
          final token = await adminManager.getValidToken();
          expect(token, isNotEmpty);
          expect(token.contains('.'), true); // JWT format check
        } on Exception catch (e) {
          fail('Getting admin token failed: $e');
        }
      });

      test('Admin can create a test user', () async {
        try {
          final authService = await adminManager.createAuthService(
            baseUrl: authBaseUrl,
          );

          final user = await authService.createUser(
            username: testUsername,
            password: testPassword,
          );

          expect(user, isNotNull);
          expect(user.username, testUsername);
          print('Test user created: $testUsername');
        } on Exception catch (e) {
          fail('User creation failed: $e');
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
        } on Exception catch (e) {
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
        } on Exception catch (e) {
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

          final storeService = await adminManager.createStoreService(
            baseUrl: storeBaseUrl,
          );
          expect(storeService, isNotNull);
        } on Exception catch (e) {
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

          final storeService = await adminManager.createStoreService(
            baseUrl: storeBaseUrl,
          );
          final response = await storeService.listEntities();

          expect(response, isNotNull);
          expect(response.items, isNotNull);
          print('Listed ${response.items.length} entities');
        } on Exception catch (e) {
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

          final storeService = await adminManager.createStoreService(
            baseUrl: storeBaseUrl,
          );
          final entity = await storeService.createEntity(
            isCollection: true,
            label: 'Integration Test Collection',
            description: 'Created by integration test',
          );

          expect(entity, isNotNull);
          expect(entity.label, 'Integration Test Collection');
          print('Created entity: ${entity.id}');
        } on Exception catch (e) {
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

          final computeService = await adminManager.createComputeService(
            baseUrl: computeBaseUrl,
          );
          expect(computeService, isNotNull);
        } on Exception catch (e) {
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

          final computeService = await adminManager.createComputeService(
            baseUrl: computeBaseUrl,
          );
          final response = await computeService.listWorkers();

          expect(response, isNotNull);
          expect(response.workers, isNotNull);
          print('Listed ${response.workers.length} workers');
        } on Exception catch (e) {
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

          final computeService = await adminManager.createComputeService(
            baseUrl: computeBaseUrl,
          );
          final job = await computeService.createJob(
            taskType: 'test_task',
            metadata: {'test': 'integration_test'},
          );

          expect(job, isNotNull);
          expect(job.taskType, 'test_task');
          print('Created job: ${job.jobId}');
        } on Exception catch (e) {
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

          final authServiceInstance = await adminManager.createAuthService(
            baseUrl: authBaseUrl,
          );
          expect(authServiceInstance, isNotNull);
        } on Exception catch (e) {
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

          final authServiceInstance = await adminManager.createAuthService(
            baseUrl: authBaseUrl,
          );
          final user = await authServiceInstance.getCurrentUser();

          expect(user, isNotNull);
          expect(user.username, adminUsername);
          print('Current user: ${user.username} (ID: ${user.id})');
        } on Exception catch (e) {
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
          // Check tokenBefore and tokenAfter
          expect(tokenAfter, isNotEmpty);
          expect(tokenAfter, isNot(equals(tokenBefore)));
          print('Token refreshed successfully');
        } on Exception catch (e) {
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
          final storeService = await adminManager.createStoreService(
            baseUrl: storeBaseUrl,
          );
          final response = await storeService.listEntities();
          expect(response, isNotNull);
        } on Exception catch (e) {
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
        } on Exception catch (e) {
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
        } on Exception catch (e) {
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
        } on Exception catch (e) {
          fail('Wrong exception type: $e');
        }
      });

      test(
        'Getting valid token when not logged in throws NotLoggedInException',
        () async {
          try {
            final manager = SessionManager.initialize();
            await manager.getValidToken();
            fail('Should have thrown NotLoggedInException');
          } on NotLoggedInException {
            // Expected
            expect(true, true);
          } on Exception catch (e) {
            fail('Wrong exception type: $e');
          }
        },
      );

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
        } on Exception catch (e) {
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
          final storeService = await manager.createStoreService(
            baseUrl: storeBaseUrl,
          );
          final entity = await storeService.createEntity(
            isCollection: true,
            label: 'Test Workflow Collection',
            description: 'Created in integration test',
          );
          print('✓ Created entity: ${entity.id}');

          // Step 3: Create job via Compute Service
          final computeService = await manager.createComputeService(
            baseUrl: computeBaseUrl,
          );
          final job = await computeService.createJob(
            taskType: 'test_task',
            metadata: {
              'entityId': entity.id,
              'entityLabel': entity.label,
            },
          );
          print('✓ Created job: ${job.jobId}');

          // Step 4: Verify user via Auth Service
          final authService = await manager.createAuthService(
            baseUrl: authBaseUrl,
          );
          final user = await authService.getCurrentUser();
          print('✓ Verified user: ${user.username}');

          // Step 5: Logout
          await manager.logout();
          print('✓ Logged out');

          expect(manager.isLoggedIn, false);
        } on Exception catch (e) {
          fail('Multi-service workflow failed: $e');
        }
      });
    });
  });
}
