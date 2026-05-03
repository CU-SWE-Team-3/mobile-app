import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';
import 'package:soundcloud_clone/features/auth/presentation/providers/auth_provider.dart';

void main() {
  const tUser = User(
    id: 'state_user',
    permalink: 'state-user',
    displayName: 'State User',
    favoriteGenres: [],
    socialLinks: {},
    isPrivate: false,
    role: 'listener',
    isPremium: false,
    isEmailVerified: true,
    accountStatus: 'active',
    followerCount: 0,
    followingCount: 0,
  );

  group('AuthState — default constructor', () {
    test('initialises with null user, isLoading = false, null error', () {
      const state = AuthState();
      expect(state.user, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });
  });

  group('AuthState.copyWith', () {
    test('copyWith with no args returns same values', () {
      const original = AuthState(user: tUser, isLoading: false, error: null);
      final copy = original.copyWith();

      expect(copy.user, tUser);
      expect(copy.isLoading, isFalse);
      expect(copy.error, isNull);
    });

    test('copyWith updates isLoading without changing other fields', () {
      const original = AuthState(user: tUser, isLoading: false, error: null);
      final loading = original.copyWith(isLoading: true);

      expect(loading.isLoading, isTrue);
      expect(loading.user, tUser);
      expect(loading.error, isNull);
    });

    test('copyWith updates error without changing user', () {
      const original = AuthState(user: tUser, isLoading: false, error: null);
      final withError = original.copyWith(error: 'Something went wrong');

      expect(withError.error, 'Something went wrong');
      expect(withError.user, tUser);
      expect(withError.isLoading, isFalse);
    });

    test('copyWith updates user without changing isLoading or error', () {
      const original = AuthState();
      final withUser = original.copyWith(user: tUser);

      expect(withUser.user, tUser);
      expect(withUser.isLoading, isFalse);
      expect(withUser.error, isNull);
    });

    test('copyWith sets isLoading = false and clears error after success', () {
      const loading = AuthState(isLoading: true, error: null);
      final success = loading.copyWith(user: tUser, isLoading: false);

      expect(success.user, tUser);
      expect(success.isLoading, isFalse);
      expect(success.error, isNull);
    });

    test('copyWith sets error and isLoading = false on failure', () {
      const loading = AuthState(isLoading: true);
      final failed = loading.copyWith(error: 'Auth error', isLoading: false);

      expect(failed.error, 'Auth error');
      expect(failed.isLoading, isFalse);
      expect(failed.user, isNull);
    });

    test('copyWith preserves existing user when only error is updated', () {
      final stateWithUser = AuthState(user: tUser);
      final withError = stateWithUser.copyWith(error: 'Refresh error');

      expect(withError.user, tUser);
      expect(withError.error, 'Refresh error');
    });

    test('copyWith creates a new instance (immutability)', () {
      const original = AuthState();
      final copy = original.copyWith(isLoading: true);

      expect(identical(original, copy), isFalse);
    });
  });
}
