import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/session_provider.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/participant.dart';
import '../providers/messaging_providers.dart';
import '../widgets/conversation_tile.dart';

class ChatInboxPage extends ConsumerWidget {
  const ChatInboxPage({super.key});

  Participant? _otherParticipant(Conversation c, String userId) {
    try {
      return c.participants.firstWhere((p) => p.id != userId);
    } catch (_) {
      return c.participants.isNotEmpty ? c.participants.first : null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(sessionUserIdProvider);
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Inbox',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'New message',
            onPressed: () => context.push('/messages/new'),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load messages',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(conversationsProvider),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFFFF5500)),
                ),
              ),
            ],
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Text(
                'No messages yet',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFFFF5500),
            backgroundColor: const Color(0xFF1F1F1F),
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(
                color: Color(0xFF2A2A2A),
                height: 1,
                indent: 72,
              ),
              itemBuilder: (context, i) {
                final c = conversations[i];
                final other = _otherParticipant(c, currentUserId);
                if (other == null) return const SizedBox.shrink();
                return ConversationTile(
                  conversation: c,
                  otherParticipant: other,
                  currentUserId: currentUserId,
                  onTap: () => context.push('/messages/chat/${c.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
