import 'package:flutter/material.dart';

import '../../../../core/utils/relative_time.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/participant.dart';
import 'attachment_card.dart';
import 'participant_avatar.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final Participant? otherParticipant;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.otherParticipant,
    this.onEdit,
    this.onDelete,
  });

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              ListTile(
                leading:
                    const Icon(Icons.edit_outlined, color: Colors.white),
                title: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onEdit!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMenu = onEdit != null || onDelete != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: GestureDetector(
        onLongPress: hasMenu ? () => _showContextMenu(context) : null,
        child: Row(
          mainAxisAlignment:
              isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwn) ...[
              ParticipantAvatar(
                avatarUrl: otherParticipant?.avatarUrl,
                displayName: otherParticipant?.displayName ?? '?',
                radius: 16,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isOwn
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  _BubbleBody(message: message, isOwn: isOwn),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatRelativeTime(message.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      if (isOwn) ...[
                        const SizedBox(width: 3),
                        _StatusTick(status: message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isOwn) const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  final Message message;
  final bool isOwn;

  const _BubbleBody({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (message.isDeleted) {
      content = Text(
        'This message was deleted',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    } else if (message.attachment != null) {
      // AttachmentCard is a ConsumerWidget and handles its own provider watches.
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AttachmentCard(attachment: message.attachment!),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            _MessageText(
              content: message.content,
              isEdited: message.isEdited,
            ),
          ],
        ],
      );
    } else {
      content = _MessageText(
        content: message.content,
        isEdited: message.isEdited,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isOwn ? const Color(0xFF2A2A2A) : const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isOwn ? 18 : 4),
          bottomRight: Radius.circular(isOwn ? 4 : 18),
        ),
      ),
      child: content,
    );
  }
}

class _MessageText extends StatelessWidget {
  final String content;
  final bool isEdited;

  const _MessageText({required this.content, required this.isEdited});

  @override
  Widget build(BuildContext context) {
    if (!isEdited) {
      return Text(
        content,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: content,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const TextSpan(
            text: ' (edited)',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusTick extends StatelessWidget {
  final String? status;

  const _StatusTick({required this.status});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    if (status == 'read') {
      icon = Icons.done_all;
      color = const Color(0xFFFF5500);
    } else if (status == 'delivered') {
      icon = Icons.done_all;
      color = Colors.white38;
    } else {
      // 'sent', null, or pending
      icon = Icons.done;
      color = Colors.white38;
    }

    return Icon(icon, size: 13, color: color);
  }
}
