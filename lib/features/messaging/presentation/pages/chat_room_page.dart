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
  final _textFocusNode = FocusNode();

  // Local copy of messages; initialized on first data load, mutated for
  // optimistic updates and real-time patches.
  List<Message>? _localMessages;
  bool _hasScrolledToBottom = false;

  // Existing socket subscriptions
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _deliverySubscription;
  StreamSubscription<Map<String, dynamic>>? _readSubscription;

  // Phase 6 socket subscriptions
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _stoppedTypingSubscription;
  StreamSubscription<Map<String, dynamic>>? _editedSubscription;
  StreamSubscription<Map<String, dynamic>>? _deletedSubscription;

  // Cached in initState so dispose() can call leaveChat without touching ref.
  late final SocketService _socketService;
  bool _hasEmittedReceipts = false;

  // Receiver ID cached from build() so the text-change listener can use it.
  String? _receiverId;

  // Typing emit state
  bool _isTypingEmitted = false;
  Timer? _typingStopTimer;

  // Typing indicator (incoming from other user)
  bool _otherUserIsTyping = false;
  Timer? _typingHideTimer;

  // Edit mode: non-null = currently editing that message id
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _joinAndSubscribe();
    _textController.addListener(_onTextChanged);
  }

  void _joinAndSubscribe() {
    _socketService = ref.read(socketServiceProvider);
    _socketService.joinChat(widget.conversationId);
    _messageSubscription =
        _socketService.newMessages.listen(_onSocketMessage);
    _deliverySubscription =
        _socketService.deliveryReceipts.listen(_onDeliveryReceipt);
    _readSubscription =
        _socketService.readReceipts.listen(_onReadReceipt);
    _typingSubscription =
        _socketService.userTyping.listen(_onUserTyping);
    _stoppedTypingSubscription =
        _socketService.userStoppedTyping.listen(_onUserStoppedTyping);
    _editedSubscription =
        _socketService.messageEdited.listen(_onMessageEdited);
    _deletedSubscription =
        _socketService.messageDeletedEveryone.listen(_onMessageDeletedEveryone);
  }

  // ── Existing receipt handlers ──────────────────────────────────────────────

  void _onDeliveryReceipt(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;
    if (_localMessages == null) return;
    setState(() {
      _localMessages = _localMessages!
          .map(
            (m) => m.status == 'sent' ? m.copyWith(status: 'delivered') : m,
          )
          .toList();
    });
  }

  void _onReadReceipt(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;
    if (_localMessages == null) return;
    setState(() {
      _localMessages = _localMessages!
          .map(
            (m) => (m.status == 'sent' || m.status == 'delivered')
                ? m.copyWith(status: 'read')
                : m,
          )
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
    if (_localMessages!.any((m) => m.id == incoming.id)) return;

    setState(() => _localMessages!.add(incoming));
    _scrollToBottom(force: true);
  }

  // ── Typing indicator (incoming) ────────────────────────────────────────────

  void _onUserTyping(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;
    _typingHideTimer?.cancel();
    setState(() => _otherUserIsTyping = true);
    // Safety-net: auto-hide after 3 s in case stop event is lost.
    _typingHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _otherUserIsTyping = false);
    });
  }

  void _onUserStoppedTyping(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;
    _typingHideTimer?.cancel();
    if (mounted) setState(() => _otherUserIsTyping = false);
  }

  // ── Edit / delete socket events ────────────────────────────────────────────

  void _onMessageEdited(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;
    if (_localMessages == null) return;
    final messageId = data['_id'] as String? ?? data['id'] as String?;
    final newContent = data['content'] as String?;
    if (messageId == null || newContent == null) return;
    setState(() {
      final idx = _localMessages!.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _localMessages![idx] = _localMessages![idx]
            .copyWith(content: newContent, isEdited: true);
      }
    });
  }

  void _onMessageDeletedEveryone(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    if (convId != widget.conversationId) return;
    if (_localMessages == null) return;
    final messageId = data['_id'] as String? ?? data['id'] as String?;
    if (messageId == null) return;
    setState(() {
      final idx = _localMessages!.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _localMessages![idx] = _localMessages![idx].copyWith(
          isDeleted: true,
          content: 'This message was deleted',
        );
      }
    });
  }

  // ── Typing emit logic ──────────────────────────────────────────────────────

  void _onTextChanged() {
    final receiverId = _receiverId;
    if (receiverId == null) return;

    if (_textController.text.isEmpty) {
      _stopTypingIfNeeded(receiverId);
      return;
    }

    // Emit only on first keystroke of each typing burst.
    if (!_isTypingEmitted) {
      _isTypingEmitted = true;
      _socketService.sendTyping(receiverId);
    }
    // Reset the 2-second inactivity timer on every keystroke.
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), () {
      _isTypingEmitted = false;
      _socketService.stopTyping(receiverId);
    });
  }

  void _stopTypingIfNeeded(String receiverId) {
    if (!_isTypingEmitted) return;
    _isTypingEmitted = false;
    _typingStopTimer?.cancel();
    _socketService.stopTyping(receiverId);
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  void _enterEditMode(Message message) {
    setState(() => _editingMessageId = message.id);
    _textController.text = message.content;
    _textController.selection =
        TextSelection.collapsed(offset: message.content.length);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _textFocusNode.requestFocus());
  }

  void _cancelEditMode() {
    setState(() => _editingMessageId = null);
    _textController.clear();
  }

  Future<void> _confirmEdit() async {
    final messageId = _editingMessageId;
    if (messageId == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _editingMessageId = null);
    _textController.clear();

    try {
      final updated = await ref
          .read(messagingRepositoryProvider)
          .editMessage(messageId, text);
      if (!mounted) return;
      setState(() {
        final idx = _localMessages!.indexWhere((m) => m.id == messageId);
        if (idx >= 0) _localMessages![idx] = updated;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to edit message')),
      );
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteMessage(Message message) async {
    try {
      await ref
          .read(messagingRepositoryProvider)
          .deleteMessageForEveryone(message.id);
      if (!mounted) return;
      setState(() {
        final idx = _localMessages!.indexWhere((m) => m.id == message.id);
        if (idx >= 0) {
          _localMessages![idx] = _localMessages![idx].copyWith(
            isDeleted: true,
            content: 'This message was deleted',
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete message')),
      );
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _messageSubscription?.cancel();
    _deliverySubscription?.cancel();
    _readSubscription?.cancel();
    _typingSubscription?.cancel();
    _stoppedTypingSubscription?.cancel();
    _editedSubscription?.cancel();
    _deletedSubscription?.cancel();
    _typingStopTimer?.cancel();
    _typingHideTimer?.cancel();
    // Emit stop_typing if disposed while mid-typing.
    if (_isTypingEmitted && _receiverId != null) {
      _socketService.stopTyping(_receiverId!);
    }
    _socketService.leaveChat(widget.conversationId);
    _scrollController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
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

    // Stop typing indicator immediately on send.
    _stopTypingIfNeeded(receiverId);

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
      setState(
          () => _localMessages!.removeWhere((m) => m.id == optimisticId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(sessionUserIdProvider);
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final otherParticipant = _resolveOtherParticipant(currentUserId);

    // Cache for the text-change listener (runs outside build).
    _receiverId = otherParticipant?.id;

    final isEditing = _editingMessageId != null;

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
                child:
                    CircularProgressIndicator(color: Color(0xFFFF5500)),
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
                // Seed local list on first load; ignore subsequent provider
                // rebuilds so optimistic messages aren't overwritten.
                _localMessages ??= List.of(loaded);

                // Emit delivery + read receipts once after messages arrive.
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
                      style:
                          TextStyle(color: Colors.white54, fontSize: 16),
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
                    ref.invalidate(
                        messagesProvider(widget.conversationId));
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _localMessages!.length,
                    itemBuilder: (context, i) {
                      final msg = _localMessages![i];
                      final isOwn = msg.senderId == currentUserId;
                      final isPending = msg.id.startsWith('pending_');

                      // Context menu: own, non-deleted, non-pending,
                      // within the 15-minute edit/delete window.
                      final withinWindow =
                          DateTime.now().difference(msg.createdAt).inMinutes <
                              15;
                      final canEditDelete = isOwn &&
                          !msg.isDeleted &&
                          !isPending &&
                          withinWindow;

                      return Opacity(
                        opacity: isPending ? 0.6 : 1.0,
                        child: MessageBubble(
                          message: msg,
                          isOwn: isOwn,
                          otherParticipant:
                              isOwn ? null : otherParticipant,
                          onEdit: canEditDelete
                              ? () => _enterEditMode(msg)
                              : null,
                          onDelete: canEditDelete
                              ? () => _deleteMessage(msg)
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          // Animated indicator shown while the other user is typing.
          if (_otherUserIsTyping)
            _TypingIndicator(participant: otherParticipant),
          _MessageInputBar(
            controller: _textController,
            focusNode: _textFocusNode,
            isEditMode: isEditing,
            onCancelEdit: isEditing ? _cancelEditMode : null,
            onSend: isEditing
                ? () => _confirmEdit()
                : (otherParticipant == null
                    ? null
                    : () => _sendMessage(
                          currentUserId: currentUserId,
                          receiverId: otherParticipant.id,
                        )),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator widget ───────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  final Participant? participant;

  const _TypingIndicator({this.participant});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          ParticipantAvatar(
            avatarUrl: widget.participant?.avatarUrl,
            displayName: widget.participant?.displayName ?? '?',
            radius: 12,
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final dotCount =
                    (_controller.value * 3).floor().clamp(1, 3);
                return Text(
                  '.' * dotCount,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 20,
                    letterSpacing: 4,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onSend;
  final bool isEditMode;
  final VoidCallback? onCancelEdit;

  const _MessageInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.isEditMode = false,
    this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit mode banner
            if (isEditMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Color(0xFFFF5500),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Editing message',
                        style: TextStyle(
                          color: Color(0xFFFF5500),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onCancelEdit,
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isEditMode
                            ? 'Edit message...'
                            : 'Write a message...',
                        hintStyle:
                            const TextStyle(color: Colors.white38),
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
                    icon: Icon(
                      isEditMode
                          ? Icons.check_rounded
                          : Icons.send_rounded,
                    ),
                    color: onSend != null
                        ? const Color(0xFFFF5500)
                        : Colors.white24,
                    iconSize: 26,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
