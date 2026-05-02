import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/utils/profile_navigation.dart';
import '../../../player/data/services/player_api_service.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/datasources/messaging_remote_data_source.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/participant.dart';
import '../providers/messaging_providers.dart';
import '../widgets/attachment_picker_sheet.dart';
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
  final List<Map<String, dynamic>> _pendingSocketMessages = [];
  bool _hasScrolledToBottom = false;

  // Pending attachment selection from the picker.
  AttachmentSelection? _pendingAttachment;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref
          .read(conversationsProvider.notifier)
          .resetUnread(widget.conversationId);
    });
    _messageSubscription = _socketService.newMessages.listen(_onSocketMessage);
    _deliverySubscription =
        _socketService.deliveryReceipts.listen(_onDeliveryReceipt);
    _readSubscription = _socketService.readReceipts.listen(_onReadReceipt);
    _typingSubscription = _socketService.userTyping.listen(_onUserTyping);
    _stoppedTypingSubscription =
        _socketService.userStoppedTyping.listen(_onUserStoppedTyping);
    _editedSubscription = _socketService.messageEdited.listen(_onMessageEdited);
    _deletedSubscription =
        _socketService.messageDeletedEveryone.listen(_onMessageDeletedEveryone);
  }

  // ── Existing receipt handlers ──────────────────────────────────────────────

  void _onDeliveryReceipt(Map<String, dynamic> data) {
    final convId = _conversationIdFrom(data);
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
    final convId = _conversationIdFrom(data);
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
    final convId = _conversationIdFrom(data);
    if (convId != widget.conversationId) {
      debugPrint(
        '[ChatRoom] ignored socket message: '
        'current=${widget.conversationId} incoming=$convId',
      );
      return;
    }

    // If REST is still loading, keep the socket event and force a refetch.
    if (_localMessages == null) {
      debugPrint('[ChatRoom] queued socket message while loading: $convId');
      _pendingSocketMessages.add(data);
      ref.invalidate(messagesProvider(widget.conversationId));
      return;
    }

    _appendIncomingMessage(data);
  }

  void _appendIncomingMessage(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data)
      ..['conversationId'] = _conversationIdFrom(data);
    final incoming = Message.fromJson(normalized);

    // Deduplication: skip if the same message id is already present.
    if (_localMessages!.any((m) => m.id == incoming.id)) {
      debugPrint('[ChatRoom] skipped duplicate socket message: ${incoming.id}');
      return;
    }

    debugPrint('[ChatRoom] appended socket message: ${incoming.id}');
    setState(() => _localMessages!.add(incoming));
    if (incoming.attachment != null && !incoming.attachment!.hasRichData) {
      _refreshMessagesFromServerSoon();
    }
    _emitReceipts();
    _scrollToBottom(force: true);
  }

  void _refreshMessagesFromServerSoon() {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _localMessages = null);
      ref.invalidate(messagesProvider(widget.conversationId));
    });
  }

  String _conversationIdFrom(Map<String, dynamic> message) {
    final direct = message['conversationId'] ?? message['chatId'];
    final directValue = _idValue(direct);
    if (directValue.isNotEmpty) return directValue;

    final conversation = message['conversation'];
    final conversationValue = _idValue(conversation);
    if (conversationValue.isNotEmpty) return conversationValue;

    return '';
  }

  String _idValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return (map['_id'] ?? map['id'] ?? '').toString();
    }
    return value.toString();
  }

  // ── Typing indicator (incoming) ────────────────────────────────────────────

  void _onUserTyping(Map<String, dynamic> data) {
    final convId = _conversationIdFrom(data);
    if (convId != widget.conversationId) return;
    _typingHideTimer?.cancel();
    setState(() => _otherUserIsTyping = true);
    // Safety-net: auto-hide after 3 s in case stop event is lost.
    _typingHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _otherUserIsTyping = false);
    });
  }

  void _onUserStoppedTyping(Map<String, dynamic> data) {
    final convId = _conversationIdFrom(data);
    if (convId != widget.conversationId) return;
    _typingHideTimer?.cancel();
    if (mounted) setState(() => _otherUserIsTyping = false);
  }

  // ── Edit / delete socket events ────────────────────────────────────────────

  void _onMessageEdited(Map<String, dynamic> data) {
    final convId = _conversationIdFrom(data);
    if (convId != widget.conversationId) return;
    if (_localMessages == null) return;
    final messageId = data['_id'] as String? ?? data['id'] as String?;
    final newContent = data['content'] as String?;
    if (messageId == null || newContent == null) return;
    setState(() {
      final idx = _localMessages!.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _localMessages![idx] =
            _localMessages![idx].copyWith(content: newContent, isEdited: true);
      }
    });
  }

  void _onMessageDeletedEveryone(Map<String, dynamic> data) {
    final convId = _conversationIdFrom(data);
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
    final convId = widget.conversationId;

    if (_textController.text.isEmpty) {
      _stopTypingIfNeeded(convId);
      return;
    }

    if (!_isTypingEmitted) {
      _isTypingEmitted = true;
      _socketService.sendTyping(convId);
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), () {
      _isTypingEmitted = false;
      _socketService.sendStoppedTyping(convId);
    });
  }

  void _stopTypingIfNeeded(String convId) {
    if (!_isTypingEmitted) return;

    _isTypingEmitted = false;
    _typingStopTimer?.cancel();
    _socketService.sendStoppedTyping(convId);
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

  // ── Attachment picker ──────────────────────────────────────────────────────

  Future<void> _openAttachmentPicker() async {
    final selection = await showAttachmentPicker(context);
    if (selection == null || !mounted) return;
    setState(() => _pendingAttachment = selection);
  }

  void _clearPendingAttachment() {
    setState(() => _pendingAttachment = null);
  }

  // ── Attachment tap-to-navigate ─────────────────────────────────────────────

  Future<void> _onAttachmentTap(Attachment attachment) async {
    if (!attachment.isAvailable) return;

    if (attachment.type == 'playlist') {
      context.push('/playlist', extra: {'playlistId': attachment.referenceId});
      return;
    }

    // For tracks: fetch full details so we can play them, then open the player.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loading track…'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final playerTrack =
          await ref.read(playerApiServiceProvider).getTrackDetails(
                attachment.referenceId,
                trackPermalink: attachment.permalink,
              );

      if (!mounted) return;

      if (playerTrack == null) {
        debugPrint(
          '[ChatRoom] track fetch returned null — '
          'referenceId=${attachment.referenceId} permalink=${attachment.permalink}',
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not load track')),
          );
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ref.read(playerProvider.notifier).playTrack(playerTrack);
      context.push('/player');
    } catch (e, st) {
      debugPrint('[ChatRoom] _onAttachmentTap error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not load track')),
        );
    }
  }

  // ── Send message ───────────────────────────────────────────────────────────

  Future<void> _sendMessage({
    required String currentUserId,
    required String receiverId,
  }) async {
    final text = _textController.text.trim();
    final attachment = _pendingAttachment;

    // Must have at least text or an attachment.
    if (text.isEmpty && attachment == null) return;

    // Stop typing indicator immediately on send.
    _stopTypingIfNeeded(widget.conversationId);
    _textController.clear();
    setState(() => _pendingAttachment = null);

    final optimisticId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = Message(
      id: optimisticId,
      conversationId: widget.conversationId,
      senderId: currentUserId,
      content: text,
      attachment: attachment != null
          ? Attachment(
              type: attachment.type,
              referenceId: attachment.id,
              title: attachment.title,
              artworkUrl: attachment.artworkUrl,
            )
          : null,
      createdAt: DateTime.now(),
    );

    setState(() => (_localMessages ??= []).add(optimistic));
    _scrollToBottom(force: true);

    try {
      final sent = await ref.read(messagingRepositoryProvider).sendMessage(
            receiverId: receiverId,
            content: text.isNotEmpty ? text : null,
            conversationId: widget.conversationId,
            attachmentType: attachment?.type,
            attachmentId: attachment?.id,
          );

      if (!mounted) return;
      if (sent.conversationId != widget.conversationId) {
        debugPrint(
          '[ChatRoom] sendMessage returned different conversationId: '
          'current=${widget.conversationId} returned=${sent.conversationId}',
        );
      }
      setState(() {
        final messages = _localMessages ??= [];
        final idx = messages.indexWhere((m) => m.id == optimisticId);
        if (idx >= 0) {
          messages[idx] = _preserveOptimisticAttachmentData(
            sent,
            optimistic.attachment,
          );
        }
      });
      ref.invalidate(conversationsProvider);
    } on PrivateAttachmentException {
      if (!mounted) return;
      setState(() => _localMessages!.removeWhere((m) => m.id == optimisticId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This track is private and cannot be shared.'),
          backgroundColor: Color(0xFF3A1A1A),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _localMessages!.removeWhere((m) => m.id == optimisticId));
      final isAttachmentError =
          e.response?.statusCode == 400 && attachment != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAttachmentError
                ? "Couldn't send attachment — please try again."
                : 'Failed to send message',
          ),
          backgroundColor: isAttachmentError ? const Color(0xFF3A1A1A) : null,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _localMessages!.removeWhere((m) => m.id == optimisticId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Message _preserveOptimisticAttachmentData(
    Message sent,
    Attachment? optimisticAttachment,
  ) {
    final sentAttachment = sent.attachment;
    if (sentAttachment == null || optimisticAttachment == null) return sent;
    if (sentAttachment.hasRichData &&
        (sentAttachment.artworkUrl?.isNotEmpty ?? false)) {
      return sent;
    }
    return Message(
      id: sent.id,
      conversationId: sent.conversationId,
      senderId: sent.senderId,
      senderDisplayName: sent.senderDisplayName,
      senderAvatarUrl: sent.senderAvatarUrl,
      content: sent.content,
      attachment: Attachment(
        type: sentAttachment.type.isNotEmpty
            ? sentAttachment.type
            : optimisticAttachment.type,
        referenceId: sentAttachment.referenceId.isNotEmpty
            ? sentAttachment.referenceId
            : optimisticAttachment.referenceId,
        title: sentAttachment.title ?? optimisticAttachment.title,
        artworkUrl:
            sentAttachment.artworkUrl ?? optimisticAttachment.artworkUrl,
        permalink: sentAttachment.permalink ?? optimisticAttachment.permalink,
        artistName:
            sentAttachment.artistName ?? optimisticAttachment.artistName,
        duration: sentAttachment.duration ?? optimisticAttachment.duration,
      ),
      status: sent.status,
      isEdited: sent.isEdited,
      isDeleted: sent.isDeleted,
      createdAt: sent.createdAt,
    );
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
    if (_isTypingEmitted) {
      _socketService.sendStoppedTyping(widget.conversationId);
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
      return conversation.participants.firstWhere((p) => p.id != currentUserId);
    } catch (_) {
      return null;
    }
  }

  Participant? _fallbackParticipantFromMessages(
    String currentUserId,
    List<Message>? loadedMessages,
  ) {
    final messages = _localMessages ?? loadedMessages;
    if (messages == null) return null;

    for (final message in messages) {
      if (message.senderId == currentUserId) continue;
      final displayName = message.senderDisplayName?.trim();
      if (displayName == null || displayName.isEmpty) continue;
      return Participant(
        id: message.senderId,
        displayName: displayName,
        avatarUrl: message.senderAvatarUrl,
        permalink: '',
      );
    }

    return null;
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/messages');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(sessionUserIdProvider);
    final conversationsAsync = ref.watch(conversationsProvider);
    final conversations = conversationsAsync.valueOrNull ?? const [];
    final conversationLookupComplete = conversationsAsync.hasValue;
    final conversationExists =
        conversations.any((c) => c.id == widget.conversationId);
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final otherParticipant = _resolveOtherParticipant(currentUserId) ??
        _fallbackParticipantFromMessages(
          currentUserId,
          messagesAsync.valueOrNull,
        );

    final isEditing = _editingMessageId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('chat_back_button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBack,
        ),
        title: otherParticipant != null
            ? GestureDetector(
                onTap: otherParticipant.id.isNotEmpty &&
                        otherParticipant.permalink.isNotEmpty
                    ? () => navigateToUserProfile(
                          context,
                          userId: otherParticipant.id,
                          permalink: otherParticipant.permalink,
                          displayName: otherParticipant.displayName,
                        )
                    : null,
                child: Row(
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
                ),
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
                // Seed local list on first load; ignore subsequent provider
                // rebuilds so optimistic messages aren't overwritten.
                _localMessages ??= List.of(loaded);
                if (_pendingSocketMessages.isNotEmpty) {
                  final pending = List<Map<String, dynamic>>.from(
                    _pendingSocketMessages,
                  );
                  _pendingSocketMessages.clear();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    for (final message in pending) {
                      _appendIncomingMessage(message);
                    }
                  });
                }

                // Emit delivery + read receipts once after messages arrive.
                if (!_hasEmittedReceipts) {
                  _hasEmittedReceipts = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _emitReceipts();
                  });
                }

                if (_localMessages!.isEmpty) {
                  if (conversationLookupComplete && !conversationExists) {
                    return _UnknownConversationFallback(
                      onOpenInbox: () => context.go('/messages'),
                    );
                  }
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
                    key: const ValueKey('message_list'),
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
                      final canEditDelete =
                          isOwn && !msg.isDeleted && !isPending && withinWindow;
                      return Opacity(
                        opacity: isPending ? 0.6 : 1.0,
                        child: KeyedSubtree(
                          key: ValueKey('message_bubble_$i'),
                          child: MessageBubble(
                            message: msg,
                            isOwn: isOwn,
                            otherParticipant: isOwn ? null : otherParticipant,
                            onEdit: canEditDelete &&
                                    msg.content.isNotEmpty &&
                                    msg.attachment == null
                                ? () => _enterEditMode(msg)
                                : null,
                            onDelete: canEditDelete
                                ? () => _deleteMessage(msg)
                                : null,
                            onAttachmentTap: msg.attachment != null
                                ? _onAttachmentTap
                                : null,
                          ),
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
          // Pending attachment preview strip
          if (_pendingAttachment != null)
            _AttachmentPreviewStrip(
              selection: _pendingAttachment!,
              onClear: _clearPendingAttachment,
            ),
          _MessageInputBar(
            controller: _textController,
            focusNode: _textFocusNode,
            isEditMode: isEditing,
            hasAttachment: _pendingAttachment != null,
            onCancelEdit: isEditing ? _cancelEditMode : null,
            onAttach: isEditing ? null : _openAttachmentPicker,
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

// ── Attachment preview strip ──────────────────────────────────────────────────

class _AttachmentPreviewStrip extends StatelessWidget {
  final AttachmentSelection selection;
  final VoidCallback onClear;

  const _AttachmentPreviewStrip({
    required this.selection,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isTrack = selection.type == 'track';
    final hasArtwork = selection.artworkUrl != null &&
        selection.artworkUrl!.isNotEmpty &&
        selection.artworkUrl!.startsWith('http');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 36,
              height: 36,
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: selection.artworkUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _fallback(isTrack),
                    )
                  : _fallback(isTrack),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selection.title ?? (isTrack ? 'Track' : 'Playlist'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isTrack ? 'Track' : 'Playlist',
                  style: const TextStyle(
                    color: Color(0xFFFF5500),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _fallback(bool isTrack) => ColoredBox(
        color: const Color(0xFF2A2A2A),
        child: Center(
          child: Icon(
            isTrack ? Icons.music_note : Icons.queue_music,
            color: Colors.white38,
            size: 16,
          ),
        ),
      );
}

// ── Unknown conversation fallback ─────────────────────────────────────────────

class _UnknownConversationFallback extends StatelessWidget {
  final VoidCallback onOpenInbox;

  const _UnknownConversationFallback({required this.onOpenInbox});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not open this chat',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'The notification did not include a valid conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onOpenInbox,
              child: const Text(
                'Open inbox',
                style: TextStyle(color: Color(0xFFFF5500)),
              ),
            ),
          ],
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final dotCount = (_controller.value * 3).floor().clamp(1, 3);
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
  final VoidCallback? onAttach;
  final bool isEditMode;
  final bool hasAttachment;
  final VoidCallback? onCancelEdit;

  const _MessageInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.onAttach,
    this.isEditMode = false,
    this.hasAttachment = false,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Attach button (hidden in edit mode)
                  if (!isEditMode)
                    IconButton(
                      key: const ValueKey('message_attach_button'),
                      onPressed: onAttach,
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: hasAttachment
                            ? const Color(0xFFFF5500)
                            : Colors.white54,
                      ),
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (!isEditMode) const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('message_input_field'),
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText:
                            isEditMode ? 'Edit message...' : 'Write a message…',
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
                    key: const ValueKey('message_send_button'),
                    onPressed: onSend,
                    icon: Icon(
                      isEditMode ? Icons.check_rounded : Icons.send_rounded,
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
