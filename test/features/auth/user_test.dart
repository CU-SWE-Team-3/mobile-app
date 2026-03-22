import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';

void main() {
  group('User', () {
    const user = User(
      id: '1',
      permalink: 'test-user',
      displayName: 'Test User',
      location: 'Test City',
      bio: 'Test bio',
      favoriteGenres: ['Rock', 'Pop'],
      socialLinks: {'twitter': 'test', 'instagram': null},
      isPrivate: false,
      role: 'listener',
      isPremium: true,
      isEmailVerified: true,
      accountStatus: 'active',
      avatarUrl: 'avatar.jpg',
      coverPhotoUrl: 'cover.jpg',
      followerCount: 100,
      followingCount: 50,
    );

    test('should create User with correct properties', () {
      expect(user.id, '1');
      expect(user.permalink, 'test-user');
      expect(user.displayName, 'Test User');
      expect(user.location, 'Test City');
      expect(user.bio, 'Test bio');
      expect(user.favoriteGenres, ['Rock', 'Pop']);
      expect(user.socialLinks, {'twitter': 'test', 'instagram': null});
      expect(user.isPrivate, false);
      expect(user.role, 'listener');
      expect(user.isPremium, true);
      expect(user.isEmailVerified, true);
      expect(user.accountStatus, 'active');
      expect(user.avatarUrl, 'avatar.jpg');
      expect(user.coverPhotoUrl, 'cover.jpg');
      expect(user.followerCount, 100);
      expect(user.followingCount, 50);
    });

    test('should handle nullable fields', () {
      const userNullable = User(
        id: '2',
        permalink: 'nullable-user',
        displayName: 'Nullable User',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: true,
        role: 'artist',
        isPremium: false,
        isEmailVerified: false,
        accountStatus: 'inactive',
        followerCount: 0,
        followingCount: 0,
      );

      expect(userNullable.location, null);
      expect(userNullable.bio, null);
      expect(userNullable.avatarUrl, null);
      expect(userNullable.coverPhotoUrl, null);
    });
  });
}