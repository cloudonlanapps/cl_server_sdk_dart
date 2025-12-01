import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('TokenStorage Tests', () {
    late TokenStorage storage;

    setUp(() {
      storage = TokenStorage();
    });

    group('Token Storage', () {
      test('hasToken returns false initially', () async {
        final has = await storage.hasToken();
        expect(has, false);
      });

      test('saveToken stores token and username', () async {
        await storage.saveToken('testuser', 'test_token_123');

        final token = await storage.getToken();
        final username = await storage.getUsername();

        expect(token, 'test_token_123');
        expect(username, 'testuser');
      });

      test('hasToken returns true after saveToken', () async {
        await storage.saveToken('testuser', 'test_token_123');
        final has = await storage.hasToken();
        expect(has, true);
      });

      test('updateToken replaces existing token', () async {
        await storage.saveToken('testuser', 'old_token');
        await storage.updateToken('new_token');

        final token = await storage.getToken();
        expect(token, 'new_token');
      });

      test('getToken returns null when no token stored', () async {
        final token = await storage.getToken();
        expect(token, isNull);
      });

      test('getUsername returns null when no username stored', () async {
        final username = await storage.getUsername();
        expect(username, isNull);
      });

      test('clearToken removes all session data', () async {
        await storage.saveToken('testuser', 'test_token');
        await storage.clearToken();

        final token = await storage.getToken();
        final username = await storage.getUsername();
        final has = await storage.hasToken();

        expect(token, isNull);
        expect(username, isNull);
        expect(has, false);
      });
    });

    group('Refresh Time Storage', () {
      test('getLastRefreshTime returns null initially', () async {
        final time = await storage.getLastRefreshTime();
        expect(time, isNull);
      });

      test('updateRefreshTime stores current time', () async {
        final before = DateTime.now();
        await storage.updateRefreshTime();
        final after = DateTime.now();

        final stored = await storage.getLastRefreshTime();

        expect(stored, isNotNull);
        expect(stored!.isAfter(before.subtract(const Duration(seconds: 1))),
            true);
        expect(stored.isBefore(after.add(const Duration(seconds: 1))), true);
      });

      test('updateRefreshTime overwrites previous time', () async {
        await storage.updateRefreshTime();
        final first = await storage.getLastRefreshTime();

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await storage.updateRefreshTime();
        final second = await storage.getLastRefreshTime();

        expect(second!.isAfter(first!), true);
      });

      test('clearToken removes refresh time', () async {
        await storage.saveToken('user', 'token');
        await storage.updateRefreshTime();
        await storage.clearToken();

        final time = await storage.getLastRefreshTime();
        expect(time, isNull);
      });
    });

    group('Password Encryption', () {
      test('saveEncryptedPassword encrypts and stores password', () async {
        await storage.saveEncryptedPassword('testuser', 'secret123');

        final decrypted = await storage.getDecryptedPassword();
        expect(decrypted, 'secret123');
      });

      test('getDecryptedPassword returns null when no password stored', () async {
        final password = await storage.getDecryptedPassword();
        expect(password, isNull);
      });

      test('saveEncryptedPassword overwrites previous password', () async {
        await storage.saveEncryptedPassword('user', 'oldpass');
        await storage.saveEncryptedPassword('user', 'newpass');

        final decrypted = await storage.getDecryptedPassword();
        expect(decrypted, 'newpass');
      });

      test('clearPassword removes encrypted password', () async {
        await storage.saveEncryptedPassword('user', 'secret123');
        await storage.clearPassword();

        final decrypted = await storage.getDecryptedPassword();
        expect(decrypted, isNull);
      });

      test('clearToken removes encrypted password', () async {
        await storage.saveEncryptedPassword('user', 'secret123');
        await storage.clearToken();

        final decrypted = await storage.getDecryptedPassword();
        expect(decrypted, isNull);
      });

      test('password encryption handles special characters', () async {
        const specialPass =
            'p@ss!w0rd#123\$%^&*()_+-=[]{}|;:\'",.<>?/\\`~';
        await storage.saveEncryptedPassword('user', specialPass);

        final decrypted = await storage.getDecryptedPassword();
        expect(decrypted, specialPass);
      });

      test('password encryption handles empty string', () async {
        await storage.saveEncryptedPassword('user', '');

        final decrypted = await storage.getDecryptedPassword();
        expect(decrypted, '');
      });

      test('password encryption handles long strings', () async {
        final longPass = 'a' * 1000;
        await storage.saveEncryptedPassword('user', longPass);

        final decrypted = await storage.getDecryptedPassword();
        expect(decrypted, longPass);
      });
    });

    group('Session State Isolation', () {
      test('storing one user replaces previous user', () async {
        await storage.saveToken('user1', 'token1');
        await storage.saveToken('user2', 'token2');

        final username = await storage.getUsername();
        final token = await storage.getToken();

        expect(username, 'user2');
        expect(token, 'token2');
      });

      test('different storage instances share same in-memory cache', () async {
        final storage1 = TokenStorage();
        final storage2 = TokenStorage();

        // Note: Since TokenStorage uses separate instances,
        // they should NOT share data. This test documents that behavior.
        await storage1.saveToken('user1', 'token1');

        final token2 = await storage2.getToken();
        // They have separate in-memory caches
        expect(token2, isNull);
      });
    });

    group('Error Handling', () {
      test('handles corruption gracefully with clearPassword on empty cache',
          () async {
        // Should not throw
        await storage.clearPassword();
      });

      test('handles multiple clearToken calls', () async {
        await storage.saveToken('user', 'token');
        await storage.clearToken();
        // Second call should not throw
        await storage.clearToken();
      });
    });
  });
}
