import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
class PlaylistOptionsSheet extends ConsumerStatefulWidget {
  final Playlist playlist;
  final bool showCopyOption;
  final bool popPageOnDelete;
  final bool canManage;

  const PlaylistOptionsSheet({
    super.key,
    required this.playlist,
    this.showCopyOption = false,
    this.popPageOnDelete = false,
    this.canManage = true,
  });

  @override
  ConsumerState<PlaylistOptionsSheet> createState() =>
      _PlaylistOptionsSheetState();
}

class _PlaylistOptionsSheetState extends ConsumerState<PlaylistOptionsSheet> {
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('avatarUrl') ?? '';
    if (mounted) setState(() => _avatarUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final showCopyOption = widget.showCopyOption;
    final popPageOnDelete = widget.popPageOnDelete;
    final canManage = widget.canManage;
    final media = MediaQuery.of(context);
    final thumbnailUrl = _resolvedThumbnailUrl(playlist);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: 12,
            bottom: 132 + media.padding.bottom,
          ),
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
                        child: thumbnailUrl != null
                            ? Image.network(thumbnailUrl, fit: BoxFit.cover)
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
                            style: const TextStyle(
                                color: _secondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 28),
              if (canManage) ...[
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
                  key: const ValueKey('playlist_delete_button'),
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
              ],
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
                    isScrollControlled: true,
                    builder: (_) => SharePlaylistSheet(playlist: playlist),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolvedThumbnailUrl(Playlist playlist) {
    if (_isUsableArtworkUrl(playlist.artworkUrl)) return playlist.artworkUrl;
    if (playlist.trackCount > 0) {
      return _isUsableArtworkUrl(playlist.firstTrackArtworkUrl)
          ? playlist.firstTrackArtworkUrl
          : null;
    }
    return _isUsableAvatarUrl(_avatarUrl) ? _avatarUrl : null;
  }

  bool _isUsableArtworkUrl(String? url) =>
      url != null &&
      url.isNotEmpty &&
      url.startsWith('http') &&
      !url.contains('default');

  bool _isUsableAvatarUrl(String? url) =>
      url != null &&
      url.isNotEmpty &&
      url.startsWith('http') &&
      !url.contains('default-avatar');

  Widget _optionRow({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 16),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      );
}
