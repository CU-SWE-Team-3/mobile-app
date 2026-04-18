import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playlist.dart';
import '../../../library/presentation/pages/library_playlists_page.dart';

final _avatarUrlProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final allKeys = prefs.getKeys();
  final value = prefs.getString('avatarUrl') ?? '';
  debugPrint('[PlaylistDetails] SharedPreferences keys: $allKeys');
  debugPrint('[PlaylistDetails] avatarUrl value: "$value"');
  return value;
});

const _bg = Color(0xFF111111);
const _surface = Color(0xFF1F1F1F);
const _secondary = Color(0xFF999999);

class PlaylistDetailsPage extends ConsumerWidget {
  final Playlist? playlist;

  const PlaylistDetailsPage({super.key, this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always read the live version from the provider so visibility changes
    // and deletions reflect immediately. Falls back to the constructor arg
    // while the provider's async _load() is still completing.
    final playlists = ref.watch(playlistsProvider);
    Playlist? current;
    if (playlist != null) {
      for (final pl in playlists) {
        if (pl.id == playlist!.id) {
          current = pl;
          break;
        }
      }
      current ??= playlist;
    }

    if (current == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          title: const Text('Playlist', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('No playlist selected',
              style: TextStyle(color: _secondary, fontSize: 16)),
        ),
      );
    }

    final p = current;
    final avatarAsync = ref.watch(_avatarUrlProvider);
    final resolvedAvatarUrl = avatarAsync.maybeWhen(
      data: (url) => url,
      orElse: () => '',
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Playlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),
          // Compact header: thumbnail left, metadata right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square artwork thumbnail
              _ArtworkThumbnail(playlist: p, avatarUrl: resolvedAvatarUrl),
              const SizedBox(width: 14),
              // Metadata column
              Expanded(
                child: SizedBox(
                  height: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Subtitle: Playlist · N Tracks · 0:00 · Just now [lock]
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Playlist · ${p.trackCount} Tracks · 0:00 · Just now',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _secondary, fontSize: 12),
                            ),
                          ),
                          if (!p.isPublic)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.lock_rounded,
                                  color: _secondary, size: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Owner row
                      Row(
                        children: [
                          _buildOwnerAvatar(resolvedAvatarUrl),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'By ${p.ownerName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
          const SizedBox(height: 16),
          // Action row: three-dot left, shuffle + play right
          Row(
            children: [
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: _surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => _PlaylistOptionsSheet(playlist: p),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_horiz_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shuffle_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.black, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tracks area — empty when no tracks
        ],
      ),
    );
  }

  Widget _buildOwnerAvatar(String url) {
    final hasValidUrl =
        url.isNotEmpty && !url.contains('default-avatar');
    if (hasValidUrl) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: _surface,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return const CircleAvatar(
      radius: 16,
      backgroundColor: _surface,
      child: Icon(Icons.person, color: _secondary, size: 18),
    );
  }
}

// ── Playlist options sheet ────────────────────────────────────────────────────

class _PlaylistOptionsSheet extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistOptionsSheet({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header: artwork + title/owner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: playlist.artworkUrl != null
                          ? Image.network(playlist.artworkUrl!,
                              fit: BoxFit.cover)
                          : const ColoredBox(
                              color: Color(0xFF2A2A2A),
                              child: Center(
                                child: Icon(Icons.music_note,
                                    color: Colors.white38, size: 32),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          playlist.ownerName,
                          style: const TextStyle(
                              color: _secondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 28),
            // Edit
            _optionRow(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming soon'),
                    backgroundColor: _surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            // Make private / Make public
            _optionRow(
              icon: Icons.lock_outline,
              label: playlist.isPublic ? 'Make private' : 'Make public',
              onTap: () {
                Navigator.pop(context);
                ref.read(playlistsProvider.notifier).updateVisibility(
                      playlist.id,
                      !playlist.isPublic,
                    );
              },
            ),
            // Delete
            _optionRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop(); // close sheet
                ref.read(playlistsProvider.notifier).remove(playlist.id);
                nav.maybePop(); // go back to playlists list
              },
            ),
            // Copy playlist
            _optionRow(
              icon: Icons.copy_rounded,
              label: 'Copy playlist',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming soon'),
                    backgroundColor: _surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 16),
              Text(label,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ArtworkThumbnail extends StatelessWidget {
  final Playlist playlist;
  final String avatarUrl;

  const _ArtworkThumbnail({required this.playlist, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final p = playlist;
    final hasArtwork =
        p.artworkUrl != null && p.artworkUrl!.isNotEmpty;
    final hasValidAvatar =
        avatarUrl.isNotEmpty && !avatarUrl.contains('default-avatar');

    ImageProvider? imageProvider;
    if (hasArtwork) {
      imageProvider = CachedNetworkImageProvider(p.artworkUrl!);
    } else if (p.trackCount == 0 && hasValidAvatar) {
      imageProvider = CachedNetworkImageProvider(avatarUrl);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 130,
        height: 130,
        color: _surface,
        child: imageProvider != null
            ? Image(image: imageProvider, fit: BoxFit.cover)
            : const Center(
                child: Icon(Icons.music_note,
                    color: Colors.white24, size: 48),
              ),
      ),
    );
  }
}
