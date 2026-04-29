import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/engagement/presentation/providers/engagement_provider.dart';
import '../../../../features/library/presentation/pages/library_playlists_page.dart';
import '../../../../features/library/presentation/providers/my_tracks_provider.dart';

/// The result of a user selection in the attachment picker.
typedef AttachmentSelection = ({
  String type,
  String id,
  String? title,
  String? artworkUrl,
});

/// Opens a modal bottom sheet attachment picker and returns the user's
/// selection, or null if dismissed. Call via:
///
/// ```dart
/// final sel = await showAttachmentPicker(context);
/// if (sel != null) { ... }
/// ```
Future<AttachmentSelection?> showAttachmentPicker(BuildContext context) {
  return showModalBottomSheet<AttachmentSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _AttachmentPickerSheet(),
  );
}

class _AttachmentPickerSheet extends ConsumerStatefulWidget {
  const _AttachmentPickerSheet();

  @override
  ConsumerState<_AttachmentPickerSheet> createState() =>
      _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState
    extends ConsumerState<_AttachmentPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _select(AttachmentSelection selection) {
    Navigator.of(context).pop(selection);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Column(
        children: [
          // Drag handle
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Share a track or playlist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFF5500),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'My Tracks'),
              Tab(text: 'Liked'),
              Tab(text: 'Playlists'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MyTracksTab(onSelect: _select),
                _LikedTracksTab(onSelect: _select),
                _PlaylistsTab(onSelect: _select),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── My Tracks tab ─────────────────────────────────────────────────────────────

class _MyTracksTab extends ConsumerWidget {
  final ValueChanged<AttachmentSelection> onSelect;

  const _MyTracksTab({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTracksProvider);
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFF5500))),
      error: (_, __) => const Center(
        child: Text('Failed to load tracks', style: TextStyle(color: Colors.white54)),
      ),
      data: (tracks) {
        final uploadable = tracks.where((t) => t.id != null && t.id!.isNotEmpty).toList();
        if (uploadable.isEmpty) {
          return const Center(
            child: Text('No tracks uploaded yet', style: TextStyle(color: Colors.white54)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: uploadable.length,
          itemBuilder: (_, i) {
            final t = uploadable[i];
            return _TrackTile(
              id: t.id!,
              title: t.title,
              subtitle: t.artist,
              artworkUrl: t.artworkUrl,
              onTap: () => onSelect((
                type: 'track',
                id: t.id!,
                title: t.title,
                artworkUrl: t.artworkUrl,
              )),
            );
          },
        );
      },
    );
  }
}

// ── Liked Tracks tab ──────────────────────────────────────────────────────────

class _LikedTracksTab extends ConsumerWidget {
  final ValueChanged<AttachmentSelection> onSelect;

  const _LikedTracksTab({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mergedUserLikesProvider);
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFF5500))),
      error: (_, __) => const Center(
        child: Text('Failed to load likes', style: TextStyle(color: Colors.white54)),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Center(
            child: Text('No liked tracks yet', style: TextStyle(color: Colors.white54)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tracks.length,
          itemBuilder: (_, i) {
            final t = tracks[i];
            return _TrackTile(
              id: t.id,
              title: t.title,
              subtitle: t.artistName,
              artworkUrl: t.artworkUrl,
              onTap: () => onSelect((
                type: 'track',
                id: t.id,
                title: t.title,
                artworkUrl: t.artworkUrl,
              )),
            );
          },
        );
      },
    );
  }
}

// ── Playlists tab ─────────────────────────────────────────────────────────────

class _PlaylistsTab extends ConsumerWidget {
  final ValueChanged<AttachmentSelection> onSelect;

  const _PlaylistsTab({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    if (playlists.isEmpty) {
      return const Center(
        child: Text('No playlists yet', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: playlists.length,
      itemBuilder: (_, i) {
        final p = playlists[i];
        final artwork = p.artworkUrl ?? p.firstTrackArtworkUrl;
        return _TrackTile(
          id: p.id,
          title: p.title,
          subtitle: '${p.trackCount} track${p.trackCount == 1 ? '' : 's'}',
          artworkUrl: artwork,
          isPlaylist: true,
          onTap: () => onSelect((
            type: 'playlist',
            id: p.id,
            title: p.title,
            artworkUrl: artwork,
          )),
        );
      },
    );
  }
}

// ── Shared tile ───────────────────────────────────────────────────────────────

class _TrackTile extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  final String? artworkUrl;
  final bool isPlaylist;
  final VoidCallback onTap;

  const _TrackTile({
    required this.id,
    required this.title,
    required this.subtitle,
    this.artworkUrl,
    this.isPlaylist = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasArtwork = artworkUrl != null &&
        artworkUrl!.isNotEmpty &&
        artworkUrl!.startsWith('http');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: hasArtwork
                    ? CachedNetworkImage(
                        imageUrl: artworkUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline_rounded,
                color: Color(0xFFFF5500), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => ColoredBox(
        color: const Color(0xFF2A2A2A),
        child: Center(
          child: Icon(
            isPlaylist ? Icons.queue_music : Icons.music_note,
            color: Colors.white38,
            size: 20,
          ),
        ),
      );
}
