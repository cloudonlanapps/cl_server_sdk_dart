import 'dart:convert';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('TestTokenResponse', () {
    test('test_token_response_valid', () {
      final data = {'access_token': 'eyJhbGc...', 'token_type': 'bearer'};
      final token = TokenResponse.fromMap(data);

      expect(token.accessToken, equals('eyJhbGc...'));
      expect(token.tokenType, equals('bearer'));
    });

    test('test_token_response_from_json', () {
      final data = {'access_token': 'test_token', 'token_type': 'bearer'};
      final token = TokenResponse.fromJson(jsonEncode(data));

      expect(token.accessToken, equals('test_token'));
      expect(token.tokenType, equals('bearer'));
    });

    test('test_token_response_to_json', () {
      final token = TokenResponse(
        accessToken: 'test_token',
        tokenType: 'bearer',
      );
      final data = token.toMap();

      expect(
        data,
        equals({'access_token': 'test_token', 'token_type': 'bearer'}),
      );
    });

    test('test_token_response_missing_fields', () {
      expect(
        () => TokenResponse.fromMap({'access_token': 'test_token'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('TestPublicKeyResponse', () {
    test('test_public_key_response_valid', () {
      final data = {
        'public_key': '-----BEGIN PUBLIC KEY-----\n...',
        'algorithm': 'ES256',
      };
      final response = PublicKeyResponse.fromMap(data);

      expect(response.publicKey, equals('-----BEGIN PUBLIC KEY-----\n...'));
      expect(response.algorithm, equals('ES256'));
    });

    test('test_public_key_response_from_json', () {
      final data = {'public_key': 'test_key', 'algorithm': 'ES256'};
      final response = PublicKeyResponse.fromJson(jsonEncode(data));

      expect(response.publicKey, equals('test_key'));
      expect(response.algorithm, equals('ES256'));
    });
    group('TestUserResponse', () {
      test('test_user_response_valid', () {
        final now = DateTime.now().toUtc().toIso8601String();
        final data = {
          'id': 1,
          'username': 'testuser',
          'is_admin': false,
          'is_active': true,
          'created_at': now,
          'permissions': ['read:jobs', 'write:jobs'],
        };

        final user = UserResponse.fromMap(data);

        expect(user.id, equals(1));
        expect(user.username, equals('testuser'));
        expect(user.isAdmin, isFalse);
        expect(user.isActive, isTrue);
        expect(user.permissions, equals(['read:jobs', 'write:jobs']));
      });

      test('test_user_response_defaults', () {
        final now = DateTime.now().toUtc().toIso8601String();
        final data = {'id': 1, 'username': 'testuser', 'created_at': now};

        final user = UserResponse.fromMap(data);

        expect(user.isAdmin, isFalse);
        expect(user.isActive, isTrue);
        expect(user.permissions, isEmpty);
      });

      test('test_user_response_from_json', () {
        final data = {
          'id': 2,
          'username': 'admin',
          'is_admin': true,
          'is_active': true,
          'created_at': '2024-01-15T10:30:00Z',
          'permissions': ['*'],
        };

        final user = UserResponse.fromJson(jsonEncode(data));

        expect(user.id, equals(2));
        expect(user.username, equals('admin'));
        expect(user.isAdmin, isTrue);
        expect(user.permissions, equals(['*']));
      });

      test('test_user_response_to_json', () {
        final now = DateTime.now().toUtc();
        final user = UserResponse(
          id: 1,
          username: 'testuser',
          createdAt: now,
          permissions: ['read:jobs'],
        );

        final data = user.toMap();

        expect(data['id'], equals(1));
        expect(data['username'], equals('testuser'));
        expect(data['is_admin'], isFalse);
        expect(data['permissions'], equals(['read:jobs']));
      });
    });

    group('TestUserCreateRequest', () {
      test('test_user_create_request_valid', () {
        final data = {
          'username': 'newuser',
          'password': 'securepass',
          'is_admin': false,
          'is_active': true,
          'permissions': ['read:jobs'],
        };
        final request = UserCreateRequest.fromMap(data);

        expect(request.username, equals('newuser'));
        expect(request.password, equals('securepass'));
        expect(request.isAdmin, isFalse);
        expect(request.isActive, isTrue);
        expect(request.permissions, equals(['read:jobs']));
      });

      test('test_user_create_request_defaults', () {
        final request = UserCreateRequest(
          username: 'newuser',
          password: 'password',
        );

        expect(request.isAdmin, isFalse);
        expect(request.isActive, isTrue);
        expect(request.permissions, isEmpty);
      });

      test('test_user_create_request_admin', () {
        final request = UserCreateRequest(
          username: 'admin',
          password: 'adminpass',
          isAdmin: true,
          permissions: ['*'],
        );

        expect(request.isAdmin, isTrue);
        expect(request.permissions, equals(['*']));
      });

      test('test_user_create_request_to_json', () {
        final request = UserCreateRequest(
          username: 'testuser',
          password: 'testpass',
          permissions: ['read:jobs', 'write:jobs'],
        );

        final data = request.toMap();

        expect(data['username'], equals('testuser'));
        expect(data['password'], equals('testpass'));
        expect(data['permissions'], equals(['read:jobs', 'write:jobs']));
      });
    });

    group('TestUserUpdateRequest', () {
      test('test_user_update_request_all_fields', () {
        final data = {
          'password': 'newpassword',
          'permissions': ['*'],
          'is_active': false,
          'is_admin': true,
        };
        final request = UserUpdateRequest.fromMap(data);

        expect(request.password, equals('newpassword'));
        expect(request.permissions, equals(['*']));
        expect(request.isActive, isFalse);
        expect(request.isAdmin, isTrue);
      });

      test('test_user_update_request_partial', () {
        final request1 = UserUpdateRequest(password: 'newpass');
        expect(request1.password, equals('newpass'));
        expect(request1.permissions, isNull);
        expect(request1.isActive, isNull);
        expect(request1.isAdmin, isNull);

        final request2 = UserUpdateRequest(permissions: ['read:jobs']);
        expect(request2.password, isNull);
        expect(request2.permissions, equals(['read:jobs']));
      });

      test('test_user_update_request_empty', () {
        final request = UserUpdateRequest();

        expect(request.password, isNull);
        expect(request.permissions, isNull);
        expect(request.isActive, isNull);
        expect(request.isAdmin, isNull);
      });

      test('test_user_update_request_to_json_excludes_none', () {
        final request = UserUpdateRequest(password: 'newpass', isAdmin: true);
        final data = request.toMap();

        expect(data, contains('password'));
        expect(data, contains('is_admin'));
        expect(data, isNot(contains('permissions')));
        expect(data, isNot(contains('is_active')));
      });
    });
  });
}
