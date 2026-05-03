import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/auth/data/datasources/auth_mock_datasource.dart';
import 'package:soundcloud_clone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';

// AuthMockDatasource is a concrete class — Mockito cannot mock it.
// We use it directly here since it is already a fake/stub by design.
// All its methods use Future.delayed with fixed return values,
// making it perfectly suitable for direct use in unit tests.
void main() {
  late AuthRepositoryImpl repository;
  late AuthMockDatasource datasource;

  setUp(() {
    datasource = AuthMockDatasource();
    repository = AuthRepositoryImpl(mockDatasource: datasource);
  });

  // ─── register ──────────────────────────────────────────────────────────────
  group('AuthRepositoryImpl.register', () {
    test('returns a User on success', () async {
      final result = await repository.register(
        email: 'test@test.com',
        password: 'pass',
        displayName: 'Test User',
        age: 22,
      );
      expect(result, isA<User>());
    });

    test('returned user has the provided displayName', () async {
      final result = await repository.register(
        email: 'test@test.com',
        password: 'pass',
        displayName: 'Kareem',
        age: 20,
      );
      expect(result.displayName, 'Kareem');
    });

    test('returned user is not email verified after registration', () async {
      final result = await repository.register(
        email: 'unverified@test.com',
        password: 'pass',
        displayName: 'Unverified',
        age: 18,
      );
      expect(result.isEmailVerified, isFalse);
    });

    test('returned user has role listener by default', () async {
      final result = await repository.register(
        email: 'a@a.com',
        password: 'p',
        displayName: 'A',
        age: 19,
      );
      expect(result.role, 'listener');
    });

    test('returned user has zero followers', () async {
      final result = await repository.register(
        email: 'zero@test.com',
        password: 'p',
        displayName: 'Zero',
        age: 21,
      );
      expect(result.followerCount, 0);
      expect(result.followingCount, 0);
    });

    test('accepts optional gender without error', () async {
      await expectLater(
        repository.register(
          email: 'g@g.com',
          password: 'p',
          displayName: 'G',
          age: 25,
          gender: 'female',
        ),
        completes,
      );
    });
  });

  // ─── login ─────────────────────────────────────────────────────────────────
  group('AuthRepositoryImpl.login', () {
    test('returns a User on success', () async {
      final result = await repository.login(
        email: 'user@test.com',
        password: 'pass',
      );
      expect(result, isA<User>());
    });

    test('returned user is email verified after login', () async {
      final result = await repository.login(
        email: 'user@test.com',
        password: 'pass',
      );
      expect(result.isEmailVerified, isTrue);
    });

    test('returned user has a non-empty displayName', () async {
      final result = await repository.login(
        email: 'user@test.com',
        password: 'pass',
      );
      expect(result.displayName, isNotEmpty);
    });

    test('returned user has a non-empty id', () async {
      final result = await repository.login(
        email: 'user@test.com',
        password: 'pass',
      );
      expect(result.id, isNotEmpty);
    });
  });

  // ─── verifyEmail ───────────────────────────────────────────────────────────
  group('AuthRepositoryImpl.verifyEmail', () {
    test('completes without throwing', () async {
      await expectLater(
        repository.verifyEmail(token: 'valid_token_123'),
        completes,
      );
    });

    test('returns Future<void>', () {
      expect(
        repository.verifyEmail(token: 'token'),
        isA<Future<void>>(),
      );
    });
  });

  // ─── forgotPassword ────────────────────────────────────────────────────────
  group('AuthRepositoryImpl.forgotPassword', () {
    test('completes without throwing', () async {
      await expectLater(
        repository.forgotPassword(email: 'forgot@test.com'),
        completes,
      );
    });

    test('returns Future<void>', () {
      expect(
        repository.forgotPassword(email: 'e@e.com'),
        isA<Future<void>>(),
      );
    });
  });

  // ─── logout ────────────────────────────────────────────────────────────────
  group('AuthRepositoryImpl.logout', () {
    test('completes without throwing', () async {
      await expectLater(repository.logout(), completes);
    });
  });

  // ─── getCurrentUser ────────────────────────────────────────────────────────
  group('AuthRepositoryImpl.getCurrentUser', () {
    test('returns null (no session stored)', () async {
      final result = await repository.getCurrentUser();
      expect(result, isNull);
    });
  });
}
