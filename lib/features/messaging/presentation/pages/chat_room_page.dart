import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/socket/socket_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/participant.dart';
import '../providers/messaging_providers.dart';
import '../widgets/message_bubble.dart';
import '../widgets/participant_avatar.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatRoomPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  // Local copy of messages; initialized on first data load, mutated for optimistic updates.
  List<Message>? _localMessages;
  bool _hasScrolledToBottom = false;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _deliverySubscription;
  StreamSubscription<Map<String, dynamic>>? _readSubscription;
  // Cached in initState so dispose() can call leaveChat without touching ref.
  late final SocketService _socketService;
  bool _hasEmittedReceipts = false;

  @override
  void initState() {
    super.initState();
    _joinAndSubscribe();
  }

  void _joinAndSubscribe() {
    _socketService = ref.read(socketServiceProvider);
    _socketService.joinChat(widget.conversationId);
    _messageSubscription = _socketService.newMessages.listen(_onSocketMessage);
    _deliverySubscription =
        _socketService.deliveryReceipts.listen(_onDeliveryReceipt);
    _readSubscription = _socketService.readReceipts.listen(_onReadReceipt);
  }

  void _onDeliveryReceipt(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;
    if (_localMessages == null) return;
    setState(() {
      _localMessages = _localMessages!
          .map((m) => m.status == 'sent' ? m.copyWith(status: 'delivered') : m)
          .toList();
    });
  }

  void _onReadReceipt(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;
    if (_localMessages == null) return;
    setState(() {
      _localMessages = _localMessages!
          .map((m) => (m.status == 'sent' || m.status == 'delivered')
              ? m.copyWith(status: 'read')
              : m)
          .toList();
    });
  }

  void _emitReceipts() {
    _socketService.markAsDelivered(widget.conversationId);
    ref
        .read(messagingRepositoryProvider)
        .markAsRead(widget.conversationId)
        .catchError((_) {});
  }

  void _onSocketMessage(Map<String, dynamic> data) {
    // Filter: only handle messages belonging to this conversation.
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;

    // Drop if local list hasn't been seeded yet (REST still loading).
    if (_localMessages == null) return;

    final incoming = Message.fromJson(data);

    // Deduplication: skip if the same message id is already present.
    // This guards against the backend echoing the sender's own message
    // after the optimistic entry has already been confirmed.
    if (_localMessages!.any((m) => m.id == incoming.id)) return;

    setState(() => _localMessages!.add(incoming));
    _scrollToBottom(force: true);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _deliverySubscription?.cancel();
    _readSubscription?.cancel();
    _socketService.leaveChat(widget.conversationId);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false}) {
    if (_hasScrolledToBottom && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        _hasScrolledToBottom = true;
      }
    });
  }

  Participant? _resolveOtherParticipant(String currentUserId) {
    final conversations = ref.read(conversationsProvider).valueOrNull ?? [];
    try {
      final conversation =
          conversations.firstWhere((c) => c.id == widget.conversationId);
      return conversation.participants
          .firstWhere((p) => p.id != currentUserId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendMessage({
    required String currentUserId,
    required String receiverId,
  }) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    final optimisticId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = Message(
      id: optimisticId,
      conversationId: widget.conversationId,
      senderId: currentUserId,
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() => _localMessages!.add(optimistic));
    _scrollToBottom(force: true);

    try {
      final sent = await ref
          .read(messagingRepositoryProvider)
          .sendMessage(receiverId: receiverId, content: text);

      if (!mounted) return;
      setState(() {
        final idx = _localMessages!.indexWhere((m) => m.id == optimisticId);
        if (idx >= 0) _localMessages![idx] = sent;
      });
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _localMessages!.removeWhere((m) => m.id == optimisticId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(sessionUserIdProvider);
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final otherParticipant = _resolveOtherParticipant(currentUserId);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: otherParticipant != null
            ? Row(
                children: [
                  ParticipantAvatar(
                    avatarUrl: otherParticipant.avatarUrl,
                    displayName: otherParticipant.displayName,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      otherParticipant.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : const Text(
                'Chat',
                style: TextStyle(color: Colors.white),
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
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
                      onPressed: () => ref.invalidate(
                        messagesProvider(widget.conversationId),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Color(0xFFFF5500)),
                      ),
                    ),
                  ],
                ),
              ),
              data: (loaded) {
                // Seed local list on first load; ignore subsequent provider rebuilds
                // so optimistic messages aren't overwritten.
                _localMessages ??= List.of(loaded);

                // Emit delivery + read receipts once, after messages are available.
                if (!_hasEmittedReceipts) {
                  _hasEmittedReceipts = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _emitReceipts();
                  });
                }

                if (_localMessages!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                _scrollToBottom();

                return RefreshIndicator(
                  color: const Color(0xFFFF5500),
                  backgroundColor: const Color(0xFF1F1F1F),
                  onRefresh: () async {
                    _hasScrolledToBottom = false;
                    setState(() => _localMessages = null);
                    ref.invalidate(messagesProvider(widget.conversationId));
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _localMessages!.length,
                    itemBuilder: (context, i) {
                      final msg = _localMessages![i];
                      final isOwn = msg.senderId == currentUserId;
                      // Optimistic messages have a 'pending_' id; dim them slightly.
                      final isPending = msg.id.startsWith('pending_');
                      return Opacity(
                        opacity: isPending ? 0.6 : 1.0,
                        child: MessageBubble(
                          message: msg,
                          isOwn: isOwn,
                          otherParticipant: isOwn ? null : otherParticipant,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _MessageInputBar(
            controller: _textController,
            // Disable send when we don't yet know who to send to.
            onSend: otherParticipant == null
                ? null
                : () => _sendMessage(
                      currentUserId: currentUserId,
                      receiverId: otherParticipant.id,
                    ),
          ),
        ],
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSend;

  const _MessageInputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend?.call(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              color: onSend != null
                  ? const Color(0xFFFF5500)
                  : Colors.white24,
              iconSize: 26,
            ),
          ],
        ),
      ),
    );
  }
}
