import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';
import 'package:soundcloud_clone/features/auth/domain/repositories/auth_repository.dart';
import 'package:soundcloud_clone/features/auth/domain/usecases/register_use_case.dart';

import 'register_use_case_test.mocks.dart';

// AuthRepository is abstract — Mockito can mock it correctly.
@GenerateMocks([AuthRepository])
void main() {
  late RegisterUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = RegisterUseCase(repository: mockRepository);
  });

  const tUser = User(
    id: 'user_001',
    permalink: 'jane-doe',
    displayName: 'Jane Doe',
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

  group('RegisterUseCase', () {
    test('delegates call to AuthRepository.register with correct params',
        () async {
      when(mockRepository.register(
        email: 'jane@example.com',
        password: 'secret123',
        displayName: 'Jane Doe',
        age: 25,
        gender: null,
      )).thenAnswer((_) async => tUser);

      await useCase(
        email: 'jane@example.com',
        password: 'secret123',
        displayName: 'Jane Doe',
        age: 25,
      );

      verify(mockRepository.register(
        email: 'jane@example.com',
        password: 'secret123',
        displayName: 'Jane Doe',
        age: 25,
        gender: null,
      )).called(1);
    });

    test('returns the User returned by the repository', () async {
      when(mockRepository.register(
        email: anyNamed('email'),
        password: anyNamed('password'),
        displayName: anyNamed('displayName'),
        age: anyNamed('age'),
        gender: anyNamed('gender'),
      )).thenAnswer((_) async => tUser);

      final result = await useCase(
        email: 'jane@example.com',
        password: 'secret123',
        displayName: 'Jane Doe',
        age: 25,
      );

      expect(result, tUser);
    });

    test('forwards the optional gender parameter to the repository', () async {
      when(mockRepository.register(
        email: anyNamed('email'),
        password: anyNamed('password'),
        displayName: anyNamed('displayName'),
        age: anyNamed('age'),
        gender: 'female',
      )).thenAnswer((_) async => tUser);

      await useCase(
        email: 'jane@example.com',
        password: 'secret123',
        displayName: 'Jane Doe',
        age: 25,
        gender: 'female',
      );

      verify(mockRepository.register(
        email: anyNamed('email'),
        password: anyNamed('password'),
        displayName: anyNamed('displayName'),
        age: anyNamed('age'),
        gender: 'female',
      )).called(1);
    });

    test('propagates exceptions thrown by the repository', () {
      when(mockRepository.register(
        email: anyNamed('email'),
        password: anyNamed('password'),
        displayName: anyNamed('displayName'),
        age: anyNamed('age'),
        gender: anyNamed('gender'),
      )).thenThrow(Exception('Registration failed'));

      expect(
        () => useCase(
          email: 'bad@example.com',
          password: 'pass',
          displayName: 'Bad',
          age: 21,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('repository.register is called exactly once per useCase call',
        () async {
      when(mockRepository.register(
        email: anyNamed('email'),
        password: anyNamed('password'),
        displayName: anyNamed('displayName'),
        age: anyNamed('age'),
        gender: anyNamed('gender'),
      )).thenAnswer((_) async => tUser);

      await useCase(
        email: 'once@test.com',
        password: 'pass',
        displayName: 'Once',
        age: 20,
      );

      verify(mockRepository.register(
        email: anyNamed('email'),
        password: anyNamed('password'),
        displayName: anyNamed('displayName'),
        age: anyNamed('age'),
        gender: anyNamed('gender'),
      )).called(1);

      verifyNever(mockRepository.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ));
    });
  });
}
