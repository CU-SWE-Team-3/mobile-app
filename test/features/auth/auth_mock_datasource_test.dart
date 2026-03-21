import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/auth/data/datasources/auth_mock_datasource.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';

void main() {
  late AuthMockDatasource datasource;

  setUp(() {
    datasource = AuthMockDatasource();
  });

  group('AuthMockDatasource', () {

    group('register', () {

      test('returns a User', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'DJ Bio',
          age: 25,
        );
        expect(user, isA<User>());
      });

      test('id is mock_001', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'DJ Bio',
          age: 25,
        );
        expect(user.id, equals('mock_001'));
      });

      test('displayName matches input', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'DJ Bio',
          age: 25,
        );
        expect(user.displayName, equals('DJ Bio'));
      });

      test('permalink is lowercase with dashes', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'DJ Bio',
          age: 25,
        );
        expect(user.permalink, equals('dj-bio'));
      });

      test('isEmailVerified is false', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'Test',
          age: 25,
        );
        expect(user.isEmailVerified, isFalse);
      });

      test('isPremium is false', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'Test',
          age: 25,
        );
        expect(user.isPremium, isFalse);
      });

      test('role is listener', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'Test',
          age: 25,
        );
        expect(user.role, equals('listener'));
      });

      test('followerCount is 0', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'Test',
          age: 25,
        );
        expect(user.followerCount, equals(0));
      });

      test('followingCount is 0', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'Test',
          age: 25,
        );
        expect(user.followingCount, equals(0));
      });

      test('accountStatus is active', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'Test',
          age: 25,
        );
        expect(user.accountStatus, equals('active'));
      });

      test('works with gender parameter', () async {
        final user = await datasource.register(
          email: 'test@test.com',
          password: 'Pass1',
          displayName: 'Test',
          age: 25,
          gender: 'male',
        );
        expect(user, isA<User>());
      });

    });

    group('login', () {

      test('returns a User', () async {
        final user = await datasource.login(
          email: 'test@test.com',
          password: 'Pass1',
        );
        expect(user, isA<User>());
      });

      test('id is mock_001', () async {
        final user = await datasource.login(
          email: 'test@test.com',
          password: 'Pass1',
        );
        expect(user.id, equals('mock_001'));
      });

      test('isEmailVerified is true after login', () async {
        final user = await datasource.login(
          email: 'test@test.com',
          password: 'Pass1',
        );
        expect(user.isEmailVerified, isTrue);
      });

      test('displayName is Mock User', () async {
        final user = await datasource.login(
          email: 'test@test.com',
          password: 'Pass1',
        );
        expect(user.displayName, equals('Mock User'));
      });

      test('isPremium is false', () async {
        final user = await datasource.login(
          email: 'test@test.com',
          password: 'Pass1',
        );
        expect(user.isPremium, isFalse);
      });

    });

    group('verifyEmail', () {

      test('completes without throwing', () async {
        expect(
          () async => datasource.verifyEmail(token: 'token-123'),
          returnsNormally,
        );
      });

      

    });

    group('forgotPassword', () {

      test('completes without throwing', () async {
        expect(
          () async => datasource.forgotPassword(email: 'test@test.com'),
          returnsNormally,
        );
      });

      

    });

  });
}