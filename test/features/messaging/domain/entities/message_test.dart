import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/attachment.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/message.dart';

void main() {
  // ── Shared fixture ──────────────────────────────────────────────────────────
  final tCreatedAt = DateTime.parse('2025-01-15T10:30:00.000Z');

  final tMessage = Message(
    id: 'msg_001',
    conversationId: 'conv_abc',
    senderId: 'user_001',
    senderDisplayName: 'Alice',
    senderAvatarUrl: 'https://cdn.example.com/alice.jpg',
    content: 'Hello World!',
    status: 'delivered',
    isEdited: false,
    isDeleted: false,
    createdAt: tCreatedAt,
  );

  // ── Construction ────────────────────────────────────────────────────────────
  group('Message — construction', () {
    test('stores all required fields', () {
      expect(tMessage.id, 'msg_001');
      expect(tMessage.conversationId, 'conv_abc');
      expect(tMessage.senderId, 'user_001');
      expect(tMessage.content, 'Hello World!');
      expect(tMessage.createdAt, tCreatedAt);
    });

    test('optional fields default correctly', () {
      final minimal = Message(
        id: 'msg_min',
        conversationId: 'conv_min',
        senderId: 'user_min',
        content: 'Hi',
        createdAt: tCreatedAt,
      );
      expect(minimal.senderDisplayName, isNull);
      expect(minimal.senderAvatarUrl, isNull);
      expect(minimal.attachment, isNull);
      expect(minimal.status, isNull);
      expect(minimal.isEdited, isFalse);
      expect(minimal.isDeleted, isFalse);
    });

    test('stores attachment when provided', () {
      const att = Attachment(type: 'track', referenceId: 'track_001');
      final msg = Message(
        id: 'msg_with_att',
        conversationId: 'conv_1',
        senderId: 'user_1',
        content: '',
        attachment: att,
        createdAt: tCreatedAt,
      );
      expect(msg.attachment, isNotNull);
      expect(msg.attachment!.type, 'track');
    });
  });

  // ── copyWith ────────────────────────────────────────────────────────────────
  group('Message.copyWith', () {
    test('copyWith with no args preserves all fields', () {
      final copy = tMessage.copyWith();
      expect(copy.id, tMessage.id);
      expect(copy.content, tMessage.content);
      expect(copy.status, tMessage.status);
      expect(copy.isEdited, tMessage.isEdited);
      expect(copy.isDeleted, tMessage.isDeleted);
    });

    test('copyWith updates status', () {
      final updated = tMessage.copyWith(status: 'read');
      expect(updated.status, 'read');
      expect(updated.id, tMessage.id);
    });

    test('copyWith updates content', () {
      final edited = tMessage.copyWith(content: 'Edited content', isEdited: true);
      expect(edited.content, 'Edited content');
      expect(edited.isEdited, isTrue);
    });

    test('copyWith marks message as deleted', () {
      final deleted = tMessage.copyWith(isDeleted: true);
      expect(deleted.isDeleted, isTrue);
      expect(deleted.id, tMessage.id);
    });

    test('copyWith does not change immutable id', () {
      final copy = tMessage.copyWith(content: 'new content');
      expect(copy.id, 'msg_001');
    });

    test('copyWith creates a new instance', () {
      final copy = tMessage.copyWith(status: 'read');
      expect(identical(tMessage, copy), isFalse);
    });
  });

  // ── fromJson ────────────────────────────────────────────────────────────────
  group('Message.fromJson', () {
    test('parses basic fields from JSON', () {
      final json = {
        '_id': 'msg_json_001',
        'conversationId': 'conv_json',
        'senderId': 'sender_001',
        'content': 'Test content',
        'createdAt': '2025-01-15T10:30:00.000Z',
      };
      final msg = Message.fromJson(json);

      expect(msg.id, 'msg_json_001');
      expect(msg.conversationId, 'conv_json');
      expect(msg.senderId, 'sender_001');
      expect(msg.content, 'Test content');
    });

    test('parses isEdited = false by default', () {
      final json = {
        '_id': 'msg_002',
        'conversationId': 'c1',
        'senderId': 's1',
        'content': 'x',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.isEdited, isFalse);
    });

    test('parses isEdited = true when present', () {
      final json = {
        '_id': 'msg_003',
        'conversationId': 'c1',
        'senderId': 's1',
        'content': 'edited',
        'isEdited': true,
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.isEdited, isTrue);
    });

    test('parses isDeleted = true when present', () {
      final json = {
        '_id': 'msg_004',
        'conversationId': 'c1',
        'senderId': 's1',
        'content': '',
        'isDeleted': true,
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.isDeleted, isTrue);
    });

    test('parses status field', () {
      final json = {
        '_id': 'msg_005',
        'conversationId': 'c1',
        'senderId': 's1',
        'content': 'hi',
        'status': 'read',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.status, 'read');
    });

    test('attachment is null when not present in JSON', () {
      final json = {
        '_id': 'msg_006',
        'conversationId': 'c1',
        'senderId': 's1',
        'content': 'no attachment',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.attachment, isNull);
    });

    test('attachment is parsed when present in JSON', () {
      final json = {
        '_id': 'msg_007',
        'conversationId': 'c1',
        'senderId': 's1',
        'content': '',
        'attachment': {'type': 'track', 'referenceId': 'track_001'},
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.attachment, isNotNull);
      expect(msg.attachment!.type, 'track');
    });

    test('parses senderId from embedded senderId map', () {
      final json = {
        '_id': 'msg_008',
        'conversationId': 'c1',
        'senderId': {'_id': 'nested_sender', 'displayName': 'Sender Name'},
        'content': 'hello',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.senderId, 'nested_sender');
      expect(msg.senderDisplayName, 'Sender Name');
    });

    test('parses sender from "sender" key as fallback', () {
      final json = {
        '_id': 'msg_009',
        'conversationId': 'c1',
        'senderId': 'direct_sender_id',
        'sender': {'_id': 'sender_obj', 'displayName': 'From Sender Key'},
        'content': 'hello',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      // When senderId is a plain string, sender map is checked
      expect(msg.senderDisplayName, 'From Sender Key');
    });

    test('parses createdAt datetime correctly', () {
      final json = {
        '_id': 'msg_010',
        'conversationId': 'c1',
        'senderId': 's1',
        'content': 'time check',
        'createdAt': '2025-06-15T14:22:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.createdAt.year, 2025);
      expect(msg.createdAt.month, 6);
      expect(msg.createdAt.day, 15);
    });

    test('conversationId extracted from nested map structure', () {
      final json = {
        '_id': 'msg_011',
        'conversation': {'_id': 'nested_conv', 'name': 'test'},
        'senderId': 's1',
        'content': 'nested conv',
        'createdAt': '2025-01-01T00:00:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.conversationId, 'nested_conv');
    });
  });
}
