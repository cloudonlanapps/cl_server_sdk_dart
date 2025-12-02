import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAuthService extends Mock implements AuthService {}

class MockStoreService extends Mock implements StoreService {}

void main() {
  group('UserManager', () {
    late MockAuthService mockAuthService;
    late MockStoreService mockStoreService;
    late UserManager userManager;

    setUp(() {
      mockAuthService = MockAuthService();
      mockStoreService = MockStoreService();
      userManager = UserManager(
        authService: mockAuthService,
        storeService: mockStoreService,
      );
    });

    test('createUser calls AuthService.createUser', () async {
      const username = 'testuser';
      const password = 'password';
      final createdUser = User(
        id: 1,
        username: 't#testuser',
        isAdmin: false,
        isActive: true,
        createdAt: DateTime.now(),
        permissions: const <String>[],
      );

      when(
        () => mockAuthService.createUser(
          username: 't#$username',
          password: password,
        ),
      ).thenAnswer((_) async => createdUser);

      final result = await userManager.createUser(
        username: username,
        password: password,
      );

      expect(result.isSuccess, true);
      expect(result.data, createdUser);
      verify(
        () => mockAuthService.createUser(
          username: 't#$username',
          password: password,
          permissions: [],
        ),
      ).called(1);
    });

    test('getUser calls AuthService.getUser', () async {
      final user = User(
        id: 1,
        username: 't#testuser',
        isActive: true,
        createdAt: DateTime.now(),
        permissions: const <String>[],
        isAdmin: false,
      );

      when(() => mockAuthService.getUser(1)).thenAnswer((_) async => user);

      final result = await userManager.getUser(userId: 1);

      expect(result.isSuccess, true);
      expect(result.data, user);
      verify(() => mockAuthService.getUser(1)).called(1);
    });

    test('listUsers calls AuthService.listUsers', () async {
      final users = [
        User(
          id: 1,
          username: 't#user1',
          isAdmin: false,
          isActive: true,
          createdAt: DateTime.now(),
          permissions: const <String>[],
        ),
      ];

      when(
        () => mockAuthService.listUsers(),
      ).thenAnswer((_) async => users);

      final result = await userManager.listUsers();

      expect(result.isSuccess, true);
      expect((result.data as List).length, 1);
      verify(() => mockAuthService.listUsers()).called(1);
    });

    test('updateUser calls AuthService.updateUser', () async {
      final updatedUser = User(
        id: 1,
        username: 't#testuser',
        isAdmin: true,
        isActive: true,
        createdAt: DateTime.now(),
        permissions: const <String>[],
      );

      when(
        () => mockAuthService.updateUser(
          1,
          isAdmin: true,
        ),
      ).thenAnswer((_) async => updatedUser);

      final result = await userManager.updateUser(
        userId: 1,
        isAdmin: true,
      );

      expect(result.isSuccess, true);
      expect(result.data, updatedUser);
      verify(
        () => mockAuthService.updateUser(
          1,
          isAdmin: true,
        ),
      ).called(1);
    });

    test('deleteUser calls AuthService.deleteUser', () async {
      when(() => mockAuthService.deleteUser(1)).thenAnswer((_) async {});

      final result = await userManager.deleteUser(userId: 1);

      expect(result.isSuccess, true);
      verify(() => mockAuthService.deleteUser(1)).called(1);
    });

    test('getUserPermissions calls AuthService.getUser', () async {
      final user = User(
        id: 1,
        username: 't#testuser',
        isAdmin: false,
        isActive: true,
        createdAt: DateTime.now(),
        permissions: const <String>['read:data'],
      );

      when(() => mockAuthService.getUser(1)).thenAnswer((_) async => user);

      final result = await userManager.getUserPermissions(userId: 1);

      expect(result.isSuccess, true);
      expect(result.data, ['read:data']);
      verify(() => mockAuthService.getUser(1)).called(1);
    });
  });
}
