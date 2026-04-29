import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../domain/entities/participant.dart';
import '../providers/messaging_providers.dart';

// ── Shareable item type ───────────────────────────────────────────────────────

sealed class ShareableItem {
  const ShareableItem();
  String get attachmentType;
  String get attachmentId;
}

class ShareableTrack extends ShareableItem {
  final String id;
  const ShareableTrack(this.id);
  @override
  String get attachmentType => 'track';
  @override
  String get attachmentId => id;
}

class ShareablePlaylist extends ShareableItem {
  final String id;
  const ShareablePlaylist(this.id);
  @override
  String get attachmentType => 'playlist';
  @override
  String get attachmentId => id;
}

// ── Entry-point helper ────────────────────────────────────────────────────────

Future<void> showSendToSheet(BuildContext context, ShareableItem item) =>
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SendToSheet(item: item),
    );

// ── Sheet widget ──────────────────────────────────────────────────────────────

class SendToSheet extends ConsumerStatefulWidget {
  final ShareableItem item;

  const SendToSheet({super.key, required this.item});

  @override
  ConsumerState<SendToSheet> createState() => _SendToSheetState();
}

class _SendToSheetState extends ConsumerState<SendToSheet> {
  String? _sendingTo;

  Future<void> _send(Participant participant) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = participant.id);

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      await ref.read(messagingRepositoryProvider).sendMessage(
            receiverId: participant.id,
            attachmentType: widget.item.attachmentType,
            attachmentId: widget.item.attachmentId,
          );
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sent to ${participant.displayName}'),
          backgroundColor: const Color(0xFF333333),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingTo = null);
      final isPrivate = e.runtimeType.toString() == 'PrivateAttachmentException';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isPrivate
                ? 'This track is private and cannot be shared'
                : 'Failed to send — please try again',
          ),
          backgroundColor: const Color(0xFFCC3333),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(sessionUserIdProvider);
    final conversationsAsync = ref.watch(conversationsProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'SEND TO',
                style: TextStyle(
                  color: Color(0xFFB6B6B6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            conversationsAsync.when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF5500),
                    strokeWidth: 2,
                  ),
                ),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Could not load recent conversations',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              data: (conversations) {
                final contacts = <Participant>[];
                for (final conv in conversations) {
                  final other = conv.participants
                      .where((p) => p.id != myId && p.id.isNotEmpty)
                      .firstOrNull;
                  if (other != null) contacts.add(other);
                  if (contacts.length == 6) break;
                }

                if (contacts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'No recent conversations',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: contacts.map((p) {
                      final isSending = _sendingTo == p.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: GestureDetector(
                          onTap: isSending ? null : () => _send(p),
                          child: SizedBox(
                            width: 60,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _ContactAvatar(
                                      avatarUrl: p.avatarUrl,
                                      name: p.displayName,
                                    ),
                                    if (isSending)
                                      const CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.black54,
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  p.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Avatar widget ─────────────────────────────────────────────────────────────

class _ContactAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;

  const _ContactAvatar({this.avatarUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final isValid = avatarUrl != null &&
        avatarUrl!.isNotEmpty &&
        avatarUrl!.startsWith('http');
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF3A3A3A),
      backgroundImage:
          isValid ? CachedNetworkImageProvider(avatarUrl!) : null,
      child: !isValid
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            )
          : null,
    );
  }
}
