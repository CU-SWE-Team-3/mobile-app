import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/messaging_repository.dart';

// ── Socket ────────────────────────────────────────────────────────────────────

/// Thin Riverpod wrapper around the get_it SocketService singleton.
final socketServiceProvider = Provider<SocketService>(
  (ref) => sl<SocketService>(),
);

/// Watches sessionUserIdProvider and drives the socket lifecycle.
/// Connect on login, disconnect on logout. Activated by AppShell watching it.
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

/// Keeps conversation lists fresh when messages arrive outside an open chat.
final socketMessageLifecycleProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  final service = ref.watch(socketServiceProvider);
  StreamSubscription<Map<String, dynamic>>? sub;

  if (userId.isNotEmpty) {
    sub = service.newMessages.listen((data) {
      final conversationId = data['conversationId']?.toString() ?? '';
      ref.invalidate(conversationsProvider);
      if (conversationId.isNotEmpty) {
        ref.invalidate(messagesProvider(conversationId));
      }
    });
  }

  ref.onDispose(() => sub?.cancel());
});

// ── Repository ────────────────────────────────────────────────────────────────

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => sl<MessagingRepository>(),
);

// ── Conversations ─────────────────────────────────────────────────────────────

/// All conversations for the current user. Returns [] when unauthenticated.
/// Auto-invalidates when sessionUserIdProvider changes (Riverpod dependency
/// tracking handles this — no manual invalidation needed on user switch).
final conversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId.isEmpty) return [];
  return ref.watch(messagingRepositoryProvider).getConversations();
});

// ── Messages ──────────────────────────────────────────────────────────────────

/// Messages for a given conversation. Returns [] when unauthenticated.
/// The userId watch ensures this rebuilds and clears on user switch.
final messagesProvider = FutureProvider.autoDispose
    .family<List<Message>, String>((ref, conversationId) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId.isEmpty) return [];
  return ref.watch(messagingRepositoryProvider).getMessages(conversationId);
});
