import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/playlist/presentation/providers/playlist_providers.dart';
import '../../domain/entities/attachment.dart';

/// Renders an embedded mini-card for a track or playlist attachment.
///
/// Tracks render directly from the metadata snapshot carried on [attachment]
/// (populated at send time from AttachmentPickerItem, or from inline server
/// fields on the receive side). No network fetch needed for tracks.
///
/// Playlists still use [playlistByIdProvider] because GET /playlists/{id}
/// is a working endpoint on the real backend.
class AttachmentCard extends ConsumerWidget {
  final Attachment attachment;

  const AttachmentCard({super.key, required this.attachment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachment.type == 'track') {
      final title = attachment.title;
      if (title == null || title.isEmpty) {
        return const _CardFallback(label: 'Track unavailable');
      }
      return _CardLoaded(
        artworkUrl: attachment.artworkUrl,
        title: title,
        subtitle: attachment.subtitle ?? '',
        icon: Icons.music_note_rounded,
      );
    } else {
      // 'playlist'
      final async = ref.watch(playlistByIdProvider(attachment.referenceId));
      return async.when(
        loading: () => const _CardSkeleton(),
        error: (_, __) => const _CardFallback(label: 'Playlist unavailable'),
        data: (playlist) => _CardLoaded(
          artworkUrl: playlist.artworkUrl,
          title: playlist.title,
          subtitle: playlist.ownerName,
          icon: Icons.queue_music_rounded,
        ),
      );
    }
  }
}

// ── Shared card frame ─────────────────────────────────────────────────────────

BoxDecoration _cardDecoration() => BoxDecoration(
      color: const Color(0xFF333333),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF444444)),
    );

// ── Loaded state ──────────────────────────────────────────────────────────────

class _CardLoaded extends StatelessWidget {
  final String? artworkUrl;
  final String title;
  final String subtitle;
  final IconData icon;

  const _CardLoaded({
    required this.artworkUrl,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasArtwork = artworkUrl != null &&
        artworkUrl!.isNotEmpty &&
        !artworkUrl!.contains('default-artwork');

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Artwork square
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: hasArtwork
                ? CachedNetworkImage(
                    imageUrl: artworkUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _artworkPlaceholder(icon),
                  )
                : _artworkPlaceholder(icon),
          ),
          const SizedBox(width: 10),
          // Title + artist/owner
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _artworkPlaceholder(IconData icon) => Container(
      width: 48,
      height: 48,
      color: const Color(0xFF444444),
      child: Icon(icon, color: Colors.white38, size: 20),
    );

// ── Skeleton (loading) state ──────────────────────────────────────────────────

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Artwork placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar
              Container(
                width: 110,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              // Subtitle bar
              Container(
                width: 74,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error / fallback state ────────────────────────────────────────────────────

class _CardFallback extends StatelessWidget {
  final String label;

  const _CardFallback({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
