import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/playlist.dart';
import '../pages/share_playlist_page.dart';
import '../providers/playlists_provider.dart';

const _surface = Color(0xFF1F1F1F);
const _secondary = Color(0xFF999999);

/// Shared options sheet for a playlist. Used from both LibraryPlaylistsPage
/// (three-dot on playlist tile) and PlaylistDetailsPage (three-dot in header).
///
/// [showCopyOption] — include the "Copy playlist" row (shown on details page).
/// [popPageOnDelete] — pop the host page after a confirmed delete (true on
///   details page so the user doesn't land on a deleted-playlist view).
class PlaylistOptionsSheet extends ConsumerWidget {
  final Playlist playlist;
  final bool showCopyOption;
  final bool popPageOnDelete;

  const PlaylistOptionsSheet({
    super.key,
    required this.playlist,
    this.showCopyOption = false,
    this.popPageOnDelete = false,
  });

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
            // Header: thumbnail + title/owner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: playlist.artworkUrl != null
                          ? Image.network(playlist.artworkUrl!,
                              fit: BoxFit.cover)
                          : const ColoredBox(
                              color: Color(0xFF2A2A2A),
                              child: Center(
                                child: Icon(Icons.music_note,
                                    color: Colors.white38, size: 24),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          playlist.ownerName,
                          style:
                              const TextStyle(color: _secondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 28),
            // Edit playlist
            _optionRow(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.push('/playlist/edit', extra: playlist);
              },
            ),
            // Privacy settings — navigates to full privacy page
            _optionRow(
              icon: Icons.shield_outlined,
              label: 'Privacy settings',
              onTap: () {
                Navigator.pop(context);
                context.push('/playlist/privacy', extra: playlist);
              },
            ),
            // Delete
            _optionRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              onTap: () {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final shouldPopPage = popPageOnDelete;
                nav.pop();
                ref
                    .read(playlistsProvider.notifier)
                    .remove(playlist.id)
                    .then((_) {
                  if (shouldPopPage) {
                    nav.maybePop();
                  } else {
                    messenger.showSnackBar(const SnackBar(
                      content: Text('Playlist deleted'),
                      backgroundColor: _surface,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }).catchError((_) {
                  messenger.showSnackBar(const SnackBar(
                    content: Text(
                        'Could not delete playlist. Please try again.'),
                    backgroundColor: Color(0xFF3A1A1A),
                    behavior: SnackBarBehavior.floating,
                  ));
                });
              },
            ),
            // Copy playlist (details page only)
            if (showCopyOption)
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
            // Share
            _optionRow(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: _surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => SharePlaylistSheet(playlist: playlist),
                );
              },
            ),
            // Clearance for mini player (64dp height + 8dp bottom margin)
            const SizedBox(height: 72),
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
