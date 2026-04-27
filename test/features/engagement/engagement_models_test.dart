

import 'package:flutter_test/flutter_test.dart';

import 'package:soundcloud_clone/features/engagement/data/models/comment_model.dart';
import 'package:soundcloud_clone/features/engagement/data/models/liker_user_model.dart';

void main() {
  // ── LikerUser.fromJson ───────────────────────────────────────────────────

  group('LikerUser.fromJson', () {
    test('parses all fields from a full JSON object', () {
      final json = {
        '_id': 'u1',
        'displayName': 'Alice',
        'permalink': 'alice',
        'avatarUrl': 'https://example.com/avatar.png',
        'isFollowing': true,
      };

      final user = LikerUser.fromJson(json);

      expect(user.id, 'u1');
      expect(user.displayName, 'Alice');
      expect(user.permalink, 'alice');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
      expect(user.isFollowing, isTrue);
    });

    test('accepts "id" key as alternative to "_id"', () {
      final json = {
        'id': 'u2',
        'displayName': 'Bob',
        'permalink': 'bob',
      };

      final user = LikerUser.fromJson(json);

      expect(user.id, 'u2');
    });

    test('prefers "id" over "_id" when both keys are present', () {
      // fromJson reads json['id'] ?? json['_id'], so "id" wins
      final json = {
        '_id': 'mongo-id',
        'id': 'other-id',
        'displayName': 'Carol',
        'permalink': 'carol',
      };

      final user = LikerUser.fromJson(json);

      expect(user.id, 'other-id');
    });

    test('defaults isFollowing to false when absent', () {
      final json = {
        '_id': 'u3',
        'displayName': 'Ziad',
        'permalink': 'ziad',
      };

      final user = LikerUser.fromJson(json);

      expect(user.isFollowing, isFalse);
    });

    test('avatarUrl is null when absent', () {
      final json = {
        '_id': 'u4',
        'displayName': 'Kareem',
        'permalink': 'kareem',
      };

      final user = LikerUser.fromJson(json);

      expect(user.avatarUrl, isNull);
    });

    test('handles completely empty JSON with safe defaults', () {
      final user = LikerUser.fromJson({});

      expect(user.id, '');
      expect(user.displayName, '');
      expect(user.permalink, '');
      expect(user.avatarUrl, isNull);
      expect(user.isFollowing, isFalse);
    });
  });

  // ── CommentUserModel.fromJson ────────────────────────────────────────────

  group('CommentUserModel.fromJson', () {
    test('parses all fields', () {
      final json = {
        '_id': 'u10',
        'displayName': 'Ahmed',
        'permalink': 'ahmed',
        'avatarUrl': 'https://example.com/ahmed.jpg',
      };

      final user = CommentUserModel.fromJson(json);

      expect(user.id, 'u10');
      expect(user.displayName, 'Ahmed');
      expect(user.permalink, 'ahmed');
      expect(user.avatarUrl, 'https://example.com/ahmed.jpg');
    });

    test('uses "Unknown" as displayName fallback when absent', () {
      final json = {'_id': 'u11', 'permalink': 'anon'};
      final user = CommentUserModel.fromJson(json);
      expect(user.displayName, 'Unknown');
    });

    test('handles empty JSON without throwing', () {
      final user = CommentUserModel.fromJson({});
      expect(user.id, '');
      expect(user.displayName, 'Unknown');
      expect(user.permalink, '');
    });
  });

  // ── CommentReplyModel.fromJson ───────────────────────────────────────────

  group('CommentReplyModel.fromJson', () {
    test('parses all fields', () {
      final json = {
        '_id': 'r1',
        'content': 'Nice one!',
        'timestamp': 25,
        'user': {
          '_id': 'u5',
          'displayName': 'Khaled',
          'permalink': 'khaled',
        },
        'createdAt': '2024-06-01T12:00:00.000Z',
      };

      final reply = CommentReplyModel.fromJson(json);

      expect(reply.id, 'r1');
      expect(reply.content, 'Nice one!');
      expect(reply.timestamp, 25);
      expect(reply.user.id, 'u5');
      expect(reply.user.displayName, 'Khaled');
      expect(reply.createdAt, DateTime.parse('2024-06-01T12:00:00.000Z'));
    });

    test('timestamp defaults to 0 when absent', () {
      final json = {
        '_id': 'r2',
        'content': 'Reply',
        'user': {'_id': 'u1', 'displayName': 'Alice', 'permalink': 'alice'},
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final reply = CommentReplyModel.fromJson(json);

      expect(reply.timestamp, 0);
    });

    test('falls back to DateTime.now() when createdAt is absent', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final json = {
        '_id': 'r3',
        'content': 'No date',
        'user': {'_id': 'u1', 'displayName': 'A', 'permalink': 'a'},
      };

      final reply = CommentReplyModel.fromJson(json);

      expect(reply.createdAt.isAfter(before), isTrue);
    });
  });

  // ── CommentModel.fromJson ────────────────────────────────────────────────

  group('CommentModel.fromJson', () {
    test('parses a top-level comment with no replies', () {
      final json = {
        '_id': 'c1',
        'content': 'Great track',
        'timestamp': 45,
        'user': {
          '_id': 'u1',
          'displayName': 'Alice',
          'permalink': 'alice',
        },
        'replies': [],
        'createdAt': '2024-03-15T08:30:00.000Z',
      };

      final comment = CommentModel.fromJson(json);

      expect(comment.id, 'c1');
      expect(comment.content, 'Great track');
      expect(comment.timestamp, 45);
      expect(comment.user.id, 'u1');
      expect(comment.user.displayName, 'Alice');
      expect(comment.replies, isEmpty);
      expect(comment.parentCommentId, isNull);
      expect(comment.createdAt, DateTime.parse('2024-03-15T08:30:00.000Z'));
    });

    test('parses nested replies', () {
      final json = {
        '_id': 'c2',
        'content': 'Parent',
        'timestamp': 10,
        'user': {'_id': 'u1', 'displayName': 'Alice', 'permalink': 'alice'},
        'replies': [
          {
            '_id': 'r1',
            'content': 'Reply 1',
            'timestamp': 11,
            'user': {'_id': 'u2', 'displayName': 'Bob', 'permalink': 'bob'},
            'createdAt': '2024-01-01T00:00:00.000Z',
          },
          {
            '_id': 'r2',
            'content': 'Reply 2',
            'timestamp': 12,
            'user': {
              '_id': 'u3',
              'displayName': 'Carol',
              'permalink': 'carol'
            },
            'createdAt': '2024-01-01T00:00:00.000Z',
          },
        ],
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final comment = CommentModel.fromJson(json);

      expect(comment.replies.length, 2);
      expect(comment.replies[0].id, 'r1');
      expect(comment.replies[1].id, 'r2');
      expect(comment.replies[0].user.displayName, 'Bob');
    });

    test('parses parentCommentId when present', () {
      final json = {
        '_id': 'c3',
        'content': 'Child',
        'timestamp': 0,
        'user': {'_id': 'u1', 'displayName': 'A', 'permalink': 'a'},
        'parentComment': 'parent-c1',
        'replies': [],
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final comment = CommentModel.fromJson(json);

      expect(comment.parentCommentId, 'parent-c1');
    });

    test('handles user as a plain string id (legacy shape)', () {
      final json = {
        '_id': 'c4',
        'content': 'Legacy',
        'timestamp': 5,
        'user': 'u99', // legacy: user is just an id string
        'replies': [],
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final comment = CommentModel.fromJson(json);

      expect(comment.user.id, 'u99');
      expect(comment.user.displayName, 'Unknown');
    });

    test('timestamp defaults to 0 when absent', () {
      final json = {
        '_id': 'c5',
        'content': 'No ts',
        'user': {'_id': 'u1', 'displayName': 'A', 'permalink': 'a'},
        'replies': [],
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final comment = CommentModel.fromJson(json);

      expect(comment.timestamp, 0);
    });

    test('replies list defaults to empty when absent', () {
      final json = {
        '_id': 'c6',
        'content': 'No replies key',
        'timestamp': 0,
        'user': {'_id': 'u1', 'displayName': 'A', 'permalink': 'a'},
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final comment = CommentModel.fromJson(json);

      expect(comment.replies, isEmpty);
    });
  });
}
