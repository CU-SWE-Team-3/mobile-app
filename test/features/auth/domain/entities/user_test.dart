import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';

void main() {
  // ── Shared fixture ─────────────────────────────────────────────────────────
  const tUser = User(
    id: 'user_001',
    permalink: 'john-doe',
    displayName: 'John Doe',
    location: 'Cairo, Egypt',
    bio: 'A test user bio.',
    favoriteGenres: ['Hip Hop', 'Electronic'],
    socialLinks: {
      'instagram': 'https://instagram.com/johndoe',
      'twitter': null,
      'website': null,
    },
    isPrivate: false,
    role: 'listener',
    isPremium: false,
    isEmailVerified: true,
    accountStatus: 'active',
    avatarUrl: 'https://example.com/avatar.jpg',
    coverPhotoUrl: null,
    followerCount: 42,
    followingCount: 10,
  );

  group('User entity — construction', () {
    test('stores all required fields correctly', () {
      expect(tUser.id, 'user_001');
      expect(tUser.permalink, 'john-doe');
      expect(tUser.displayName, 'John Doe');
      expect(tUser.role, 'listener');
      expect(tUser.accountStatus, 'active');
      expect(tUser.followerCount, 42);
      expect(tUser.followingCount, 10);
    });

    test('stores optional fields when provided', () {
      expect(tUser.location, 'Cairo, Egypt');
      expect(tUser.bio, 'A test user bio.');
      expect(tUser.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('optional fields default to null when omitted', () {
      const minimalUser = User(
        id: 'u2',
        permalink: 'minimal',
        displayName: 'Minimal',
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

      expect(minimalUser.location, isNull);
      expect(minimalUser.bio, isNull);
      expect(minimalUser.avatarUrl, isNull);
      expect(minimalUser.coverPhotoUrl, isNull);
    });

    test('favoriteGenres list is stored as provided', () {
      expect(tUser.favoriteGenres, ['Hip Hop', 'Electronic']);
    });

    test('empty favoriteGenres list is valid', () {
      const u = User(
        id: 'x',
        permalink: 'x',
        displayName: 'X',
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
      expect(u.favoriteGenres, isEmpty);
    });

    test('socialLinks map is stored correctly', () {
      expect(tUser.socialLinks['instagram'],
          'https://instagram.com/johndoe');
      expect(tUser.socialLinks['twitter'], isNull);
    });
  });

  group('User entity — boolean flags', () {
    test('isPrivate is false for a public user', () {
      expect(tUser.isPrivate, isFalse);
    });

    test('isPrivate is true for a private user', () {
      const privateUser = User(
        id: 'p1',
        permalink: 'private',
        displayName: 'Private',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: true,
        role: 'listener',
        isPremium: false,
        isEmailVerified: false,
        accountStatus: 'active',
        followerCount: 0,
        followingCount: 0,
      );
      expect(privateUser.isPrivate, isTrue);
    });

    test('isPremium is false for a free user', () {
      expect(tUser.isPremium, isFalse);
    });

    test('isPremium is true for a premium user', () {
      const premiumUser = User(
        id: 'p2',
        permalink: 'pro',
        displayName: 'Pro',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'artist',
        isPremium: true,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 0,
        followingCount: 0,
      );
      expect(premiumUser.isPremium, isTrue);
    });

    test('isEmailVerified reflects provided value', () {
      expect(tUser.isEmailVerified, isTrue);

      const unverified = User(
        id: 'u3',
        permalink: 'unverified',
        displayName: 'Unverified',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'listener',
        isPremium: false,
        isEmailVerified: false,
        accountStatus: 'pending',
        followerCount: 0,
        followingCount: 0,
      );
      expect(unverified.isEmailVerified, isFalse);
    });
  });

  group('User entity — role', () {
    test('artist role is stored correctly', () {
      const artist = User(
        id: 'a1',
        permalink: 'artist',
        displayName: 'Artist',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'artist',
        isPremium: false,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 100,
        followingCount: 5,
      );
      expect(artist.role, 'artist');
    });

    test('listener role is stored correctly', () {
      expect(tUser.role, 'listener');
    });
  });

  group('User entity — follower/following counts', () {
    test('followerCount is zero for a new user', () {
      const newUser = User(
        id: 'new',
        permalink: 'newbie',
        displayName: 'Newbie',
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
      expect(newUser.followerCount, 0);
      expect(newUser.followingCount, 0);
    });

    test('large follower counts are stored without overflow', () {
      const famous = User(
        id: 'famous',
        permalink: 'famous',
        displayName: 'Famous',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'artist',
        isPremium: true,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 1000000,
        followingCount: 500,
      );
      expect(famous.followerCount, 1000000);
    });
  });
}
