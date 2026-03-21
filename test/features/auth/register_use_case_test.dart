import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';
import 'package:soundcloud_clone/features/auth/domain/repositories/auth_repository.dart';
import 'package:soundcloud_clone/features/auth/domain/usecases/register_use_case.dart';

@GenerateMocks([AuthRepository])
import 'register_use_case_test.mocks.dart';

void main() {
  late RegisterUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = RegisterUseCase(repository: mockRepository);
  });

  group('RegisterUseCase', () {
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

    test('calls repository with correct params', () async {
      when(mockRepository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).thenAnswer((_) async => testUser);

      await useCase.call(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      );

      verify(mockRepository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).called(1);
    });

    test('returns correct User', () async {
      when(mockRepository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).thenAnswer((_) async => testUser);

      final result = await useCase.call(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      );

      expect(result, testUser);
    });

    test('passes gender when provided', () async {
      when(mockRepository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Female',
      )).thenAnswer((_) async => testUser);

      await useCase.call(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Female',
      );

      verify(mockRepository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Female',
      )).called(1);
    });

    test('throws when repository fails', () async {
      when(mockRepository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).thenThrow(Exception('Repository error'));

      expect(
        () => useCase.call(
          email: 'test@example.com',
          password: 'pass',
          displayName: 'Test',
          age: 25,
          gender: 'Male',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('repository called exactly once', () async {
      when(mockRepository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).thenAnswer((_) async => testUser);

      await useCase.call(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      );

      verify(mockRepository.register(
        email: 'test@example.com',
        password: 'pass',
        displayName: 'Test',
        age: 25,
        gender: 'Male',
      )).called(1);
    });
  });
}