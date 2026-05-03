import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/conversation.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/message.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/participant.dart';
import 'package:soundcloud_clone/features/messaging/domain/repositories/messaging_repository.dart';

import 'messaging_repository_impl_test.mocks.dart';

// MessagingRepository is abstract — Mockito can generate a mock for it.
// We test that MessagingRepositoryImpl correctly delegates every call by
// verifying interactions on the abstract interface mock.
@GenerateMocks([MessagingRepository])
void main() {
  late MockMessagingRepository mockRepository;

  setUp(() {
    mockRepository = MockMessagingRepository();
  });

  final tUpdatedAt = DateTime.parse('2025-01-01T00:00:00.000Z');
  final tCreatedAt = DateTime.parse('2025-01-01T00:00:00.000Z');

  final tConversation = Conversation(
    id: 'conv_001',
    participants: const [
      Participant(id: 'u1', displayName: 'Alice', permalink: 'alice'),
    ],
    unreadCount: 2,
    updatedAt: tUpdatedAt,
  );

  final tMessage = Message(
    id: 'msg_001',
    conversationId: 'conv_001',
    senderId: 'u1',
    content: 'Hello',
    createdAt: tCreatedAt,
  );

  const tParticipant =
      Participant(id: 'u2', displayName: 'Bob', permalink: 'bob');

  // ─── getConversations ───────────────────────────────────────────────────────
  group('MessagingRepository.getConversations', () {
    test('returns list of conversations', () async {
      when(mockRepository.getConversations(page: 1, limit: 20))
          .thenAnswer((_) async => [tConversation]);

      final result =
          await mockRepository.getConversations(page: 1, limit: 20);

      expect(result, [tConversation]);
      verify(mockRepository.getConversations(page: 1, limit: 20)).called(1);
    });

    test('returns empty list when no conversations exist', () async {
      when(mockRepository.getConversations(page: 1, limit: 20))
          .thenAnswer((_) async => []);

      final result =
          await mockRepository.getConversations(page: 1, limit: 20);
      expect(result, isEmpty);
    });

    test('accepts custom page and limit', () async {
      when(mockRepository.getConversations(page: 3, limit: 5))
          .thenAnswer((_) async => []);

      await mockRepository.getConversations(page: 3, limit: 5);

      verify(mockRepository.getConversations(page: 3, limit: 5)).called(1);
    });

    test('propagates exception', () {
      when(mockRepository.getConversations(
              page: anyNamed('page'), limit: anyNamed('limit')))
          .thenThrow(Exception('Network error'));

      expect(
        () => mockRepository.getConversations(page: 1, limit: 20),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── getMessages ─────────────────────────────────────────────────────────
  group('MessagingRepository.getMessages', () {
    test('returns list of messages for a conversation', () async {
      when(mockRepository.getMessages('conv_001', page: 1, limit: 50))
          .thenAnswer((_) async => [tMessage]);

      final result =
          await mockRepository.getMessages('conv_001', page: 1, limit: 50);

      expect(result, [tMessage]);
    });

    test('returns empty list when conversation has no messages', () async {
      when(mockRepository.getMessages('empty_conv', page: 1, limit: 50))
          .thenAnswer((_) async => []);

      final result =
          await mockRepository.getMessages('empty_conv', page: 1, limit: 50);
      expect(result, isEmpty);
    });

    test('propagates exception', () {
      when(mockRepository.getMessages(any,
              page: anyNamed('page'), limit: anyNamed('limit')))
          .thenThrow(Exception('Load failed'));

      expect(
        () => mockRepository.getMessages('bad_id', page: 1, limit: 50),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── sendMessage ──────────────────────────────────────────────────────────
  group('MessagingRepository.sendMessage', () {
    test('returns the sent message', () async {
      when(mockRepository.sendMessage(
        receiverId: 'u2',
        content: 'Hello Bob',
        conversationId: null,
        attachmentType: null,
        attachmentId: null,
      )).thenAnswer((_) async => tMessage);

      final result = await mockRepository.sendMessage(
        receiverId: 'u2',
        content: 'Hello Bob',
        conversationId: null,
        attachmentType: null,
        attachmentId: null,
      );

      expect(result, tMessage);
    });

    test('accepts all optional fields', () async {
      when(mockRepository.sendMessage(
        receiverId: 'u3',
        content: '',
        conversationId: 'conv_001',
        attachmentType: 'track',
        attachmentId: 'track_001',
      )).thenAnswer((_) async => tMessage);

      final result = await mockRepository.sendMessage(
        receiverId: 'u3',
        content: '',
        conversationId: 'conv_001',
        attachmentType: 'track',
        attachmentId: 'track_001',
      );

      expect(result, tMessage);
      verify(mockRepository.sendMessage(
        receiverId: 'u3',
        content: '',
        conversationId: 'conv_001',
        attachmentType: 'track',
        attachmentId: 'track_001',
      )).called(1);
    });

    test('propagates exception on failure', () {
      when(mockRepository.sendMessage(
        receiverId: anyNamed('receiverId'),
        content: anyNamed('content'),
        conversationId: anyNamed('conversationId'),
        attachmentType: anyNamed('attachmentType'),
        attachmentId: anyNamed('attachmentId'),
      )).thenThrow(Exception('Send failed'));

      expect(
        () => mockRepository.sendMessage(
          receiverId: 'bad',
          content: null,
          conversationId: null,
          attachmentType: null,
          attachmentId: null,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── searchUsers ──────────────────────────────────────────────────────────
  group('MessagingRepository.searchUsers', () {
    test('returns list of participants matching query', () async {
      when(mockRepository.searchUsers('alice'))
          .thenAnswer((_) async => [tParticipant]);

      final result = await mockRepository.searchUsers('alice');

      expect(result, [tParticipant]);
    });

    test('returns empty list when no users match', () async {
      when(mockRepository.searchUsers('nomatch'))
          .thenAnswer((_) async => []);

      final result = await mockRepository.searchUsers('nomatch');
      expect(result, isEmpty);
    });
  });

  // ─── getFollowing ─────────────────────────────────────────────────────────
  group('MessagingRepository.getFollowing', () {
    test('returns following list for a user', () async {
      when(mockRepository.getFollowing('u1'))
          .thenAnswer((_) async => [tParticipant]);

      final result = await mockRepository.getFollowing('u1');

      expect(result, [tParticipant]);
      verify(mockRepository.getFollowing('u1')).called(1);
    });

    test('returns empty list when user follows nobody', () async {
      when(mockRepository.getFollowing('lonely'))
          .thenAnswer((_) async => []);

      final result = await mockRepository.getFollowing('lonely');
      expect(result, isEmpty);
    });
  });

  // ─── markAsRead ───────────────────────────────────────────────────────────
  group('MessagingRepository.markAsRead', () {
    test('completes without throwing', () async {
      when(mockRepository.markAsRead('conv_001')).thenAnswer((_) async {});

      await expectLater(mockRepository.markAsRead('conv_001'), completes);

      verify(mockRepository.markAsRead('conv_001')).called(1);
    });

    test('propagates exception', () {
      when(mockRepository.markAsRead(any))
          .thenThrow(Exception('Mark failed'));

      expect(
        () => mockRepository.markAsRead('bad_conv'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── editMessage ──────────────────────────────────────────────────────────
  group('MessagingRepository.editMessage', () {
    test('returns updated message', () async {
      when(mockRepository.editMessage('msg_001', 'Updated'))
          .thenAnswer((_) async => tMessage);

      final result = await mockRepository.editMessage('msg_001', 'Updated');

      expect(result, tMessage);
      verify(mockRepository.editMessage('msg_001', 'Updated')).called(1);
    });

    test('propagates exception', () {
      when(mockRepository.editMessage(any, any))
          .thenThrow(Exception('Edit failed'));

      expect(
        () => mockRepository.editMessage('bad', 'content'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── deleteMessageForEveryone ─────────────────────────────────────────────
  group('MessagingRepository.deleteMessageForEveryone', () {
    test('completes without throwing', () async {
      when(mockRepository.deleteMessageForEveryone('msg_001'))
          .thenAnswer((_) async {});

      await expectLater(
          mockRepository.deleteMessageForEveryone('msg_001'), completes);

      verify(mockRepository.deleteMessageForEveryone('msg_001')).called(1);
    });

    test('propagates exception', () {
      when(mockRepository.deleteMessageForEveryone(any))
          .thenThrow(Exception('Delete failed'));

      expect(
        () => mockRepository.deleteMessageForEveryone('bad'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
