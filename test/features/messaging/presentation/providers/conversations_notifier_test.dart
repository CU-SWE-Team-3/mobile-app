import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:soundcloud_clone/core/providers/session_provider.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/conversation.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/message.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/participant.dart';
import 'package:soundcloud_clone/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:soundcloud_clone/features/messaging/presentation/providers/messaging_providers.dart';

import 'conversations_notifier_test.mocks.dart';

@GenerateMocks([MessagingRepository])
void main() {
  Conversation makeConv({
    required String id,
    int unreadCount = 0,
    DateTime? updatedAt,
    Message? lastMessage,
  }) =>
      Conversation(
        id: id,
        participants: const [
          Participant(id: 'u1', displayName: 'Alice', permalink: 'alice'),
        ],
        lastMessage: lastMessage,
        unreadCount: unreadCount,
        updatedAt: updatedAt ?? DateTime(2025, 1, 1),
      );

  ProviderContainer makeContainer({
    required MockMessagingRepository repo,
    List<Conversation> conversations = const [],
    String userId = 'user_001',
  }) {
    when(repo.getConversations(page: anyNamed('page'), limit: anyNamed('limit')))
        .thenAnswer((_) async => conversations);

    return ProviderContainer(
      overrides: [
        messagingRepositoryProvider.overrideWithValue(repo),
        sessionUserIdProvider.overrideWith((ref) => userId),
      ],
    );
  }

  group('ConversationsNotifier.incrementUnread', () {
    test('increments unread count for the target conversation', () async {
      final repo = MockMessagingRepository();
      final conv = makeConv(id: 'conv_001', unreadCount: 2);
      final container = makeContainer(repo: repo, conversations: [conv]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).incrementUnread('conv_001');

      final updated = container.read(conversationsProvider).value!;
      expect(updated.first.unreadCount, 3);
    });

    test('does not affect other conversations', () async {
      final repo = MockMessagingRepository();
      final c1 = makeConv(id: 'conv_001', unreadCount: 0);
      final c2 = makeConv(id: 'conv_002', unreadCount: 5);
      final container = makeContainer(repo: repo, conversations: [c1, c2]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).incrementUnread('conv_001');

      final updated = container.read(conversationsProvider).value!;
      expect(updated.firstWhere((c) => c.id == 'conv_002').unreadCount, 5);
    });

    test('bumps updatedAt so conversation moves to top after sort', () async {
      final repo = MockMessagingRepository();
      final older = makeConv(id: 'conv_old', unreadCount: 0, updatedAt: DateTime(2025, 1, 1));
      final newer = makeConv(id: 'conv_new', unreadCount: 0, updatedAt: DateTime(2025, 6, 1));
      final container = makeContainer(repo: repo, conversations: [newer, older]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).incrementUnread('conv_old');

      final updated = container.read(conversationsProvider).value!;
      expect(updated.first.id, 'conv_old');
    });

    test('is a no-op when conversationId does not match any conversation', () async {
      final repo = MockMessagingRepository();
      final conv = makeConv(id: 'conv_001', unreadCount: 1);
      final container = makeContainer(repo: repo, conversations: [conv]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).incrementUnread('nonexistent');

      final updated = container.read(conversationsProvider).value!;
      expect(updated.first.unreadCount, 1);
    });

    test('state is AsyncData after incrementUnread', () async {
      final repo = MockMessagingRepository();
      final conv = makeConv(id: 'c1');
      final container = makeContainer(repo: repo, conversations: [conv]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).incrementUnread('c1');

      expect(container.read(conversationsProvider), isA<AsyncData<List<Conversation>>>());
    });

    test('returns empty list when userId is empty', () async {
      final repo = MockMessagingRepository();
      final container = makeContainer(repo: repo, conversations: [], userId: '');
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      expect(container.read(conversationsProvider).value!, isEmpty);
    });
  });

  group('ConversationsNotifier.resetUnread', () {
    test('resets unread count to 0', () async {
      final repo = MockMessagingRepository();
      final conv = makeConv(id: 'conv_001', unreadCount: 5);
      final container = makeContainer(repo: repo, conversations: [conv]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).resetUnread('conv_001');

      expect(container.read(conversationsProvider).value!.first.unreadCount, 0);
    });

    test('is a no-op when unreadCount is already 0', () async {
      final repo = MockMessagingRepository();
      final conv = makeConv(id: 'conv_001', unreadCount: 0);
      final container = makeContainer(repo: repo, conversations: [conv]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).resetUnread('conv_001');

      expect(container.read(conversationsProvider).value!.first.unreadCount, 0);
    });

    test('does not affect other conversations', () async {
      final repo = MockMessagingRepository();
      final c1 = makeConv(id: 'conv_001', unreadCount: 3);
      final c2 = makeConv(id: 'conv_002', unreadCount: 7);
      final container = makeContainer(repo: repo, conversations: [c1, c2]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).resetUnread('conv_001');

      expect(container.read(conversationsProvider).value!.firstWhere((c) => c.id == 'conv_002').unreadCount, 7);
    });

    test('is a no-op when conversationId does not match', () async {
      final repo = MockMessagingRepository();
      final conv = makeConv(id: 'conv_001', unreadCount: 4);
      final container = makeContainer(repo: repo, conversations: [conv]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).resetUnread('unknown');

      expect(container.read(conversationsProvider).value!.first.unreadCount, 4);
    });

    test('preserves all other fields when resetting unread', () async {
      final repo = MockMessagingRepository();
      final lastMsg = Message(
        id: 'msg_1',
        conversationId: 'conv_001',
        senderId: 'u1',
        content: 'Keep me',
        createdAt: DateTime(2025, 1, 1),
      );
      final conv = makeConv(id: 'conv_001', unreadCount: 3, lastMessage: lastMsg);
      final container = makeContainer(repo: repo, conversations: [conv]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.future);
      container.read(conversationsProvider.notifier).resetUnread('conv_001');

      final updated = container.read(conversationsProvider).value!.first;
      expect(updated.id, 'conv_001');
      expect(updated.lastMessage?.content, 'Keep me');
      expect(updated.participants.first.displayName, 'Alice');
      expect(updated.unreadCount, 0);
    });
  });
}
