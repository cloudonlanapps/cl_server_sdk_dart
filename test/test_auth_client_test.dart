import 'dart:convert';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('AuthClient', () {
    late MockHttpClient mockHttpClient;
    late AuthClient authClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      authClient = AuthClient(
        client: mockHttpClient,
        baseUrl: 'http://localhost:8010',
      );
    });

    tearDown(() {
      authClient.close();
    });

    group('TestAuthClientInit', () {
      test('test_auth_client_default_config', () {
        final client = AuthClient();
        expect(client.baseUrl, equals('http://localhost:8010'));
        expect(client.timeout, equals(const Duration(seconds: 60)));
        client.close();
      });

      test('test_auth_client_custom_base_url', () {
        final client = AuthClient(baseUrl: 'https://auth.example.com');
        expect(client.baseUrl, equals('https://auth.example.com'));
        client.close();
      });

      test('test_auth_client_custom_server_config', () {
        final config = ServerConfig(authUrl: 'https://custom-auth.example.com');
        final client = AuthClient(serverConfig: config);
        expect(client.baseUrl, equals('https://custom-auth.example.com'));
        client.close();
      });

      test('test_auth_client_base_url_overrides_config', () {
        final config = ServerConfig(authUrl: 'https://config-auth.example.com');
        final client = AuthClient(
          baseUrl: 'https://override-auth.example.com',
          serverConfig: config,
        );
        expect(client.baseUrl, equals('https://override-auth.example.com'));
        client.close();
      });

      test('test_auth_client_custom_timeout', () {
        final client = AuthClient(timeout: const Duration(seconds: 60));
        expect(client.timeout, equals(const Duration(seconds: 60)));
        client.close();
      });
    });

    group('TestAuthClientTokenManagement', () {
      test('test_login_success', () async {
        final responseBody = jsonEncode({
          'access_token': 'test_token_abc123',
          'token_type': 'bearer',
        });

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await authClient.login('testuser', 'testpass');

        verify(
          () => mockHttpClient.post(
            Uri.parse('http://localhost:8010/auth/token'),
            headers: any(named: 'headers'),
            body: {'username': 'testuser', 'password': 'testpass'},
          ),
        ).called(1);

        expect(result.accessToken, equals('test_token_abc123'));
        expect(result.tokenType, equals('bearer'));
      });

      test('test_login_invalid_credentials', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Unauthorized', 401));

        expect(
          () => authClient.login('invalid', 'invalid'),
          throwsA(isA<AuthenticationError>()),
        );
      });

      test('test_login_invalid_response_type', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode(['not', 'a', 'dict']), 200),
        );

        expect(
          () => authClient.login('testuser', 'testpass'),
          throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
        );
      });

      test('test_refresh_token_success', () async {
        final responseBody = jsonEncode({
          'access_token': 'new_token_xyz789',
          'token_type': 'bearer',
        });

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await authClient.refreshToken('old_token');

        verify(
          () => mockHttpClient.post(
            Uri.parse('http://localhost:8010/auth/token/refresh'),
            headers: {'Authorization': 'Bearer old_token'},
          ),
        ).called(1);

        expect(result.accessToken, equals('new_token_xyz789'));
        expect(result.tokenType, equals('bearer'));
      });

      test('test_refresh_token_expired', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Unauthorized', 401));

        expect(
          () => authClient.refreshToken('expired_token'),
          throwsA(isA<AuthenticationError>()),
        );
      });

      test('test_get_public_key_success', () async {
        final responseBody = jsonEncode({
          'public_key':
              '-----BEGIN PUBLIC KEY-----\ntest_key\n-----END PUBLIC KEY-----',
          'algorithm': 'ES256',
        });

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await authClient.getPublicKey();

        verify(
          () => mockHttpClient.get(
            Uri.parse('http://localhost:8010/auth/public-key'),
          ),
        ).called(1);

        expect(result.publicKey, contains('BEGIN PUBLIC KEY'));
        expect(result.algorithm, equals('ES256'));
      });
    });

    group('TestAuthClientUserInfo', () {
      test('test_get_current_user_success', () async {
        final now = DateTime.now().toUtc().toIso8601String();
        final responseBody = jsonEncode({
          'id': 1,
          'username': 'testuser',
          'is_admin': false,
          'is_active': true,
          'created_at': now,
          'permissions': ['read:jobs', 'write:jobs'],
        });

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await authClient.getCurrentUser('valid_token');

        verify(
          () => mockHttpClient.get(
            Uri.parse('http://localhost:8010/users/me'),
            headers: {'Authorization': 'Bearer valid_token'},
          ),
        ).called(1);

        expect(result.id, equals(1));
        expect(result.username, equals('testuser'));
        expect(result.permissions, equals(['read:jobs', 'write:jobs']));
      });

      test('test_get_current_user_invalid_token', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Unauthorized', 401));

        expect(
          () => authClient.getCurrentUser('invalid_token'),
          throwsA(isA<AuthenticationError>()),
        );
      });
    });

    group('TestAuthClientAdminUserManagement', () {
      test('test_create_user_success', () async {
        final now = DateTime.now().toUtc().toIso8601String();
        final responseBody = jsonEncode({
          'id': 2,
          'username': 'newuser',
          'is_admin': false,
          'is_active': true,
          'created_at': now,
          'permissions': ['read:jobs'],
        });

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final userCreate = UserCreateRequest(
          username: 'newuser',
          password: 'securepass',
          permissions: ['read:jobs'],
        );

        final result = await authClient.createUser('admin_token', userCreate);

        final expectedBody = {
          'username': 'newuser',
          'password': 'securepass',
          'is_admin': 'false',
          'is_active': 'true',
          'permissions': 'read:jobs',
        };

        verify(
          () => mockHttpClient.post(
            Uri.parse('http://localhost:8010/users/'),
            headers: {
              'Authorization': 'Bearer admin_token',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: expectedBody,
          ),
        ).called(1);

        expect(result.username, equals('newuser'));
        expect(result.permissions, equals(['read:jobs']));
      });

      test('test_create_user_non_admin', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Forbidden', 403));

        final userCreate = UserCreateRequest(
          username: 'newuser',
          password: 'securepass',
        );
        expect(
          () => authClient.createUser('non_admin_token', userCreate),
          throwsA(isA<PermissionError>()),
        );
      });

      test('test_create_user_duplicate_username', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Bad Request', 400));

        final userCreate = UserCreateRequest(
          username: 'existing_user',
          password: 'pass',
        );
        expect(
          () => authClient.createUser('admin_token', userCreate),
          throwsA(isA<ValidationError>()),
        );
      });

      test('test_list_users_success', () async {
        final now = DateTime.now().toUtc().toIso8601String();
        final responseBody = jsonEncode([
          {
            'id': 1,
            'username': 'user1',
            'is_admin': false,
            'is_active': true,
            'created_at': now,
            'permissions': <String>[],
          },
          {
            'id': 2,
            'username': 'user2',
            'is_admin': true,
            'is_active': true,
            'created_at': now,
            'permissions': ['*'],
          },
        ]);

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await authClient.listUsers('admin_token', limit: 10);

        verify(
          () => mockHttpClient.get(
            any(
              that: predicate(
                (Uri uri) =>
                    uri.path == '/users/' &&
                    uri.queryParameters['skip'] == '0' &&
                    uri.queryParameters['limit'] == '10',
              ),
            ),
            headers: {'Authorization': 'Bearer admin_token'},
          ),
        ).called(1);

        expect(result.length, equals(2));
        expect(result[0].username, equals('user1'));
        expect(result[1].username, equals('user2'));
        expect(result[1].isAdmin, isTrue);
      });

      test('test_list_users_non_admin', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Forbidden', 403));

        expect(
          () => authClient.listUsers('non_admin_token'),
          throwsA(isA<PermissionError>()),
        );
      });

      test('test_list_users_invalid_response_type', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'not': 'a list'}), 200),
        );

        expect(
          () => authClient.listUsers('admin_token'),
          throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
        );
      });

      test('test_get_user_success', () async {
        final now = DateTime.now().toUtc().toIso8601String();
        final responseBody = jsonEncode({
          'id': 2,
          'username': 'targetuser',
          'is_admin': false,
          'is_active': true,
          'created_at': now,
          'permissions': ['read:jobs', 'write:jobs'],
        });

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final result = await authClient.getUser('admin_token', 2);

        verify(
          () => mockHttpClient.get(
            Uri.parse('http://localhost:8010/users/2'),
            headers: {'Authorization': 'Bearer admin_token'},
          ),
        ).called(1);

        expect(result.id, equals(2));
        expect(result.username, equals('targetuser'));
      });

      test('test_get_user_not_found', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not Found', 404));

        expect(
          () => authClient.getUser('admin_token', 2),
          throwsA(isA<NotFoundError>()),
        );
      });

      test('test_update_user_success', () async {
        final now = DateTime.now().toUtc().toIso8601String();
        final responseBody = jsonEncode({
          'id': 2,
          'username': 'updateduser',
          'is_admin': true,
          'is_active': true,
          'created_at': now,
          'permissions': ['*'],
        });

        when(
          () => mockHttpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final userUpdate = UserUpdateRequest(permissions: ['*'], isAdmin: true);

        final result = await authClient.updateUser(
          'admin_token',
          2,
          userUpdate,
        );

        final expectedBody = {'permissions': '*', 'is_admin': 'true'};

        verify(
          () => mockHttpClient.put(
            Uri.parse('http://localhost:8010/users/2'),
            headers: {
              'Authorization': 'Bearer admin_token',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: expectedBody,
          ),
        ).called(1);

        expect(result.isAdmin, isTrue);
        expect(result.permissions, equals(['*']));
      });

      test('test_update_user_partial', () async {
        final now = DateTime.now().toUtc().toIso8601String();
        final responseBody = jsonEncode({
          'id': 2,
          'username': 'user',
          'is_admin': false,
          'is_active': true,
          'created_at': now,
          'permissions': <String>[],
        });

        when(
          () => mockHttpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final userUpdate = UserUpdateRequest(password: 'newpassword');

        final result = await authClient.updateUser(
          'admin_token',
          2,
          userUpdate,
        );

        verify(
          () => mockHttpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: {'password': 'newpassword'},
          ),
        ).called(1);

        expect(result.username, equals('user'));
      });

      test('test_update_user_not_found', () async {
        when(
          () => mockHttpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Not Found', 404));

        final userUpdate = UserUpdateRequest(isActive: false);
        expect(
          () => authClient.updateUser('admin_token', 999, userUpdate),
          throwsA(isA<NotFoundError>()),
        );
      });

      test('test_delete_user_success', () async {
        when(
          () => mockHttpClient.delete(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('', 204));

        await authClient.deleteUser('admin_token', 2);

        verify(
          () => mockHttpClient.delete(
            Uri.parse('http://localhost:8010/users/2'),
            headers: {'Authorization': 'Bearer admin_token'},
          ),
        ).called(1);
      });

      test('test_delete_user_not_found', () async {
        when(
          () => mockHttpClient.delete(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not Found', 404));

        expect(
          () => authClient.deleteUser('admin_token', 999),
          throwsA(isA<NotFoundError>()),
        );
      });

      test('test_delete_user_non_admin', () async {
        when(
          () => mockHttpClient.delete(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Forbidden', 403));

        expect(
          () => authClient.deleteUser('non_admin_token', 2),
          throwsA(isA<PermissionError>()),
        );
      });
    });

    group('TestAuthClientContextManager', () {
      test('test_context_manager_lifecycle', () async {
        final client = AuthClient();
        client.close();
      });

      test('test_manual_close', () async {
        final client = AuthClient();
        client.close();
      });
    });
  });
}
