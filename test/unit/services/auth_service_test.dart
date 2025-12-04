import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../test_helpers.dart';

void main() {
  group('AuthService Tests', () {
    test('generateToken returns TokenResponse on success', () async {
      final mockClient = MockHttpClient({
        'POST $authServiceBaseUrl/auth/token': http.Response(
          '{"access_token": "test-token", "token_type": "bearer"}',
          200,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        httpClient: mockClient,
      );
      final token = await authService.generateToken(
        username: 'admin',
        password: 'admin',
      );

      expect(token.accessToken, 'test-token');
      expect(token.tokenType, 'bearer');
    });

    test('generateToken throws AuthException on 401', () async {
      final mockClient = MockHttpClient({
        'POST $authServiceBaseUrl/auth/token': http.Response(
          '{"detail": "Invalid credentials"}',
          401,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        httpClient: mockClient,
      );

      expect(
        () => authService.generateToken(username: 'user', password: 'wrong'),
        throwsA(isA<AuthException>()),
      );
    });

    test('getPublicKey returns PublicKeyResponse on success', () async {
      final mockClient = MockHttpClient({
        'GET $authServiceBaseUrl/auth/public-key': http.Response(
          '''{"public_key": "-----BEGIN PUBLIC KEY-----", "algorithm": "ES256"}''',
          200,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        httpClient: mockClient,
      );
      final publicKey = await authService.getPublicKey();

      expect(publicKey.publicKey, '-----BEGIN PUBLIC KEY-----');
      expect(publicKey.algorithm, 'ES256');
    });

    test('getCurrentUser returns User on success with token', () async {
      final mockClient = MockHttpClient({
        'GET $authServiceBaseUrl/users/me': http.Response(
          '''{"id": 1, "username": "admin", "is_admin": true, "is_active": true, "created_at": "2024-01-15T10:30:00", "permissions": ["*"]}''',
          200,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final user = await authService.getCurrentUser();

      expect(user.id, 1);
      expect(user.username, 'admin');
      expect(user.isAdmin, true);
    });

    test('getCurrentUser throws AuthException on 401', () async {
      final mockClient = MockHttpClient({
        'GET $authServiceBaseUrl/users/me': http.Response(
          '{"detail": "Not authenticated"}',
          401,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        httpClient: mockClient,
      );

      expect(
        authService.getCurrentUser,
        throwsA(isA<AuthException>()),
      );
    });

    test('listUsers returns list of users', () async {
      final mockClient = MockHttpClient({
        'GET $authServiceBaseUrl/users/?skip=0&limit=100': http.Response(
          '''[{"id": 1, "username": "admin", "is_admin": true, "is_active": true, "created_at": "2024-01-15T10:30:00", "permissions": ["*"]}, {"id": 2, "username": "user", "is_admin": false, "is_active": true, "created_at": "2024-01-15T10:35:00", "permissions": ["read:data"]}]''',
          200,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final users = await authService.listUsers();

      expect(users, hasLength(2));
      expect(users[0].username, 'admin');
      expect(users[1].username, 'user');
    });

    test('getUser returns single user by ID', () async {
      final mockClient = MockHttpClient({
        'GET $authServiceBaseUrl/users/1': http.Response(
          '''{"id": 1, "username": "admin", "is_admin": true, "is_active": true, "created_at": "2024-01-15T10:30:00", "permissions": ["*"]}''',
          200,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final user = await authService.getUser(1);

      expect(user.id, 1);
      expect(user.username, 'admin');
    });

    test('getUser throws ResourceNotFoundException on 404', () async {
      final mockClient = MockHttpClient({
        'GET $authServiceBaseUrl/users/999': http.Response(
          '{"detail": "User not found"}',
          404,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );

      expect(
        () => authService.getUser(999),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('createUser returns created user', () async {
      final mockClient = MockHttpClient({
        'POST $authServiceBaseUrl/users/': http.Response(
          '''{"id": 2, "username": "newuser", "is_admin": false, "is_active": true, "created_at": "2024-01-15T10:35:00", "permissions": ["read:data"]}''',
          201,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final user = await authService.createUser(
        username: 'newuser',
        password: 'secure123',
      );

      expect(user.id, 2);
      expect(user.username, 'newuser');
      expect(user.isAdmin, false);
    });

    test('updateUser returns updated user', () async {
      final mockClient = MockHttpClient({
        'PUT $authServiceBaseUrl/users/2': http.Response(
          '''{"id": 2, "username": "newuser", "is_admin": true, "is_active": true, "created_at": "2024-01-15T10:35:00", "permissions": ["admin"]}''',
          200,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );
      final user = await authService.updateUser(
        2,
        isAdmin: true,
      );

      expect(user.isAdmin, true);
    });

    test('deleteUser completes successfully', () async {
      final mockClient = MockHttpClient({
        'DELETE $authServiceBaseUrl/users/2': http.Response('', 204),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        token: 'test-token',
        httpClient: mockClient,
      );

      expect(() => authService.deleteUser(2), returnsNormally);
    });

    test('healthCheck returns response', () async {
      final mockClient = MockHttpClient({
        'GET $authServiceBaseUrl/': http.Response(
          '{"message": "authentication service is running"}',
          200,
        ),
      });

      final authService = AuthService(
        authServiceBaseUrl,
        httpClient: mockClient,
      );
      final response = await authService.healthCheck();

      expect(response['message'], 'authentication service is running');
    });
  });
}
