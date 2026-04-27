// test/features/followers/follow_state_test.dart
//
// Tests for follow-toggle and in-flight loading state logic
// shared across followers_list_page, following_list_page,
// and suggested_users_page.
//
// Run with:
//   flutter test test/features/followers/follow_state_test.dart

import 'package:flutter_test/flutter_test.dart';

// Mirrors the _toggleFollow Set mutation in all three pages.
// Returns a new set — does NOT mutate the original.
Set<String> toggleFollow(Set<String> followingIds, String userId) {
  final updated = Set<String>.from(followingIds);
  if (updated.contains(userId)) {
    updated.remove(userId);
  } else {
    updated.add(userId);
  }
  return updated;
}

// Mirrors the `if (_loadingIds.contains(userId)) return;` guard.
bool isAlreadyLoading(Set<String> loadingIds, String userId) =>
    loadingIds.contains(userId);

void main() {
  group('toggleFollow — following a new user', () {
    test('adds userId when not yet following', () {
      final result = toggleFollow({}, 'user1');
      expect(result.contains('user1'), isTrue);
    });

    test('set size increases by 1 when following new user', () {
      final before = <String>{'user2'};
      final result = toggleFollow(before, 'user1');
      expect(result.length, before.length + 1);
    });

    test('does not affect other followed users when adding', () {
      final result = toggleFollow({'user2'}, 'user1');
      expect(result.contains('user2'), isTrue);
    });

    test('works correctly on an empty set', () {
      final result = toggleFollow({}, 'user1');
      expect(result, {'user1'});
    });
  });

  group('toggleFollow — unfollowing an existing user', () {
    test('removes userId when already following', () {
      final result = toggleFollow({'user1'}, 'user1');
      expect(result.contains('user1'), isFalse);
    });

    test('set size decreases by 1 when unfollowing', () {
      final before = <String>{'user1', 'user2'};
      final result = toggleFollow(before, 'user1');
      expect(result.length, before.length - 1);
    });

    test('does not affect other followed users when removing', () {
      final result = toggleFollow({'user1', 'user2'}, 'user1');
      expect(result.contains('user2'), isTrue);
    });

    test('set is empty after removing the only element', () {
      final result = toggleFollow({'user1'}, 'user1');
      expect(result, isEmpty);
    });
  });

  group('toggleFollow — immutability', () {
    test('does not mutate the original set when adding', () {
      final original = <String>{'user2'};
      toggleFollow(original, 'user1');
      expect(original.contains('user1'), isFalse);
    });

    test('does not mutate the original set when removing', () {
      final original = <String>{'user1'};
      toggleFollow(original, 'user1');
      expect(original.contains('user1'), isTrue);
    });

    test('toggling the same user twice returns to original state', () {
      final start = <String>{'user1'};
      final after = toggleFollow(toggleFollow(start, 'user1'), 'user1');
      expect(after, equals(start));
    });
  });

  group('isAlreadyLoading — in-flight guard', () {
    test('returns true when userId is in loadingIds', () {
      expect(isAlreadyLoading({'user1', 'user2'}, 'user1'), isTrue);
    });

    test('returns false when userId is not in loadingIds', () {
      expect(isAlreadyLoading({'user2'}, 'user1'), isFalse);
    });

    test('returns false when loadingIds is empty', () {
      expect(isAlreadyLoading({}, 'user1'), isFalse);
    });

    test('correctly identifies second user as loading', () {
      expect(isAlreadyLoading({'user1', 'user2'}, 'user2'), isTrue);
    });

    test('returns false after userId is removed from loadingIds', () {
      final ids = <String>{'user1'};
      ids.remove('user1');
      expect(isAlreadyLoading(ids, 'user1'), isFalse);
    });

    test('adding to loadingIds makes isAlreadyLoading return true', () {
      final ids = <String>{};
      ids.add('user1');
      expect(isAlreadyLoading(ids, 'user1'), isTrue);
    });
  });
}
