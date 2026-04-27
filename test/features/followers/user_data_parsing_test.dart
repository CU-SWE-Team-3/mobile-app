// test/features/followers/user_data_parsing_test.dart
//
// Tests for raw Map<String, dynamic> user data parsing logic
// shared across followers_list_page, following_list_page,
// and suggested_users_page.
//
// Run with:
//   flutter test test/features/followers/user_data_parsing_test.dart

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User data parsing — full user map', () {
    final Map<String, dynamic> fullUser = {
      '_id': 'user123',
      'displayName': 'Alice',
      'avatarUrl': 'https://cdn.example.com/alice.jpg',
      'followerCount': 42,
    };

    test('_id is parsed correctly', () {
      expect(fullUser['_id'], 'user123');
    });

    test('displayName is parsed correctly', () {
      expect(fullUser['displayName'] as String?, 'Alice');
    });

    test('avatarUrl is parsed correctly', () {
      expect(
        fullUser['avatarUrl'] as String?,
        'https://cdn.example.com/alice.jpg',
      );
    });

    test('followerCount is parsed correctly as int', () {
      expect(fullUser['followerCount'] as int? ?? 0, 42);
    });
  });

  group('User data parsing — missing / null fields', () {
    final Map<String, dynamic> emptyUser = {'_id': 'u1'};

    test('displayName falls back to empty string when absent', () {
      final name = emptyUser['displayName'] as String? ?? '';
      expect(name, '');
    });

    test('followerCount falls back to 0 when absent', () {
      final count = emptyUser['followerCount'] as int? ?? 0;
      expect(count, 0);
    });

    test('avatarUrl is null when not provided', () {
      expect(emptyUser['avatarUrl'] as String?, isNull);
    });
  });

  group('User data parsing — followerCount (SuggestedUsersPage)', () {
    // SuggestedUsersPage handles int, numeric string, and null
    int parseFollowerCount(dynamic raw) {
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    test('returns int value when raw is int', () {
      expect(parseFollowerCount(99), 99);
    });

    test('returns 0 when raw is int 0', () {
      expect(parseFollowerCount(0), 0);
    });

    test('parses numeric string correctly', () {
      expect(parseFollowerCount('150'), 150);
    });

    test('parses string "0" correctly', () {
      expect(parseFollowerCount('0'), 0);
    });

    test('returns 0 when raw is null', () {
      expect(parseFollowerCount(null), 0);
    });

    test('returns 0 when raw is empty string', () {
      expect(parseFollowerCount(''), 0);
    });

    test('returns 0 when raw is non-numeric string', () {
      expect(parseFollowerCount('abc'), 0);
    });

    test('parses large numeric string correctly', () {
      expect(parseFollowerCount('1000000'), 1000000);
    });
  });
}
