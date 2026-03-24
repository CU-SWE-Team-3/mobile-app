import '../../domain/entities/user.dart';

class AuthMockDatasource {
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required int age,
    String? gender,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return User(
      id: 'mock_001',
      permalink: displayName.toLowerCase().replaceAll(' ', '-'),
      displayName: displayName,
      location: 'Cairo, Egypt',
      bio: 'This is a mock user bio.',
      favoriteGenres: ['Hip Hop', 'Electronic'],
      socialLinks: {'instagram': null, 'twitter': null, 'website': null},
      isPrivate: false,
      role: 'listener',
      isPremium: false,
      isEmailVerified: false,
      accountStatus: 'active',
      avatarUrl: null,
      coverPhotoUrl: null,
      followerCount: 0,
      followingCount: 0,
    );
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return const User(
      id: 'mock_001',
      permalink: 'mock-user',
      displayName: 'Mock User',
      location: 'Cairo, Egypt',
      bio: 'This is a mock user.',
      favoriteGenres: ['Hip Hop'],
      socialLinks: {'instagram': null, 'twitter': null, 'website': null},
      isPrivate: false,
      role: 'listener',
      isPremium: false,
      isEmailVerified: true,
      accountStatus: 'active',
      avatarUrl: null,
      coverPhotoUrl: null,
      followerCount: 0,
      followingCount: 0,
    );
  }

  Future<void> verifyEmail({required String token}) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> forgotPassword({required String email}) async {
    await Future.delayed(const Duration(seconds: 1));
  }
}