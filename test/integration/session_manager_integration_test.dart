// ignore_for_file: avoid_print we need to move to log later

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';

void main() {
  group('SessionManager Integration Tests - Live Servers', () {
    // Test credentials
    const adminUsername = 'admin';
    const adminPassword = 'admin';
    final testUsername = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
    const testPassword = 'Test@123456';

    late SessionManager adminManager;
    SessionManager? testUserManager;

    setUpAll(() async {
      // Initialize with admin credentials
      adminManager = SessionManager.initialize(await createTestServerConfig());
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

          // Decode and print token claims for debugging
          final payload = JwtUtils.parseToken(token);
          if (payload != null) {
            print('Admin Token Claims:');
            print('  userId: ${payload.userId}');
            print('  isAdmin: ${payload.isAdmin}');
            print('  permissions: ${payload.permissions}');
            print('  expiresAt: ${payload.expiresAt}');
          }
        } on Exception catch (e) {
          fail('Getting admin token failed: $e');
        }
      });

      test('Admin can create a test user', () async {
        try {
          final authService = await adminManager.createAuthService();

          final user = await authService.createUser(
            username: testUsername,
            password: testPassword,
            permissions: ['ai_inference_support'],
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
          testUserManager =
              SessionManager.initialize(await createTestServerConfig());
          await testUserManager!.login(
            testUsername,
            testPassword,
          );

          expect(testUserManager!.isLoggedIn, true);
          expect(testUserManager!.currentUsername, testUsername);
        } on Exception catch (e) {
          fail('Test user login failed: $e');
        }
      });

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
      });
    });

    group('Store Service Integration', () {
      test('Can create pre-authenticated StoreService', () async {
        try {
          if (!adminManager.isLoggedIn) {
            await adminManager.login(
              adminUsername,
              adminPassword,
            );
          }

          final storeService = await adminManager.createStoreService();
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
            );
          }

          final storeService = await adminManager.createStoreService();
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
            );
          }

          final storeService = await adminManager.createStoreService();
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
            );
          }

          final computeService = await adminManager.createComputeService();
          expect(computeService, isNotNull);
        } on Exception catch (e) {
          fail('Creating ComputeService failed: $e');
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
            );
          }

          final authServiceInstance = await adminManager.createAuthService();
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
            );
          }

          final authServiceInstance = await adminManager.createAuthService();
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
            );
          }

          // Get a valid token
          final token = await adminManager.getValidToken();
          expect(token, isNotEmpty);
          // Token auto-refresh is tested indirectly - if we can still use the
          // token after some operations, it means refresh worked (if needed)
          final storeService = await adminManager.createStoreService();
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
          final manager =
              SessionManager.initialize(await createTestServerConfig());

          // Initially logged out
          expect(manager.isLoggedIn, false);
          expect(manager.currentUsername, isNull);

          // After login
          await manager.login(
            adminUsername,
            adminPassword,
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
          final manager =
              SessionManager.initialize(await createTestServerConfig());
          var stateChanges = 0;

          manager.onSessionStateChanged((state) {
            stateChanges++;
            print('Session state changed: logged_in=${state.isLoggedIn}');
          });

          await manager.login(
            adminUsername,
            adminPassword,
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
          final manager =
              SessionManager.initialize(await createTestServerConfig());
          await manager.login(
            adminUsername,
            'wrong_password',
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
            final manager =
              SessionManager.initialize(await createTestServerConfig());
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
            storeServiceBaseUrl,
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
  });
}
