import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart' as mockito;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';
import 'package:soundcloud_clone/features/auth/domain/usecases/register_use_case.dart';
import 'package:soundcloud_clone/features/auth/presentation/providers/auth_provider.dart';

@GenerateMocks([RegisterUseCase])
import 'auth_provider_test.mocks.dart';

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

class MockDioClient extends Mock implements DioClient {}

class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  late MockRegisterUseCase mockRegisterUseCase;
  late MockDioClient mockDioClient;
  late MockDio mockDio;

  setUp(() {
    mockRegisterUseCase = MockRegisterUseCase();
    mockDioClient = MockDioClient();
    mockDio = MockDio();

    when(() => mockDioClient.dio).thenReturn(mockDio);
    when(() => mockDio.options)
        .thenReturn(BaseOptions(headers: <String, dynamic>{}));
    when(() => mockDio.delete('/notifications/fcm-token')).thenAnswer(
      (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/notifications/fcm-token')),
    );
    when(() => mockDio.post('/auth/logout')).thenAnswer(
      (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/logout')),
    );
  });

  group('AuthNotifier', () {
    test('initial state should be AuthState with no user and not loading', () {
      final notifier = AuthNotifier(
        registerUseCase: mockRegisterUseCase,
        dioClient: mockDioClient,
      );
      expect(notifier.state.user, null);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });

    test('register success should update state with user', () async {
      mockito
          .when(mockRegisterUseCase.call(
            email: 'test@example.com',
            password: 'pass',
            displayName: 'Test',
            age: 25,
            gender: 'Male',
          ))
          .thenAnswer((_) async => testUser);

      final notifier = AuthNotifier(
        registerUseCase: mockRegisterUseCase,
        dioClient: mockDioClient,
      );

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
      mockito
          .when(mockRegisterUseCase.call(
            email: 'test@example.com',
            password: 'pass',
            displayName: 'Test',
            age: 25,
            gender: 'Male',
          ))
          .thenThrow(Exception('Registration failed'));

      final notifier = AuthNotifier(
        registerUseCase: mockRegisterUseCase,
        dioClient: mockDioClient,
      );

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

    test('logout should reset state', () async {
      final notifier = AuthNotifier(
        registerUseCase: mockRegisterUseCase,
        dioClient: mockDioClient,
      );
      notifier.state =
          const AuthState(user: testUser, isLoading: true, error: 'error');

      await notifier.logout();

      expect(notifier.state.user, null);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });
  });

  group('AuthState', () {
    test('copyWith should update fields correctly', () {
      const state = AuthState(user: testUser, isLoading: false, error: null);

      final newState = state.copyWith(isLoading: true, error: 'error');

      expect(newState.user, testUser);
      expect(newState.isLoading, true);
      expect(newState.error, 'error');
    });
  });
}
