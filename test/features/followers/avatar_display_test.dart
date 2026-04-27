// test/features/followers/avatar_display_test.dart
//
// Tests for avatar detection and initial-letter derivation logic
// used in _FollowerTile, _UserTile, and SuggestedUsersPage.
//
// Run with:
//   flutter test test/features/followers/avatar_display_test.dart

import 'package:flutter_test/flutter_test.dart';

// Mirrors the `isDefaultAvatar` check in all three page files.
bool isDefaultAvatar(String? avatarUrl) =>
    avatarUrl == null ||
    avatarUrl.isEmpty ||
    avatarUrl.contains('default-avatar');

// Mirrors the `initial` derivation used in all three page files.
String getInitial(String? displayName) {
  final name = displayName ?? '';
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

void main() {
  group('isDefaultAvatar — should use placeholder', () {
    test('returns true when avatarUrl is null', () {
      expect(isDefaultAvatar(null), isTrue);
    });

    test('returns true when avatarUrl is empty string', () {
      expect(isDefaultAvatar(''), isTrue);
    });

    test('returns true when avatarUrl contains "default-avatar"', () {
      expect(
        isDefaultAvatar('https://cdn.example.com/default-avatar.png'),
        isTrue,
      );
    });

    test('returns true when avatarUrl is exactly "default-avatar"', () {
      expect(isDefaultAvatar('default-avatar'), isTrue);
    });

    test('returns true when "default-avatar" appears mid-path', () {
      expect(
        isDefaultAvatar('https://cdn.example.com/imgs/default-avatar/v2.jpg'),
        isTrue,
      );
    });
  });

  group('isDefaultAvatar — should use real image', () {
    test('returns false when avatarUrl is a real image URL', () {
      expect(
        isDefaultAvatar('https://cdn.example.com/alice.jpg'),
        isFalse,
      );
    });

    test('returns false for URL without default-avatar keyword', () {
      expect(isDefaultAvatar('https://example.com/photo.png'), isFalse);
    });

    test('returns false for URL with unrelated avatar path', () {
      expect(
        isDefaultAvatar('https://cdn.example.com/avatars/custom.jpg'),
        isFalse,
      );
    });
  });

  group('getInitial — normal names', () {
    test('returns uppercase first letter for lowercase name', () {
      expect(getInitial('alice'), 'A');
    });

    test('returns already-uppercase letter unchanged', () {
      expect(getInitial('Bob'), 'B');
    });

    test('returns uppercase of single lowercase character', () {
      expect(getInitial('z'), 'Z');
    });

    test('returns first character only for multi-word name', () {
      expect(getInitial('John Doe'), 'J');
    });

    test('returns first character for name with numbers', () {
      expect(getInitial('4ever'), '4');
    });
  });

  group('getInitial — empty / null names', () {
    test('returns "?" when displayName is empty string', () {
      expect(getInitial(''), '?');
    });

    test('returns "?" when displayName is null', () {
      expect(getInitial(null), '?');
    });
  });

  group('getInitial — whitespace edge case', () {
    test('returns space char for whitespace-only string (no trim applied)', () {
      // The page logic does not trim — mirrors raw behaviour.
      expect(getInitial(' '), ' ');
    });
  });
}
