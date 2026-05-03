import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/auth/domain/entities/user.dart';
import 'package:soundcloud_clone/features/profile/domain/entities/profile.dart';

void main() {
  // ── Profile entity ─────────────────────────────────────────────────────────
  group('Profile entity', () {
    test('can be instantiated', () {
      expect(() => Profile(), returnsNormally);
    });

    test('is a valid Dart object', () {
      final profile = Profile();
      expect(profile, isNotNull);
      expect(profile, isA<Profile>());
    });
  });

  // ── User as Module 2 social identity ──────────────────────────────────────
  // The User entity (from Module 1) carries all Module 2 profile fields.
  // These tests verify the profile-specific contract of User.
  group('User — Profile Customization (Module 2)', () {
    const tArtist = User(
      id: 'artist_001',
      permalink: 'dj-karim',
      displayName: 'DJ Karim',
      location: 'Alexandria, Egypt',
      bio: 'Producer & DJ based in Alex.',
      favoriteGenres: ['House', 'Techno', 'Electronic'],
      socialLinks: {
        'instagram': 'https://instagram.com/djkarim',
        'twitter': 'https://twitter.com/djkarim',
        'website': 'https://djkarim.com',
      },
      isPrivate: false,
      role: 'artist',
      isPremium: true,
      isEmailVerified: true,
      accountStatus: 'active',
      avatarUrl: 'https://cdn.example.com/avatar/djkarim.jpg',
      coverPhotoUrl: 'https://cdn.example.com/cover/djkarim.jpg',
      followerCount: 4800,
      followingCount: 120,
    );

    test('stores display name correctly', () {
      expect(tArtist.displayName, 'DJ Karim');
    });

    test('stores location correctly', () {
      expect(tArtist.location, 'Alexandria, Egypt');
    });

    test('stores bio correctly', () {
      expect(tArtist.bio, 'Producer & DJ based in Alex.');
    });

    test('stores favoriteGenres list', () {
      expect(tArtist.favoriteGenres, containsAll(['House', 'Techno', 'Electronic']));
      expect(tArtist.favoriteGenres.length, 3);
    });

    test('stores all social links', () {
      expect(tArtist.socialLinks['instagram'], 'https://instagram.com/djkarim');
      expect(tArtist.socialLinks['twitter'], 'https://twitter.com/djkarim');
      expect(tArtist.socialLinks['website'], 'https://djkarim.com');
    });

    test('social link can be null (platform not connected)', () {
      const user = User(
        id: 'u_partial_links',
        permalink: 'partial',
        displayName: 'Partial Links',
        favoriteGenres: [],
        socialLinks: {'instagram': null, 'twitter': null},
        isPrivate: false,
        role: 'listener',
        isPremium: false,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 0,
        followingCount: 0,
      );
      expect(user.socialLinks['instagram'], isNull);
      expect(user.socialLinks['twitter'], isNull);
    });
  });

  group('User — Account Tiers (Module 2)', () {
    test('artist role is stored as "artist"', () {
      const artist = User(
        id: 'a1',
        permalink: 'artist1',
        displayName: 'Artist One',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'artist',
        isPremium: false,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 0,
        followingCount: 0,
      );
      expect(artist.role, 'artist');
    });

    test('listener role is stored as "listener"', () {
      const listener = User(
        id: 'l1',
        permalink: 'listener1',
        displayName: 'Listener One',
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
      expect(listener.role, 'listener');
    });

    test('artist can be premium', () {
      const premiumArtist = User(
        id: 'pa1',
        permalink: 'pro-artist',
        displayName: 'Pro Artist',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'artist',
        isPremium: true,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 1000,
        followingCount: 50,
      );
      expect(premiumArtist.isPremium, isTrue);
      expect(premiumArtist.role, 'artist');
    });

    test('listener can be premium', () {
      const premiumListener = User(
        id: 'pl1',
        permalink: 'pro-listener',
        displayName: 'Pro Listener',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'listener',
        isPremium: true,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 0,
        followingCount: 200,
      );
      expect(premiumListener.isPremium, isTrue);
    });
  });

  group('User — Visual Assets (Module 2)', () {
    test('avatarUrl is stored when provided', () {
      const u = User(
        id: 'av1',
        permalink: 'avatar',
        displayName: 'Avatar User',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'listener',
        isPremium: false,
        isEmailVerified: true,
        accountStatus: 'active',
        avatarUrl: 'https://cdn.example.com/a.jpg',
        followerCount: 0,
        followingCount: 0,
      );
      expect(u.avatarUrl, 'https://cdn.example.com/a.jpg');
    });

    test('coverPhotoUrl is stored when provided', () {
      const u = User(
        id: 'cv1',
        permalink: 'cover',
        displayName: 'Cover User',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'artist',
        isPremium: false,
        isEmailVerified: true,
        accountStatus: 'active',
        coverPhotoUrl: 'https://cdn.example.com/cover.jpg',
        followerCount: 0,
        followingCount: 0,
      );
      expect(u.coverPhotoUrl, 'https://cdn.example.com/cover.jpg');
    });

    test('avatarUrl is null when not provided', () {
      const u = User(
        id: 'no_av',
        permalink: 'no-avatar',
        displayName: 'No Avatar',
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
      expect(u.avatarUrl, isNull);
    });

    test('coverPhotoUrl is null when not provided', () {
      const u = User(
        id: 'no_cv',
        permalink: 'no-cover',
        displayName: 'No Cover',
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
      expect(u.coverPhotoUrl, isNull);
    });
  });

  group('User — Privacy Control (Module 2)', () {
    test('public profile: isPrivate = false', () {
      const publicUser = User(
        id: 'pub',
        permalink: 'public-user',
        displayName: 'Public User',
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
      expect(publicUser.isPrivate, isFalse);
    });

    test('private profile: isPrivate = true', () {
      const privateUser = User(
        id: 'priv',
        permalink: 'private-user',
        displayName: 'Private User',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: true,
        role: 'listener',
        isPremium: false,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 0,
        followingCount: 0,
      );
      expect(privateUser.isPrivate, isTrue);
    });
  });

  group('User — Permalink (Module 2)', () {
    test('permalink is URL-safe (lowercase, hyphenated)', () {
      const u = User(
        id: 'x1',
        permalink: 'dj-karim-official',
        displayName: 'DJ Karim Official',
        favoriteGenres: [],
        socialLinks: {},
        isPrivate: false,
        role: 'artist',
        isPremium: false,
        isEmailVerified: true,
        accountStatus: 'active',
        followerCount: 0,
        followingCount: 0,
      );
      // Permalink should be lowercase and contain no spaces
      expect(u.permalink, equals(u.permalink.toLowerCase()));
      expect(u.permalink, isNot(contains(' ')));
    });

    test('permalink is stored as provided', () {
      const u = User(
        id: 'x2',
        permalink: 'my-custom-permalink',
        displayName: 'Custom',
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
      expect(u.permalink, 'my-custom-permalink');
    });
  });
}
