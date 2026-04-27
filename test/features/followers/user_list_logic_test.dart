// test/features/followers/user_list_logic_test.dart
//
// Tests for:
//   • SuggestedUsersPage  — self-filtering logic (_fetchSuggested)
//   • FollowingListPage   — followingIds pre-population (_fetchFollowing)
//
// Run with:
//   flutter test test/features/followers/user_list_logic_test.dart

import 'package:flutter_test/flutter_test.dart';

// Mirrors SuggestedUsersPage._fetchSuggested:
//   _users = all.where((u) => u['_id'] != myId).toList();
List<Map<String, dynamic>> filterOutSelf(
  List<Map<String, dynamic>> users,
  String myId,
) =>
    users.where((u) => u['_id'] != myId).toList();

// Mirrors FollowingListPage._fetchFollowing:
//   _followingIds.addAll(users.map((u) => u['_id'] as String));
Set<String> buildFollowingIds(List<Map<String, dynamic>> users) =>
    users.map((u) => u['_id'] as String).toSet();

void main() {
  // ── SUGGESTED USERS — SELF FILTER ────────────────────────────────────────
  group('filterOutSelf — removes current user from suggested list', () {
    final users = [
      {'_id': 'me', 'displayName': 'Me'},
      {'_id': 'user1', 'displayName': 'Alice'},
      {'_id': 'user2', 'displayName': 'Bob'},
    ];

    test('removes the current user from the list', () {
      final result = filterOutSelf(users, 'me');
      expect(result.any((u) => u['_id'] == 'me'), isFalse);
    });

    test('result has correct length after removing self', () {
      final result = filterOutSelf(users, 'me');
      expect(result.length, 2);
    });

    test('result still contains user1', () {
      final result = filterOutSelf(users, 'me');
      expect(result.any((u) => u['_id'] == 'user1'), isTrue);
    });

    test('result still contains user2', () {
      final result = filterOutSelf(users, 'me');
      expect(result.any((u) => u['_id'] == 'user2'), isTrue);
    });

    test('returns all users when myId does not match any user', () {
      final result = filterOutSelf(users, 'stranger');
      expect(result.length, 3);
    });

    test('returns empty list when the only user is self', () {
      final single = [
        {'_id': 'me', 'displayName': 'Me'}
      ];
      expect(filterOutSelf(single, 'me'), isEmpty);
    });

    test('returns empty list when input list is empty', () {
      expect(filterOutSelf([], 'me'), isEmpty);
    });

    test('does not mutate the original list', () {
      final original = List<Map<String, dynamic>>.from(users);
      filterOutSelf(users, 'me');
      expect(users.length, original.length);
    });

    test('handles multiple users with same id as self', () {
      final dupes = [
        {'_id': 'me'},
        {'_id': 'me'},
        {'_id': 'other'},
      ];
      final result = filterOutSelf(dupes, 'me');
      expect(result.length, 1);
      expect(result.first['_id'], 'other');
    });
  });

  // ── FOLLOWING LIST — followingIds INITIALISATION ──────────────────────────
  group('buildFollowingIds — pre-populates followingIds from fetched users', () {
    test('set contains all ids from the fetched list', () {
      final users = [
        {'_id': 'a'},
        {'_id': 'b'},
        {'_id': 'c'},
      ];
      final ids = buildFollowingIds(users);
      expect(ids, containsAll(['a', 'b', 'c']));
    });

    test('set has correct length', () {
      final users = [
        {'_id': 'x'},
        {'_id': 'y'},
      ];
      expect(buildFollowingIds(users).length, 2);
    });

    test('returns empty set for empty user list', () {
      expect(buildFollowingIds([]), isEmpty);
    });

    test('set contains "a"', () {
      final ids = buildFollowingIds([
        {'_id': 'a'},
        {'_id': 'b'},
      ]);
      expect(ids.contains('a'), isTrue);
    });

    test('set contains "b"', () {
      final ids = buildFollowingIds([
        {'_id': 'a'},
        {'_id': 'b'},
      ]);
      expect(ids.contains('b'), isTrue);
    });

    test('duplicate ids are collapsed into a single entry', () {
      final users = [
        {'_id': 'a'},
        {'_id': 'a'},
      ];
      expect(buildFollowingIds(users).length, 1);
    });

    test('set does not contain an id that was not in the list', () {
      final ids = buildFollowingIds([
        {'_id': 'a'},
      ]);
      expect(ids.contains('z'), isFalse);
    });

    test('all users are treated as already-following by definition', () {
      // In FollowingListPage every fetched user is pre-marked as followed.
      final users = [
        {'_id': 'u1'},
        {'_id': 'u2'},
        {'_id': 'u3'},
      ];
      final ids = buildFollowingIds(users);
      for (final u in users) {
        expect(ids.contains(u['_id']), isTrue);
      }
    });
  });
}
