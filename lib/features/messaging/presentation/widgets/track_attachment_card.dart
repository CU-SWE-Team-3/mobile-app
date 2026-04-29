import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/attachment.dart';

/// Rich in-chat preview card for track attachments.
///
/// Tapping anywhere on the card delegates to [onTap]; the play button is a
/// visual affordance only and does not register a separate gesture.
class TrackAttachmentCard extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onTap;

  const TrackAttachmentCard({
    super.key,
    required this.attachment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!attachment.isAvailable) {
      return _UnavailableTrackCard();
    }

    final hasArtwork = attachment.artworkUrl != null &&
        attachment.artworkUrl!.isNotEmpty &&
        attachment.artworkUrl!.startsWith('http');

    final title = (attachment.title?.trim().isNotEmpty == true)
        ? attachment.title!
        : 'Unknown Track';

    final artistName = (attachment.artistName?.trim().isNotEmpty == true)
        ? attachment.artistName
        : null;

    final duration = attachment.duration;

    return GestureDetector(
      key: const ValueKey('message_track_card'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3A3A3A)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Artwork with play-button overlay ──────────────────────────
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasArtwork
                      ? CachedNetworkImage(
                          imageUrl: attachment.artworkUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _artworkFallback(),
                          errorWidget: (_, __, ___) => _artworkFallback(),
                        )
                      : _artworkFallback(),
                  Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Text section ──────────────────────────────────────────────
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (artistName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    // ── Metadata row: duration · type badge ───────────────
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (duration != null) ...[
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        const Icon(
                          Icons.music_note_rounded,
                          size: 10,
                          color: Color(0xFFFF5500),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          'Track',
                          style: TextStyle(
                            color: Color(0xFFFF5500),
                            fontSize: 10,
                          ),
                        ),
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

  static Widget _artworkFallback() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white24,
            size: 24,
          ),
        ),
      );

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _UnavailableTrackCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_off, size: 16, color: Colors.white38),
          SizedBox(width: 8),
          Text(
            'Content no longer available',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
