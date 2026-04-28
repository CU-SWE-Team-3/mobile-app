import 'package:flutter/material.dart';

import '../../../../core/utils/relative_time.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/participant.dart';
import 'participant_avatar.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final Participant? otherParticipant;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.otherParticipant,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
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
              crossAxisAlignment:
                  isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AttachmentPill(type: message.attachment!.type),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            _MessageText(
                content: message.content, isEdited: message.isEdited),
          ],
        ],
      );
    } else {
      content =
          _MessageText(content: message.content, isEdited: message.isEdited);
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

class _AttachmentPill extends StatelessWidget {
  final String type;

  const _AttachmentPill({required this.type});

  @override
  Widget build(BuildContext context) {
    final isTrack = type == 'track';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF555555)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTrack ? Icons.music_note : Icons.queue_music,
            size: 14,
            color: Colors.white54,
          ),
          const SizedBox(width: 5),
          Text(
            isTrack ? 'Track' : 'Playlist',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
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
