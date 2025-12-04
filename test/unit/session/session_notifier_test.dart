import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('SessionNotifier Tests', () {
    late AuthService authService;
    late TokenStorage tokenStorage;

    setUp(() {
      authService = AuthService(authServiceBaseUrl);
      tokenStorage = TokenStorage();
    });

    group('Initialization', () {
      test('creates notifier with logged out state', () {
        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );

        expect(notifier.isLoggedIn, false);
        expect(notifier.currentUsername, isNull);
      });

      test('initializes with default refresh strategy', () {
        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );

        expect(notifier, isNotNull);
      });

      test('initialize handles missing token gracefully', () async {
        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );

        // Should not throw
        await notifier.initialize();
        expect(notifier.isLoggedIn, false);
      });
    });

    group('Logout', () {
      test('logout clears session data', () async {
        // First set some data
        await tokenStorage.saveToken('user', 'token');

        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );
        await notifier.initialize();
        expect(notifier.isLoggedIn, true);

        // Then logout
        await notifier.logout();

        expect(notifier.isLoggedIn, false);
        expect(notifier.currentUsername, isNull);
      });

      test('logout on already logged out user is safe', () async {
        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );

        // Should not throw
        await notifier.logout();
        expect(notifier.isLoggedIn, false);
      });
    });

    group('Token Refresh', () {
      test('refreshToken throws when not logged in', () async {
        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );

        expect(
          notifier.refreshToken,
          throwsA(isA<NotLoggedInException>()),
        );
      });
    });

    group('Get Valid Token', () {
      test('getValidToken throws when not logged in', () async {
        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );

        expect(
          notifier.getValidToken,
          throwsA(isA<NotLoggedInException>()),
        );
      });
    });

    group('Session State', () {
      test('currentState reflects current session', () {
        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );

        expect(notifier.currentState.isLoggedIn, false);
      });

      test('sessionSignal reflects state', () {
        final notifier = SessionNotifier(
          authService: authService,
          storage: tokenStorage,
        );

        expect(notifier.sessionSignal.value.isLoggedIn, false);
      });
    });

    group('Refresh Strategy', () {
      test('refreshStrategy setter changes strategy', () {
        SessionNotifier(
            authService: authService,
            storage: tokenStorage,
          )
          // Should not throw
          ..refreshStrategy = TokenRefreshStrategy.reLogin
          ..refreshStrategy = TokenRefreshStrategy.refreshEndpoint;
      });
    });
  });
}
