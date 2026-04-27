import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';
import 'package:soundcloud_clone/features/auth/domain/usecases/register_use_case.dart';
import 'package:soundcloud_clone/features/auth/presentation/providers/auth_provider.dart';

@GenerateMocks([RegisterUseCase])
import 'auth_provider_test.mocks.dart';

void main() {
  late MockRegisterUseCase mockRegisterUseCase;

  setUp(() {
    mockRegisterUseCase = MockRegisterUseCase();
  });

  group('AuthNotifier', () {
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

    test('initial state should be AuthState with no user and not loading', () {
      final notifier = AuthNotifier(registerUseCase: mockRegisterUseCase);
      expect(notifier.state.user, null);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });

    test('register success should update state with user', () async {
      when(mockRegisterUseCase.call(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).thenAnswer((_) async => testUser);

      final notifier = AuthNotifier(registerUseCase: mockRegisterUseCase);

      await notifier.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      );

      expect(notifier.state.user, testUser);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });

    test('register failure should update state with error', () async {
      when(mockRegisterUseCase.call(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).thenThrow(Exception('Registration failed'));

      final notifier = AuthNotifier(registerUseCase: mockRegisterUseCase);

      await notifier.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      );

      expect(notifier.state.user, null);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, 'Exception: Registration failed');
    });

    test('logout should reset state', () {
      final notifier = AuthNotifier(registerUseCase: mockRegisterUseCase);
      notifier.state = const AuthState(user: testUser, isLoading: true, error: 'error');

      notifier.logout();

      expect(notifier.state.user, null);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });
  });

  group('AuthState', () {
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

    test('copyWith should update fields correctly', () {
      const state = AuthState(user: testUser, isLoading: false, error: null);

      final newState = state.copyWith(isLoading: true, error: 'error');

      expect(newState.user, testUser);
      expect(newState.isLoading, true);
      expect(newState.error, 'error');
    });
  });
}