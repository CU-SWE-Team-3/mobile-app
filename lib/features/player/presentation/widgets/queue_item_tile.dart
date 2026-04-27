import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/player_track.dart';

/// A single row in the queue list.
///
/// Purely presentational — all interaction is delegated via callbacks so this
/// widget holds zero Riverpod reads and is trivially testable.
class QueueItemTile extends StatelessWidget {
  final PlayerTrack track;

  /// 0-based position in the queue list (used for the track-number label).
  final int index;

  /// Whether this is the currently-playing track (drives colour accent).
  final bool isCurrentTrack;

  final VoidCallback onTap;
  final VoidCallback onRemove;

  const QueueItemTile({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrentTrack,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCurrentTrack
          ? const Color(0xFF242424)
          : const Color(0xFF111111),
      child: InkWell(
        key: const ValueKey('queue_item_tile'),
        onTap: onTap,
        splashColor: Colors.white10,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // ── Track-number / equaliser icon ──────────────────────────
              SizedBox(
                width: 28,
                child: isCurrentTrack
                    ? const Icon(
                        Icons.equalizer,
                        color: Color(0xFFFF5500),
                        size: 18,
                      )
                    : Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(width: 10),

              // ── Cover art ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: track.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: track.coverUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _coverFallback(),
                        errorWidget: (_, __, ___) => _coverFallback(),
                      )
                    : _coverFallback(),
              ),
              const SizedBox(width: 12),

              // ── Title + artist ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrentTrack
                            ? const Color(0xFFFF5500)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Remove button ──────────────────────────────────────────
              IconButton(
                key: const ValueKey('queue_item_remove_button'),
                icon:
                    const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Remove from queue',
              ),

              // ── Drag handle (ReorderableListView picks this up) ────────
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.white24,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _coverFallback() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
      );
}
