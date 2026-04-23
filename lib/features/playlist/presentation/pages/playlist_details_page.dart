import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playlist.dart';
import '../../../library/presentation/pages/library_playlists_page.dart';
import '../../../../core/network/dio_client.dart';

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

bool _isMongoId(String id) {
  if (id.length != 24) return false;
  final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
  return hexRegex.hasMatch(id);
}

String _formatDuration(int? seconds) {
  if (seconds == null) return '';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class PlaylistDetailsPage extends ConsumerStatefulWidget {
  final Playlist? playlist;

  const PlaylistDetailsPage({super.key, this.playlist});

  @override
  ConsumerState<PlaylistDetailsPage> createState() =>
      _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends ConsumerState<PlaylistDetailsPage> {
  List<_PlaylistTrack> _tracks = [];
  bool _isLoadingTracks = false;
  String? _firstTrackArtworkUrl;

  @override
  void initState() {
    super.initState();
    final id = widget.playlist?.id;
    if (id != null && _isMongoId(id)) {
      _loadTracks(id);
    }
  }

  Future<void> _loadTracks(String playlistId) async {
    setState(() => _isLoadingTracks = true);
    try {
      final response =
          await dioClient.dio.get('/playlists/$playlistId');
      final raw = response.data['data']['playlist']['tracks'] as List<dynamic>;
      final tracks =
          raw.map((t) => _PlaylistTrack.fromJson(t as Map<String, dynamic>)).toList();
      setState(() {
        _tracks = tracks;
        _firstTrackArtworkUrl = tracks.isNotEmpty ? tracks.first.artworkUrl : null;
        _isLoadingTracks = false;
      });
    } catch (e) {
      debugPrint('[PlaylistDetails] Failed to load tracks: $e');
      setState(() {
        _tracks = [];
        _firstTrackArtworkUrl = null;
        _isLoadingTracks = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);
    Playlist? current;
    if (widget.playlist != null) {
      for (final pl in playlists) {
        if (pl.id == widget.playlist!.id) {
          current = pl;
          break;
        }
      }
      current ??= widget.playlist;
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
              _ArtworkThumbnail(
                playlist: p,
                avatarUrl: resolvedAvatarUrl,
                firstTrackArtworkUrl: _firstTrackArtworkUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Playlist · ${p.trackCount} Tracks · 0:00 · Just now',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _secondary, fontSize: 13),
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
                                fontWeight: FontWeight.w700,
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
          // Action row
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
                  width: 32,
                  height: 32,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shuffle_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.black, size: 36),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Track list
          if (_isLoadingTracks)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(color: Colors.white54)),
            )
          else
            ..._tracks.map(
              (t) => _TrackTile(
                title: t.title,
                artist: t.artistName,
                isPaused: false,
                playCount: _formatPlayCount(t.playCount),
                duration: _formatDuration(t.durationSeconds),
                artworkUrl: t.artworkUrl,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOwnerAvatar(String url) {
    debugPrint('[PlaylistDetails] _buildOwnerAvatar resolved url: "$url"');
    final hasValidUrl =
        url.isNotEmpty && !url.contains('default-avatar');
    if (hasValidUrl) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: _surface,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return const CircleAvatar(
      radius: 18,
      backgroundColor: _surface,
      child: Icon(Icons.person, color: _secondary, size: 18),
    );
  }
}

String _formatPlayCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
  return count.toString();
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
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            _optionRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                ref.read(playlistsProvider.notifier).remove(playlist.id);
                nav.maybePop();
              },
            ),
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

class _TrackTile extends StatelessWidget {
  final String title;
  final String artist;
  final bool isPaused;
  final String? playCount;
  final String? duration;
  final String? artworkUrl;

  const _TrackTile({
    required this.title,
    required this.artist,
    this.isPaused = false,
    this.playCount,
    this.duration,
    this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 80,
              height: 80,
              child: artworkUrl != null && artworkUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: artworkUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF2A2A2A),
                        child: const Center(
                          child: Icon(Icons.music_note,
                              color: Colors.white24, size: 32),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF2A2A2A),
                        child: const Center(
                          child: Icon(Icons.music_note,
                              color: Colors.white24, size: 32),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF2A2A2A),
                      child: const Center(
                        child:
                            Icon(Icons.music_note, color: Colors.white24, size: 32),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
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
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _secondary, fontSize: 13),
                ),
                const SizedBox(height: 3),
                if (isPaused)
                  Row(
                    children: const [
                      Icon(Icons.pause_rounded, color: _secondary, size: 13),
                      SizedBox(width: 4),
                      Text('Paused',
                          style:
                              TextStyle(color: _secondary, fontSize: 12)),
                    ],
                  )
                else
                  Text(
                    '▶ ${playCount ?? '0'} · ${duration ?? '0:00'}',
                    style: const TextStyle(color: _secondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.more_horiz_rounded, color: _secondary, size: 22),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ArtworkThumbnail extends StatelessWidget {
  final Playlist playlist;
  final String avatarUrl;
  final String? firstTrackArtworkUrl;

  const _ArtworkThumbnail({
    required this.playlist,
    required this.avatarUrl,
    this.firstTrackArtworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final p = playlist;
    final hasArtwork = p.artworkUrl != null && p.artworkUrl!.isNotEmpty;
    final hasFirstTrack =
        firstTrackArtworkUrl != null && firstTrackArtworkUrl!.isNotEmpty;
    final hasValidAvatar =
        avatarUrl.isNotEmpty && !avatarUrl.contains('default-avatar');

    ImageProvider? imageProvider;
    if (hasArtwork) {
      imageProvider = CachedNetworkImageProvider(p.artworkUrl!);
    } else if (hasFirstTrack) {
      imageProvider = CachedNetworkImageProvider(firstTrackArtworkUrl!);
    } else if (p.trackCount == 0 && hasValidAvatar) {
      imageProvider = CachedNetworkImageProvider(avatarUrl);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 160,
        height: 160,
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

// ── UI-only track model ───────────────────────────────────────────────────────

class _PlaylistTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final int playCount;
  final int? durationSeconds;

  const _PlaylistTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.artworkUrl,
    required this.playCount,
    this.durationSeconds,
  });

  factory _PlaylistTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'];
    final artistName = artist is Map<String, dynamic>
        ? (artist['displayName'] as String? ?? '')
        : '';
    return _PlaylistTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artistName,
      artworkUrl: json['artworkUrl'] as String?,
      playCount: json['playCount'] as int? ?? 0,
      durationSeconds: json['duration'] as int?,
    );
  }
}
