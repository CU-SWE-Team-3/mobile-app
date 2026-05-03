import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/conversation.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/message.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/participant.dart';

void main() {
  final tUpdatedAt = DateTime.parse('2025-03-10T09:00:00.000Z');
  final tCreatedAt = DateTime.parse('2025-03-10T08:55:00.000Z');

  const tParticipants = [
    Participant(id: 'u1', displayName: 'Alice', permalink: 'alice'),
    Participant(id: 'u2', displayName: 'Bob', permalink: 'bob'),
  ];

  final tLastMessage = Message(
    id: 'msg_last',
    conversationId: 'conv_001',
    senderId: 'u1',
    content: 'See you there!',
    createdAt: tCreatedAt,
  );

  // ── Construction ────────────────────────────────────────────────────────────
  group('Conversation — construction', () {
    test('stores all required fields', () {
      final c = Conversation(
        id: 'conv_001',
        participants: tParticipants,
        lastMessage: tLastMessage,
        unreadCount: 3,
        updatedAt: tUpdatedAt,
      );
      expect(c.id, 'conv_001');
      expect(c.participants, tParticipants);
      expect(c.lastMessage, tLastMessage);
      expect(c.unreadCount, 3);
      expect(c.updatedAt, tUpdatedAt);
    });

    test('unreadCount defaults to 0', () {
      final c = Conversation(
        id: 'conv_002',
        participants: tParticipants,
        updatedAt: tUpdatedAt,
      );
      expect(c.unreadCount, 0);
    });

    test('lastMessage defaults to null', () {
      final c = Conversation(
        id: 'conv_003',
        participants: tParticipants,
        updatedAt: tUpdatedAt,
      );
      expect(c.lastMessage, isNull);
    });
  });

  // ── fromJson ─────────────────────────────────────────────────────────────────
  group('Conversation.fromJson — basic', () {
    test('parses _id field', () {
      final c = Conversation.fromJson({
        '_id': 'conv_json_001',
        'participants': [],
        'updatedAt': '2025-03-10T09:00:00.000Z',
      });
      expect(c.id, 'conv_json_001');
    });

    test('falls back to id when _id is absent', () {
      final c = Conversation.fromJson({
        'id': 'conv_json_002',
        'participants': [],
        'updatedAt': '2025-03-10T09:00:00.000Z',
      });
      expect(c.id, 'conv_json_002');
    });

    test('parses updatedAt correctly', () {
      final c = Conversation.fromJson({
        '_id': 'c1',
        'participants': [],
        'updatedAt': '2025-03-10T09:00:00.000Z',
      });
      expect(c.updatedAt.year, 2025);
      expect(c.updatedAt.month, 3);
      expect(c.updatedAt.day, 10);
    });

    test('falls back to lastMessageAt when updatedAt is absent', () {
      final c = Conversation.fromJson({
        '_id': 'c2',
        'participants': [],
        'lastMessageAt': '2025-04-01T12:00:00.000Z',
      });
      expect(c.updatedAt.month, 4);
      expect(c.updatedAt.day, 1);
    });

    test('falls back to createdAt when updatedAt and lastMessageAt absent', () {
      final c = Conversation.fromJson({
        '_id': 'c3',
        'participants': [],
        'createdAt': '2025-05-05T00:00:00.000Z',
      });
      expect(c.updatedAt.month, 5);
      expect(c.updatedAt.day, 5);
    });

    test('updatedAt is epoch when all date fields absent', () {
      final c = Conversation.fromJson({
        '_id': 'c4',
        'participants': [],
      });
      expect(c.updatedAt.millisecondsSinceEpoch, 0);
    });

    test('parses unreadCount correctly', () {
      final c = Conversation.fromJson({
        '_id': 'c5',
        'participants': [],
        'unreadCount': 7,
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.unreadCount, 7);
    });

    test('unreadCount defaults to 0 when absent', () {
      final c = Conversation.fromJson({
        '_id': 'c6',
        'participants': [],
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.unreadCount, 0);
    });

    test('parses lastMessage from "lastMessage" key', () {
      final c = Conversation.fromJson({
        '_id': 'c7',
        'participants': [],
        'updatedAt': '2025-01-01T00:00:00.000Z',
        'lastMessage': {
          '_id': 'msg_last',
          'conversationId': 'c7',
          'senderId': 'u1',
          'content': 'Hi there',
          'createdAt': '2025-01-01T00:00:00.000Z',
        },
      });
      expect(c.lastMessage, isNotNull);
      expect(c.lastMessage!.content, 'Hi there');
    });

    test('parses lastMessage from "latestMessage" fallback key', () {
      final c = Conversation.fromJson({
        '_id': 'c8',
        'participants': [],
        'updatedAt': '2025-01-01T00:00:00.000Z',
        'latestMessage': {
          '_id': 'msg_latest',
          'conversationId': 'c8',
          'senderId': 'u2',
          'content': 'Latest message',
          'createdAt': '2025-01-01T00:00:00.000Z',
        },
      });
      expect(c.lastMessage!.content, 'Latest message');
    });

    test('lastMessage is null when neither key is present', () {
      final c = Conversation.fromJson({
        '_id': 'c9',
        'participants': [],
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.lastMessage, isNull);
    });
  });

  // ── Participant parsing ───────────────────────────────────────────────────
  group('Conversation.fromJson — participants', () {
    test('parses participants as Participant objects', () {
      final c = Conversation.fromJson({
        '_id': 'cp1',
        'participants': [
          {'_id': 'u1', 'displayName': 'Alice', 'permalink': 'alice'},
          {'_id': 'u2', 'displayName': 'Bob', 'permalink': 'bob'},
        ],
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.participants.length, 2);
      expect(c.participants[0].displayName, 'Alice');
      expect(c.participants[1].displayName, 'Bob');
    });

    test('handles participants as plain id strings', () {
      final c = Conversation.fromJson({
        '_id': 'cp2',
        'participants': ['id_only_user'],
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.participants.length, 1);
      expect(c.participants[0].id, 'id_only_user');
    });

    test('filters out participants with empty id', () {
      final c = Conversation.fromJson({
        '_id': 'cp3',
        'participants': [
          {'_id': '', 'displayName': 'Empty ID'},
          {'_id': 'valid_user', 'displayName': 'Valid'},
        ],
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.participants.length, 1);
      expect(c.participants[0].id, 'valid_user');
    });

    test('parses participant from nested user map', () {
      final c = Conversation.fromJson({
        '_id': 'cp4',
        'participants': [
          {
            'user': {'_id': 'nested_user', 'displayName': 'Nested', 'permalink': 'nested'},
          },
        ],
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.participants[0].id, 'nested_user');
      expect(c.participants[0].displayName, 'Nested');
    });

    test('empty participants list is valid', () {
      final c = Conversation.fromJson({
        '_id': 'cp5',
        'participants': [],
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.participants, isEmpty);
    });

    test('participants defaults to empty when key is absent', () {
      final c = Conversation.fromJson({
        '_id': 'cp6',
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(c.participants, isEmpty);
    });
  });
}
