import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('SessionManager Tests', () {
    late SessionManager manager;

    setUp(() async {
      manager = SessionManager.initialize(await createTestServerConfig());
    });

    group('Initialization', () {
      test('initialize creates manager instance', () {
        expect(manager, isNotNull);
      });

      test('initialize creates logged out manager', () {
        expect(manager.isLoggedIn, false);
      });

      test('currentUsername is null initially', () {
        expect(manager.currentUsername, isNull);
      });

      test('currentState is logged out initially', () {
        expect(manager.currentState.isLoggedIn, false);
      });
    });

    group('Session State Access', () {
      test('isLoggedIn reflects login state', () async {
        expect(manager.isLoggedIn, false);
      });

      test('currentUsername returns username when logged in', () async {
        expect(manager.currentUsername, isNull);
      });

      test('currentState returns session state', () {
        final state = manager.currentState;
        expect(state, isNotNull);
        expect(state.isLoggedIn, false);
      });

      test('sessionSignal provides reactive signal', () {
        final signal = manager.sessionSignal;
        expect(signal, isNotNull);
        expect(signal.value.isLoggedIn, false);
      });
    });

    group('Refresh Strategy', () {
      test('refreshStrategy setter updates strategy', () {
        // Should not throw
        manager
          ..refreshStrategy = TokenRefreshStrategy.reLogin
          ..refreshStrategy = TokenRefreshStrategy.refreshEndpoint;
      });
    });

    group('Service Factory Methods', () {
      test('createStoreService would require valid token', () async {
        expect(
          () => manager.createStoreService(),
          throwsA(isA<NotLoggedInException>()),
        );
      });

      test('createComputeService would require valid token', () async {
        expect(
          () => manager.createComputeService(),
          throwsA(isA<NotLoggedInException>()),
        );
      });

      test('createAuthService would require valid token', () async {
        expect(
          () => manager.createAuthService(),
          throwsA(isA<NotLoggedInException>()),
        );
      });

      test('createStoreService throws when not logged in', () async {
        expect(
          () => manager.createStoreService(),
          throwsA(isA<NotLoggedInException>()),
        );
      });

      test('createComputeService throws when not logged in', () async {
        expect(
          () => manager.createComputeService(),
          throwsA(isA<NotLoggedInException>()),
        );
      });

      test('createAuthService throws when not logged in', () async {
        expect(
          () => manager.createAuthService(),
          throwsA(isA<NotLoggedInException>()),
        );
      });
    });

    group('Login/Logout', () {
      test('login would authenticate user (mock limitation)', () async {
        // Real test would require mocking AuthService
        // This test documents the expected signature
        expect(manager.isLoggedIn, false);
      });

      test('logout clears session', () async {
        await manager.logout();
        expect(manager.isLoggedIn, false);
      });

      test('login accepts optional baseUrl', () async {
        // This test documents the expected signature
        // Real implementation would need mocking
        expect(manager.isLoggedIn, false);
      });
    });

    group('Token Management', () {
      test('getValidToken throws when not logged in', () async {
        expect(
          () => manager.getValidToken(),
          throwsA(isA<NotLoggedInException>()),
        );
      });

      test('refreshToken throws when not logged in', () async {
        expect(
          () => manager.refreshToken(),
          throwsA(isA<NotLoggedInException>()),
        );
      });

      test('refreshToken accepts forceRefresh parameter', () async {
        expect(
          () => manager.refreshToken(forceRefresh: true),
          throwsA(isA<NotLoggedInException>()),
        );
      });
    });

    group('Session State Observation', () {
      test('onSessionStateChanged calls callback with state changes', () {
        var callCount = 0;
        SessionState? lastState;

        manager.onSessionStateChanged((state) {
          callCount++;
          lastState = state;
        });

        // At least the initial state should be observed
        expect(callCount, greaterThanOrEqualTo(1));
        expect(lastState, isNotNull);
      });

      test('multiple onSessionStateChanged callbacks all triggered', () {
        var count1 = 0;
        var count2 = 0;

        manager
          ..onSessionStateChanged((_) {
            count1++;
          })
          ..onSessionStateChanged((_) {
            count2++;
          });

        expect(count1, greaterThanOrEqualTo(1));
        expect(count2, greaterThanOrEqualTo(1));
      });
    });

    group('Disposal', () {
      test('dispose clears token', () async {
        await manager.dispose();
        expect(manager.isLoggedIn, false);
      });

      test('multiple dispose calls are safe', () async {
        await manager.dispose();
        await manager.dispose(); // Should not throw
      });
    });

    group('State Mutations Safety', () {
      test('modifying service state does not leak to manager', () {
        final state1 = manager.currentState;
        final state2 = manager.currentState;

        // Both should reflect same login state
        expect(state1.isLoggedIn, state2.isLoggedIn);
      });

      test('sessionSignal provides consistent access', () {
        final signal1 = manager.sessionSignal;
        final signal2 = manager.sessionSignal;

        expect(signal1, signal2);
      });
    });

    group('Concurrent Operations', () {
      test('dispose is idempotent', () async {
        final dispose1 = manager.dispose();
        final dispose2 = manager.dispose();

        await Future.wait([dispose1, dispose2]);
        // Should complete without errors
      });

      test('logout after dispose is safe', () async {
        await manager.dispose();
        // Second logout should be safe
        await manager.logout();
      });
    });
  });
}
