import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:soundcloud_clone/features/auth/data/datasources/auth_mock_datasource.dart';
import 'package:soundcloud_clone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';

@GenerateMocks([AuthMockDatasource])
import 'auth_repository_impl_test.mocks.dart';

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthMockDatasource mockDatasource;

  setUp(() {
    mockDatasource = MockAuthMockDatasource();
    repository = AuthRepositoryImpl(mockDatasource: mockDatasource);
  });

  group('AuthRepositoryImpl', () {
    const testUser = User(
      id: '1',
      permalink: 'test',
      displayName: 'Test',
      favoriteGenres: [],
      socialLinks: {},
      isPrivate: false,
      role: 'listener',
      isPremium: false,
      isEmailVerified: false,
      accountStatus: 'active',
      followerCount: 0,
      followingCount: 0,
    );

    test('register calls datasource and returns User', () async {
      when(mockDatasource.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).thenAnswer((_) async => testUser);

      final result = await repository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      );

      expect(result, testUser);
      verify(mockDatasource.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).called(1);
    });

    test('register throws when datasource throws', () async {
      when(mockDatasource.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).thenThrow(Exception('Datasource error'));

      expect(
        () => repository.register(
          email: 'test@example.com',
          password: 'pass',
          displayName: 'Test',
          age: 25,
          gender: 'Male',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('login calls datasource and returns User', () async {
      when(mockDatasource.login(
        email: 'test@example.com',
        password: 'pass',
      )).thenAnswer((_) async => testUser);

      final result = await repository.login(
        email: 'test@example.com',
        password: 'pass',
      );

      expect(result, testUser);
      verify(mockDatasource.login(
        email: 'test@example.com',
        password: 'pass',
      )).called(1);
    });

    test('login throws when datasource throws', () async {
      when(mockDatasource.login(
        email: 'test@example.com',
        password: 'pass',
      )).thenThrow(Exception('Login failed'));

      expect(
        () => repository.login(
          email: 'test@example.com',
          password: 'pass',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('verifyEmail calls datasource with token', () async {
      when(mockDatasource.verifyEmail(token: 'token')).thenAnswer((_) async {});

      await repository.verifyEmail(token: 'token');

      verify(mockDatasource.verifyEmail(token: 'token')).called(1);
    });

    test('forgotPassword calls datasource with email', () async {
      when(mockDatasource.forgotPassword(email: 'test@example.com')).thenAnswer((_) async {});

      await repository.forgotPassword(email: 'test@example.com');

      verify(mockDatasource.forgotPassword(email: 'test@example.com')).called(1);
    });

    test('logout completes without throwing', () async {
      await expectLater(repository.logout(), completes);
    });

    test('getCurrentUser returns null', () async {
      final result = await repository.getCurrentUser();
      expect(result, null);
    });
  });
}