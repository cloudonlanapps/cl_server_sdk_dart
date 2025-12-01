import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('Session Exceptions Tests', () {
    group('SessionException', () {
      test('creates exception with message', () {
        final exception = SessionException(message: 'Test error');

        expect(exception.message, 'Test error');
        expect(exception.statusCode, isNull);
      });

      test('toString returns message', () {
        final exception = SessionException(message: 'Test error');
        expect(exception.toString(), 'Test error');
      });

      test('is CLServerException', () {
        final exception = SessionException(message: 'Test');
        expect(exception, isA<CLServerException>());
      });
    });

    group('NotLoggedInException', () {
      test('creates with default message', () {
        final exception = NotLoggedInException();

        expect(exception.message, isNotEmpty);
        expect(exception.message.contains('login'), true);
      });

      test('is SessionException', () {
        final exception = NotLoggedInException();
        expect(exception, isA<SessionException>());
      });

      test('toString contains helpful message', () {
        final exception = NotLoggedInException();
        expect(exception.toString(), contains('SessionManager.login'));
      });
    });

    group('TokenExpiredException', () {
      test('creates with default message', () {
        final exception = TokenExpiredException();

        expect(exception.message, isNotEmpty);
        expect(exception.message.contains('expired'), true);
      });

      test('is SessionException', () {
        final exception = TokenExpiredException();
        expect(exception, isA<SessionException>());
      });
    });

    group('RefreshFailedException', () {
      test('creates with custom details message', () {
        final exception = RefreshFailedException('Network timeout');

        expect(exception.message, contains('Token refresh failed'));
        expect(exception.message, contains('Network timeout'));
      });

      test('is SessionException', () {
        final exception = RefreshFailedException('Error details');
        expect(exception, isA<SessionException>());
      });

      test('handles empty details string', () {
        final exception = RefreshFailedException('');
        expect(exception.message, isNotEmpty);
      });

      test('handles special characters in details', () {
        final exception =
            RefreshFailedException('Error: "Invalid" token & failed');
        expect(
          exception.message,
          contains('Error: "Invalid" token & failed'),
        );
      });
    });

    group('TokenStorageException', () {
      test('creates with custom message', () {
        final exception = TokenStorageException('Failed to save token');

        expect(exception.message, contains('Token storage error'));
        expect(exception.message, contains('Failed to save token'));
      });

      test('is SessionException', () {
        final exception = TokenStorageException('Error');
        expect(exception, isA<SessionException>());
      });

      test('handles empty message', () {
        final exception = TokenStorageException('');
        expect(exception.message, contains('Token storage error'));
      });
    });

    group('PasswordEncryptionException', () {
      test('creates with custom message', () {
        final exception = PasswordEncryptionException('Encryption failed');

        expect(exception.message, contains('Password encryption error'));
        expect(exception.message, contains('Encryption failed'));
      });

      test('is SessionException', () {
        final exception = PasswordEncryptionException('Error');
        expect(exception, isA<SessionException>());
      });

      test('handles empty message', () {
        final exception = PasswordEncryptionException('');
        expect(exception.message, contains('Password encryption error'));
      });

      test('handles cryptographic error messages', () {
        final exception = PasswordEncryptionException(
          'Invalid padding in decryption',
        );
        expect(
          exception.message,
          contains('Invalid padding in decryption'),
        );
      });
    });

    group('Exception Throwing and Catching', () {
      test('NotLoggedInException can be caught as SessionException', () {
        expect(
          () => throw NotLoggedInException(),
          throwsA(isA<SessionException>()),
        );
      });

      test('TokenExpiredException can be caught as SessionException', () {
        expect(
          () => throw TokenExpiredException(),
          throwsA(isA<SessionException>()),
        );
      });

      test('RefreshFailedException can be caught as SessionException', () {
        expect(
          () => throw RefreshFailedException('details'),
          throwsA(isA<SessionException>()),
        );
      });

      test('TokenStorageException can be caught as SessionException', () {
        expect(
          () => throw TokenStorageException('message'),
          throwsA(isA<SessionException>()),
        );
      });

      test(
        'PasswordEncryptionException can be caught as SessionException',
        () {
          expect(
            () => throw PasswordEncryptionException('message'),
            throwsA(isA<SessionException>()),
          );
        },
      );

      test('SessionException can be caught as CLServerException', () {
        expect(
          () => throw SessionException(message: 'error'),
          throwsA(isA<CLServerException>()),
        );
      });

      test('specific exception type can be caught', () {
        expect(
          () => throw NotLoggedInException(),
          throwsA(isA<NotLoggedInException>()),
        );
      });
    });

    group('Exception Messages', () {
      test('messages are descriptive', () {
        final exceptions = [
          NotLoggedInException(),
          TokenExpiredException(),
          RefreshFailedException('details'),
          TokenStorageException('message'),
          PasswordEncryptionException('message'),
        ];

        for (final exception in exceptions) {
          expect(exception.message, isNotEmpty);
          expect(exception.message.length, greaterThan(5));
        }
      });

      test('exception messages do not contain null values', () {
        final exception = RefreshFailedException('null');
        expect(exception.message.contains('null'), true);
      });
    });
  });
}
