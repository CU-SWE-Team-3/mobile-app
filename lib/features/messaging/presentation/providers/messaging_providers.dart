import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/messaging_repository.dart';

// ── Socket ────────────────────────────────────────────────────────────────────

final socketServiceProvider = Provider<SocketService>(
  (ref) => sl<SocketService>(),
);

final socketLifecycleProvider = Provider<void>((ref) {
  final service = ref.watch(socketServiceProvider);

  ref.listen<String>(
    sessionUserIdProvider,
    (previousUserId, nextUserId) {
      if (nextUserId.isEmpty) {
        service.disconnect();
        return;
      }

      if (previousUserId != nextUserId) {
        service.disconnect();
        unawaited(service.connect());
      }
    },
    fireImmediately: true,
  );
});

/// Keeps conversation unread counts live when messages arrive outside an open
/// chat. Increments the count for the relevant conversation immediately so the
/// badge updates without a full re-fetch. If the user IS inside that chat,
/// [SocketService.isViewingConversation] returns true and the count is not
/// incremented (the chat's own receipt call will reset it instead).
final socketMessageLifecycleProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  final service = ref.watch(socketServiceProvider);
  StreamSubscription<Map<String, dynamic>>? sub;

  if (userId.isNotEmpty) {
    sub = service.newMessages.listen((data) {
      final conversationId = data['conversationId']?.toString() ?? '';
      if (conversationId.isEmpty) return;

      // Always refresh the message thread so the chat room stays current.
      ref.invalidate(messagesProvider(conversationId));

      // Only bump the unread badge if the user is NOT inside that conversation.
      if (!service.isViewingConversation(conversationId)) {
        ref.read(conversationsProvider.notifier).incrementUnread(conversationId);
      }
    });
  }

  ref.onDispose(() => sub?.cancel());
});

// ── Repository ────────────────────────────────────────────────────────────────

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => sl<MessagingRepository>(),
);

// ── Conversations notifier ────────────────────────────────────────────────────

/// Holds the full conversations list and exposes surgical mutations for unread
/// count changes so the UI can update without a round-trip to the server.
class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final userId = ref.watch(sessionUserIdProvider);
    if (userId.isEmpty) return [];
    return ref.read(messagingRepositoryProvider).getConversations();
  }

  /// Increments [conversationId]'s unread count by 1 in local state.
  /// No-op when the data is not yet loaded or the conversation is not found.
  void incrementUnread(String conversationId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.map((c) {
        if (c.id != conversationId) return c;
        return Conversation(
          id: c.id,
          participants: c.participants,
          lastMessage: c.lastMessage,
          unreadCount: c.unreadCount + 1,
          updatedAt: c.updatedAt,
        );
      }).toList(),
    );
  }

  /// Resets [conversationId]'s unread count to 0 in local state.
  /// No-op when already zero or when data is not yet loaded.
  void resetUnread(String conversationId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.map((c) {
        if (c.id != conversationId || c.unreadCount == 0) return c;
        return Conversation(
          id: c.id,
          participants: c.participants,
          lastMessage: c.lastMessage,
          unreadCount: 0,
          updatedAt: c.updatedAt,
        );
      }).toList(),
    );
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
  ConversationsNotifier.new,
);

// ── Total unread message count ────────────────────────────────────────────────

/// Sum of unread counts across all conversations. Returns 0 while loading.
final totalUnreadMessagesProvider = Provider<int>((ref) {
  return ref.watch(conversationsProvider).maybeWhen(
    data: (list) => list.fold<int>(0, (sum, c) => sum + c.unreadCount),
    orElse: () => 0,
  );
});

// ── Messages ──────────────────────────────────────────────────────────────────

final messagesProvider = FutureProvider.autoDispose
    .family<List<Message>, String>((ref, conversationId) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId.isEmpty) return [];
  return ref.watch(messagingRepositoryProvider).getMessages(conversationId);
});
