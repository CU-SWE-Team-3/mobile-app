import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/auth/data/datasources/auth_mock_datasource.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';

void main() {
  late AuthMockDatasource datasource;

  setUp(() {
    datasource = AuthMockDatasource();
  });

  // ─── register ──────────────────────────────────────────────────────────────
  group('AuthMockDatasource.register', () {
    test('returns a User with the provided displayName', () async {
      final user = await datasource.register(
        email: 'test@example.com',
        password: 'password123',
        displayName: 'Test User',
        age: 25,
      );
      expect(user, isA<User>());
      expect(user.displayName, 'Test User');
    });

    test('generates permalink from displayName (lowercase, hyphenated)', () async {
      final user = await datasource.register(
        email: 'a@b.com',
        password: 'pass',
        displayName: 'Hello World',
        age: 20,
      );
      expect(user.permalink, 'hello-world');
    });

    test('returns a fixed mock id', () async {
      final user = await datasource.register(
        email: 'a@b.com',
        password: 'pass',
        displayName: 'Any Name',
        age: 22,
      );
      expect(user.id, 'mock_001');
    });

    test('email is NOT verified immediately after registration', () async {
      final user = await datasource.register(
        email: 'verify@test.com',
        password: 'pass',
        displayName: 'Unverified',
        age: 18,
      );
      expect(user.isEmailVerified, isFalse);
    });

    test('registered user is not premium by default', () async {
      final user = await datasource.register(
        email: 'free@test.com',
        password: 'pass',
        displayName: 'Free User',
        age: 21,
      );
      expect(user.isPremium, isFalse);
    });

    test('registered user has role listener by default', () async {
      final user = await datasource.register(
        email: 'listener@test.com',
        password: 'pass',
        displayName: 'Listener',
        age: 23,
      );
      expect(user.role, 'listener');
    });

    test('registered user has zero followers and following', () async {
      final user = await datasource.register(
        email: 'zero@test.com',
        password: 'zero',
        displayName: 'Zero Social',
        age: 19,
      );
      expect(user.followerCount, 0);
      expect(user.followingCount, 0);
    });

    test('accepts optional gender parameter without error', () async {
      expect(
        () => datasource.register(
          email: 'g@g.com',
          password: 'pass',
          displayName: 'Gendered',
          age: 30,
          gender: 'male',
        ),
        returnsNormally,
      );
    });

    test('account status is active after registration', () async {
      final user = await datasource.register(
        email: 'active@test.com',
        password: 'pass',
        displayName: 'Active',
        age: 25,
      );
      expect(user.accountStatus, 'active');
    });

    test('profile is public (isPrivate = false) by default', () async {
      final user = await datasource.register(
        email: 'public@test.com',
        password: 'pass',
        displayName: 'Public',
        age: 20,
      );
      expect(user.isPrivate, isFalse);
    });

    test('register completes and is a Future<User>', () {
      final future = datasource.register(
        email: 'async@test.com',
        password: 'pass',
        displayName: 'Async',
        age: 22,
      );
      expect(future, isA<Future<User>>());
    });
  });

  // ─── login ─────────────────────────────────────────────────────────────────
  group('AuthMockDatasource.login', () {
    test('returns a User instance', () async {
      final user = await datasource.login(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(user, isA<User>());
    });

    test('returned user email is verified', () async {
      final user = await datasource.login(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(user.isEmailVerified, isTrue);
    });

    test('login returns the mock user id', () async {
      final user = await datasource.login(
        email: 'any@email.com',
        password: 'anypass',
      );
      expect(user.id, 'mock_001');
    });

    test('login returns user with non-empty displayName', () async {
      final user = await datasource.login(
        email: 'x@x.com',
        password: 'x',
      );
      expect(user.displayName, isNotEmpty);
    });

    test('login returns user with non-empty permalink', () async {
      final user = await datasource.login(
        email: 'x@x.com',
        password: 'x',
      );
      expect(user.permalink, isNotEmpty);
    });

    test('login is a Future<User>', () {
      final future = datasource.login(email: 'e@e.com', password: 'p');
      expect(future, isA<Future<User>>());
    });
  });

  // ─── verifyEmail ───────────────────────────────────────────────────────────
  group('AuthMockDatasource.verifyEmail', () {
    test('completes without throwing', () async {
      await expectLater(
        datasource.verifyEmail(token: 'valid_token_abc'),
        completes,
      );
    });

    test('returns void (Future<void>)', () {
      final future = datasource.verifyEmail(token: 'token123');
      expect(future, isA<Future<void>>());
    });

    test('accepts any non-empty token string', () async {
      await expectLater(
        datasource.verifyEmail(token: 'LONG_TOKEN_1234567890'),
        completes,
      );
    });
  });

  // ─── forgotPassword ────────────────────────────────────────────────────────
  group('AuthMockDatasource.forgotPassword', () {
    test('completes without throwing', () async {
      await expectLater(
        datasource.forgotPassword(email: 'forgot@example.com'),
        completes,
      );
    });

    test('returns void (Future<void>)', () {
      final future = datasource.forgotPassword(email: 'e@e.com');
      expect(future, isA<Future<void>>());
    });

    test('accepts any email format without validation error', () async {
      await expectLater(
        datasource.forgotPassword(email: 'user+alias@subdomain.example.org'),
        completes,
      );
    });
  });
}
