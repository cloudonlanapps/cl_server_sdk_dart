import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('SessionState Tests', () {
    group('Creation', () {
      test('creates logged out state by default', () {
        const state = SessionState(isLoggedIn: false);

        expect(state.isLoggedIn, false);
        expect(state.username, isNull);
        expect(state.token, isNull);
        expect(state.error, isNull);
        expect(state.lastRefreshTime, isNull);
      });

      test('creates logged in state with all fields', () {
        const state = SessionState(
          isLoggedIn: true,
          username: 'testuser',
          token: 'test_token_123',
          error: null,
          lastRefreshTime: null,
        );

        expect(state.isLoggedIn, true);
        expect(state.username, 'testuser');
        expect(state.token, 'test_token_123');
        expect(state.error, isNull);
      });

      test('creates state with error message', () {
        const state = SessionState(
          isLoggedIn: false,
          error: 'Login failed: Invalid credentials',
        );

        expect(state.isLoggedIn, false);
        expect(state.error, 'Login failed: Invalid credentials');
      });
    });

    group('copyWith', () {
      test('copies all fields when called without arguments', () {
        final now = DateTime.now();
        final original = SessionState(
          isLoggedIn: true,
          username: 'user1',
          token: 'token1',
          error: 'error1',
          lastRefreshTime: now,
        );

        final copy = original.copyWith();

        expect(copy.isLoggedIn, original.isLoggedIn);
        expect(copy.username, original.username);
        expect(copy.token, original.token);
        expect(copy.error, original.error);
        expect(copy.lastRefreshTime, original.lastRefreshTime);
      });

      test('updates isLoggedIn in copyWith', () {
        const original = SessionState(isLoggedIn: true, username: 'user1');
        final updated = original.copyWith(isLoggedIn: false);

        expect(updated.isLoggedIn, false);
        expect(updated.username, 'user1');
      });

      test('updates username in copyWith', () {
        const original =
            SessionState(isLoggedIn: true, username: 'olduser');
        final updated = original.copyWith(username: 'newuser');

        expect(updated.username, 'newuser');
        expect(updated.isLoggedIn, true);
      });

      test('updates token in copyWith', () {
        const original =
            SessionState(isLoggedIn: true, token: 'old_token');
        final updated = original.copyWith(token: 'new_token');

        expect(updated.token, 'new_token');
        expect(updated.isLoggedIn, true);
      });

      test('updates error in copyWith', () {
        const original =
            SessionState(isLoggedIn: false, error: 'old error');
        final updated = original.copyWith(error: 'new error');

        expect(updated.error, 'new error');
      });

      test('preserves error when not specified in copyWith', () {
        const original =
            SessionState(isLoggedIn: false, error: 'some error');
        final updated = original.copyWith(isLoggedIn: true);

        // copyWith preserves error since it uses ?? operator
        expect(updated.error, 'some error');
      });

      test('updates lastRefreshTime in copyWith', () {
        final now = DateTime.now();
        final later = now.add(const Duration(hours: 1));

        final original =
            SessionState(isLoggedIn: true, lastRefreshTime: now);
        final updated = original.copyWith(lastRefreshTime: later);

        expect(updated.lastRefreshTime, later);
      });

      test('updates multiple fields in copyWith', () {
        final now = DateTime.now();
        const original = SessionState(
          isLoggedIn: true,
          username: 'user1',
          token: 'token1',
          error: null,
        );

        final updated = original.copyWith(
          isLoggedIn: false,
          username: 'user2',
          token: 'token2',
          error: 'logged out',
          lastRefreshTime: now,
        );

        expect(updated.isLoggedIn, false);
        expect(updated.username, 'user2');
        expect(updated.token, 'token2');
        expect(updated.error, 'logged out');
        expect(updated.lastRefreshTime, now);
      });
    });

    group('Immutability', () {
      test('original state not modified by copyWith', () {
        const original = SessionState(
          isLoggedIn: true,
          username: 'user1',
          token: 'token1',
        );

        original.copyWith(username: 'user2', token: 'token2');

        expect(original.username, 'user1');
        expect(original.token, 'token1');
      });

      test('multiple copyWith calls produce different instances', () {
        const state1 = SessionState(isLoggedIn: true, username: 'user1');
        final state2 = state1.copyWith(username: 'user2');
        final state3 = state1.copyWith(username: 'user3');

        expect(identical(state1, state2), false);
        expect(identical(state2, state3), false);
        expect(identical(state1, state3), false);
      });
    });

    group('Equality', () {
      test('same values produce equal states', () {
        final now = DateTime.now();
        final state1 = SessionState(
          isLoggedIn: true,
          username: 'user1',
          token: 'token1',
          error: null,
          lastRefreshTime: now,
        );

        final state2 = SessionState(
          isLoggedIn: true,
          username: 'user1',
          token: 'token1',
          error: null,
          lastRefreshTime: now,
        );

        expect(state1 == state2, true);
      });

      test('different values produce unequal states', () {
        const state1 = SessionState(isLoggedIn: true, username: 'user1');
        const state2 = SessionState(isLoggedIn: true, username: 'user2');

        expect(state1 == state2, false);
      });

      test('hash code same for equal states', () {
        const state1 = SessionState(isLoggedIn: true, username: 'user1');
        const state2 = SessionState(isLoggedIn: true, username: 'user1');

        expect(state1.hashCode == state2.hashCode, true);
      });
    });

    group('TokenRefreshStrategy enum', () {
      test('has refreshEndpoint value', () {
        expect(TokenRefreshStrategy.refreshEndpoint, isNotNull);
      });

      test('has reLogin value', () {
        expect(TokenRefreshStrategy.reLogin, isNotNull);
      });

      test('enum values are distinct', () {
        expect(
          TokenRefreshStrategy.refreshEndpoint != TokenRefreshStrategy.reLogin,
          true,
        );
      });
    });
  });
}
