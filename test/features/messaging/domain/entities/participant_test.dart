import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/participant.dart';

void main() {
  // ── Direct construction ─────────────────────────────────────────────────────
  group('Participant — construction', () {
    test('stores all required fields', () {
      const p = Participant(
        id: 'p_001',
        displayName: 'Alice',
        permalink: 'alice',
      );
      expect(p.id, 'p_001');
      expect(p.displayName, 'Alice');
      expect(p.permalink, 'alice');
    });

    test('avatarUrl defaults to null when omitted', () {
      const p =
          Participant(id: 'p_001', displayName: 'Alice', permalink: 'alice');
      expect(p.avatarUrl, isNull);
    });

    test('stores avatarUrl when provided', () {
      const p = Participant(
        id: 'p_002',
        displayName: 'Bob',
        permalink: 'bob',
        avatarUrl: 'https://cdn.example.com/bob.jpg',
      );
      expect(p.avatarUrl, 'https://cdn.example.com/bob.jpg');
    });
  });

  // ── fromJson ────────────────────────────────────────────────────────────────
  group('Participant.fromJson', () {
    test('parses standard _id field', () {
      final p = Participant.fromJson({
        '_id': 'user_abc',
        'displayName': 'Charlie',
        'permalink': 'charlie',
      });
      expect(p.id, 'user_abc');
    });

    test('falls back to id field when _id is absent', () {
      final p = Participant.fromJson({
        'id': 'user_xyz',
        'displayName': 'Dave',
        'permalink': 'dave',
      });
      expect(p.id, 'user_xyz');
    });

    test('parses displayName correctly', () {
      final p = Participant.fromJson({
        '_id': 'u1',
        'displayName': 'Eve',
        'permalink': 'eve',
      });
      expect(p.displayName, 'Eve');
    });

    test('falls back to name when displayName is absent', () {
      final p = Participant.fromJson({
        '_id': 'u2',
        'name': 'Frank',
        'permalink': 'frank',
      });
      expect(p.displayName, 'Frank');
    });

    test('falls back to username when displayName and name are absent', () {
      final p = Participant.fromJson({
        '_id': 'u3',
        'username': 'grace123',
        'permalink': 'grace',
      });
      expect(p.displayName, 'grace123');
    });

    test('uses "Unknown user" when all name fields are absent and id is set',
        () {
      final p = Participant.fromJson({
        '_id': 'u4',
        'permalink': 'unknown',
      });
      expect(p.displayName, 'Unknown user');
    });

    test('displayName is empty string when id is empty and name fields absent',
        () {
      final p = Participant.fromJson({'permalink': 'x'});
      // id is empty => displayName falls through to empty
      expect(p.id, '');
      expect(p.displayName, '');
    });

    test('parses permalink correctly', () {
      final p = Participant.fromJson({
        '_id': 'u5',
        'displayName': 'Hank',
        'permalink': 'hank-music',
      });
      expect(p.permalink, 'hank-music');
    });

    test('permalink is empty string when absent', () {
      final p =
          Participant.fromJson({'_id': 'u6', 'displayName': 'Ivy'});
      expect(p.permalink, '');
    });

    test('parses avatarUrl correctly', () {
      final p = Participant.fromJson({
        '_id': 'u7',
        'displayName': 'Jack',
        'permalink': 'jack',
        'avatarUrl': 'https://cdn.com/jack.png',
      });
      expect(p.avatarUrl, 'https://cdn.com/jack.png');
    });

    test('falls back to avatar key for avatar url', () {
      final p = Participant.fromJson({
        '_id': 'u8',
        'displayName': 'Kate',
        'permalink': 'kate',
        'avatar': 'https://cdn.com/kate.png',
      });
      expect(p.avatarUrl, 'https://cdn.com/kate.png');
    });

    test('avatarUrl is null when both avatarUrl and avatar are absent', () {
      final p = Participant.fromJson({
        '_id': 'u9',
        'displayName': 'Leo',
        'permalink': 'leo',
      });
      expect(p.avatarUrl, isNull);
    });
  });
}
