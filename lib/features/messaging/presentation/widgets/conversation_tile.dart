import 'package:flutter/material.dart';

import '../../../../core/utils/relative_time.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/participant.dart';
import 'participant_avatar.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final Participant otherParticipant;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.otherParticipant,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastMsg = conversation.lastMessage;
    final isOwnLast = lastMsg?.senderId == currentUserId;

    final unread = conversation.unreadCount;
    final hasUnread = unread > 0;

    final preview = lastMsg == null
        ? ''
        : isOwnLast
            ? 'You: ${lastMsg.content}'
            : lastMsg.content;

    final timestamp =
        lastMsg != null ? formatRelativeTime(lastMsg.createdAt) : '';

    // Cap badge label at 99+; use 4+ for counts in the 5–99 range per spec.
    final badgeLabel = unread > 99
        ? '99+'
        : unread > 4
            ? '4+'
            : '$unread';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ParticipantAvatar(
              avatarUrl: otherParticipant.avatarUrl,
              displayName: otherParticipant.displayName,
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherParticipant.displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: hasUnread
                              ? const Color(0xFFFF5500)
                              : Colors.white54,
                          fontSize: 12,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          style: TextStyle(
                            color: hasUnread ? Colors.white70 : Colors.white54,
                            fontSize: 13,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5500),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
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
