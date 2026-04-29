import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/relative_time.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/participant.dart';
import 'participant_avatar.dart';
import 'track_attachment_card.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final Participant? otherParticipant;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(Attachment)? onAttachmentTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.otherParticipant,
    this.onEdit,
    this.onDelete,
    this.onAttachmentTap,
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
                  _BubbleBody(
                    message: message,
                    isOwn: isOwn,
                    onAttachmentTap: onAttachmentTap != null &&
                            message.attachment != null
                        ? () => onAttachmentTap!(message.attachment!)
                        : null,
                  ),
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
                        _StatusTick(
                          key: const ValueKey('message_status_indicator'),
                          status: message.status,
                        ),
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
  final VoidCallback? onAttachmentTap;

  const _BubbleBody({
    required this.message,
    required this.isOwn,
    this.onAttachmentTap,
  });

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
    } else {
      final hasText = message.content.isNotEmpty;
      final hasAttachment = message.attachment != null;

      if (hasAttachment && hasText) {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _attachmentWidget(message.attachment!, onAttachmentTap),
            const SizedBox(height: 6),
            _MessageText(
              content: message.content,
              isEdited: message.isEdited,
            ),
          ],
        );
      } else if (hasAttachment) {
        content = _attachmentWidget(message.attachment!, onAttachmentTap);
      } else {
        content = _MessageText(
          content: message.content,
          isEdited: message.isEdited,
        );
      }
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

  Widget _attachmentWidget(Attachment attachment, VoidCallback? onTap) {
    if (attachment.type == 'track') {
      return TrackAttachmentCard(attachment: attachment, onTap: onTap);
    }
    return _AttachmentCard(attachment: attachment, onTap: onTap);
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

/// Rich in-chat preview card for track and playlist attachments.
/// Shows artwork, title, and type badge. Gracefully degrades when
/// rich data is absent (socket-only payload) or the entity is deleted.
class _AttachmentCard extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onTap;

  const _AttachmentCard({required this.attachment, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!attachment.isAvailable) {
      return _UnavailablePlaceholder(type: attachment.type);
    }

    final isTrack = attachment.type == 'track';
    final hasArtwork = attachment.artworkUrl != null &&
        attachment.artworkUrl!.isNotEmpty &&
        attachment.artworkUrl!.startsWith('http');
    final displayTitle =
        attachment.hasRichData ? attachment.title! : (isTrack ? 'Track' : 'Playlist');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3A3A3A)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Artwork thumbnail (48×48)
            SizedBox(
              width: 52,
              height: 52,
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: attachment.artworkUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _artworkFallback(isTrack),
                      errorWidget: (_, __, ___) => _artworkFallback(isTrack),
                    )
                  : _artworkFallback(isTrack),
            ),
            // Title + type badge
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTrack ? Icons.music_note : Icons.queue_music,
                          size: 11,
                          color: const Color(0xFFFF5500),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isTrack ? 'Track' : 'Playlist',
                          style: const TextStyle(
                            color: Color(0xFFFF5500),
                            fontSize: 11,
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Colors.white38,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artworkFallback(bool isTrack) => ColoredBox(
        color: const Color(0xFF2A2A2A),
        child: Center(
          child: Icon(
            isTrack ? Icons.music_note : Icons.queue_music,
            color: Colors.white38,
            size: 22,
          ),
        ),
      );
}

class _UnavailablePlaceholder extends StatelessWidget {
  final String type;

  const _UnavailablePlaceholder({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'track' ? Icons.music_off : Icons.playlist_remove,
            size: 16,
            color: Colors.white38,
          ),
          const SizedBox(width: 8),
          const Text(
            'Content no longer available',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusTick extends StatelessWidget {
  final String? status;

  const _StatusTick({super.key, required this.status});

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
