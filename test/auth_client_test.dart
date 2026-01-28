import 'dart:convert';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

// Helper to register fallbacks if needed.
// For http.Request/Response we might need them if used as arguments in verify.
// But mostly we verify concrete instances or any().

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('AuthClient', () {
    late MockHttpClient mockHttpClient;
    late AuthClient authClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      // Inject mock client into AuthClient
      authClient = AuthClient(
        client: mockHttpClient,
        baseUrl: 'http://localhost:8000',
      );
    });

    tearDown(() {
      authClient.close();
    });

    group('Init', () {
      test('test_auth_client_default_config', () {
        final client = AuthClient();
        expect(client.baseUrl, equals('http://localhost:8000'));
        client.close();
      });

      test('test_auth_client_custom_base_url', () {
        final client = AuthClient(baseUrl: 'https://auth.example.com');
        expect(client.baseUrl, equals('https://auth.example.com'));
        client.close();
      });
    });

    group('TokenManagement', () {
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
            Uri.parse('http://localhost:8000/auth/token'),
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
            Uri.parse('http://localhost:8000/auth/token/refresh'),
            headers: {'Authorization': 'Bearer old_token'},
          ),
        ).called(1);

        expect(result.accessToken, equals('new_token_xyz789'));
      });
    });

    group('UserInfo', () {
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
            Uri.parse('http://localhost:8000/users/me'),
            headers: {'Authorization': 'Bearer valid_token'},
          ),
        ).called(1);

        expect(result.id, equals(1));
        expect(result.username, equals('testuser'));
        expect(result.permissions, equals(['read:jobs', 'write:jobs']));
      });
    });

    group('AdminUserManagement', () {
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

        // Verify arguments
        // Logic converts list to comma separated string?
        // Let's check auth_client.dart implementation.
        // In createUser:
        // data['permissions'] = userCreate.permissions.join(',');

        final expectedBody = {
          'username': 'newuser',
          'password': 'securepass',
          'is_admin': 'false', // toString()
          'is_active': 'true', // toString()
          'permissions': 'read:jobs',
        };

        verify(
          () => mockHttpClient.post(
            Uri.parse('http://localhost:8000/users/'),
            headers: {
              'Authorization': 'Bearer admin_token',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: expectedBody,
          ),
        ).called(1);

        expect(result.username, equals('newuser'));
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

        final result = await authClient.listUsers(
          'admin_token',
          limit: 10,
        );

        // verify query params
        // http package usually does not put query params in uri passed to get unless explicitly constructed.
        // auth_client.dart constructs Uri with queryParameters.
        // Uri.parse(...).replace(queryParameters: ...)

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
        expect(result[1].isAdmin, isTrue);
      });
    });
  });
}
