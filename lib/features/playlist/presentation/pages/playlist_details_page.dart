import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playlist.dart';
import '../../../library/presentation/pages/library_playlists_page.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../../core/network/dio_client.dart';
import 'share_playlist_page.dart';

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

String _formatDuration(int? seconds) {
  if (seconds == null) return '';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class PlaylistDetailsPage extends ConsumerStatefulWidget {
  final Playlist? playlist;
  final String? playlistId;

  const PlaylistDetailsPage({super.key, this.playlist, this.playlistId});

  @override
  ConsumerState<PlaylistDetailsPage> createState() =>
      _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends ConsumerState<PlaylistDetailsPage> {
  List<_PlaylistTrack> _tracks = [];
  bool _isLoadingTracks = false;
  String? _firstTrackArtworkUrl;
  bool _isShuffleActive = false;
  Playlist? _fetchedPlaylist;

  @override
  void initState() {
    super.initState();
    final id = widget.playlistId ?? widget.playlist?.id;
    if (id != null && id.isNotEmpty) {
      _loadTracks(id);
    }
  }

  Future<void> _loadTracks(String playlistId) async {
    setState(() => _isLoadingTracks = true);
    try {
      final response = await dioClient.dio.get('/playlists/$playlistId');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final playlistData = data['playlist'] as Map<String, dynamic>? ?? {};

      // When navigated by playlistId only (no Playlist object passed), build
      // one from the response so the page can render title/artwork/owner.
      if (widget.playlist == null) {
        final creator = playlistData['creator'] as Map<String, dynamic>?;
        final fetched = Playlist(
          id: playlistId,
          title: playlistData['title'] as String? ?? '',
          artworkUrl: playlistData['artworkUrl'] as String?,
          ownerName: (playlistData['ownerName'] as String?) ??
              (creator?['displayName'] as String?) ??
              '',
          trackCount: (playlistData['trackCount'] as num?)?.toInt() ?? 0,
          isPublic: playlistData['isPublic'] as bool? ?? true,
        );
        if (mounted) setState(() => _fetchedPlaylist = fetched);
      }

      final rawTracks = (playlistData['tracks'] as List<dynamic>?) ?? [];
      // Entries can be populated objects or bare String IDs — keep only Maps.
      final tracks = rawTracks
          .whereType<Map<String, dynamic>>()
          .map(_PlaylistTrack.fromJson)
          .toList();
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
    // Fallback: playlist fetched by id when navigated from profile
    current ??= _fetchedPlaylist;

    if (current == null) {
      if (_isLoadingTracks) {
        return const Scaffold(
          backgroundColor: _bg,
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5500)),
          ),
        );
      }
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

    // Resolve artwork image: playlist artwork → first track artwork → user avatar
    final hasArtwork = p.artworkUrl != null && p.artworkUrl!.isNotEmpty;
    final hasFirstTrack =
        _firstTrackArtworkUrl != null && _firstTrackArtworkUrl!.isNotEmpty;
    final hasValidAvatar = resolvedAvatarUrl.isNotEmpty &&
        !resolvedAvatarUrl.contains('default-avatar');

    Widget artworkWidget;
    if (hasArtwork) {
      artworkWidget = CachedNetworkImage(
        imageUrl: p.artworkUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 300,
        placeholder: (_, __) => const _ArtworkPlaceholder(),
        errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
      );
    } else if (hasFirstTrack) {
      artworkWidget = CachedNetworkImage(
        imageUrl: _firstTrackArtworkUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 300,
        placeholder: (_, __) => const _ArtworkPlaceholder(),
        errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
      );
    } else if (p.trackCount == 0 && hasValidAvatar) {
      artworkWidget = CachedNetworkImage(
        imageUrl: resolvedAvatarUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 300,
        placeholder: (_, __) => const _ArtworkPlaceholder(),
        errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
      );
    } else {
      artworkWidget = const _ArtworkPlaceholder();
    }

    final canPlay = !_isLoadingTracks &&
        _tracks.any((t) => t.hlsUrl != null && t.hlsUrl!.isNotEmpty);

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Hero artwork with title overlaid ──────────────────────────────
          Stack(
            children: [
              artworkWidget,
              // Gradient: dark at top (back button legibility) → clear → dark at bottom (title)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black54,
                        Colors.transparent,
                        _bg.withValues(alpha: 0.65),
                        _bg,
                      ],
                      stops: const [0.0, 0.3, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // Title + privacy lock at bottom of artwork
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ),
                    if (!p.isPublic)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 2),
                        child: Icon(Icons.lock_rounded,
                            color: Colors.white70, size: 16),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // ── Creator row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _buildOwnerAvatar(resolvedAvatarUrl),
                const SizedBox(width: 8),
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
          ),
          // ── Action row (three-dot · shuffle · play) ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
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
                // Shuffle
                GestureDetector(
                  onTap: canPlay
                      ? () {
                          setState(() => _isShuffleActive = !_isShuffleActive);
                          if (_isShuffleActive) _shufflePlay();
                        }
                      : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isShuffleActive
                          ? const Color(0xFFFF5500).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shuffle_rounded,
                      color: !canPlay
                          ? Colors.white30
                          : _isShuffleActive
                              ? const Color(0xFFFF5500)
                              : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Play
                GestureDetector(
                  onTap: canPlay ? () => _playFrom(0) : null,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: canPlay ? Colors.white : Colors.white30,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: canPlay ? Colors.black : Colors.black38,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Track list ────────────────────────────────────────────────────
          if (_isLoadingTracks)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
            )
          else
            ...List.generate(_tracks.length, (i) {
              final t = _tracks[i];
              return _TrackTile(
                title: t.title,
                artist: t.artistName,
                isPaused: false,
                playCount: _formatPlayCount(t.playCount),
                duration: _formatDuration(t.durationSeconds),
                artworkUrl: t.artworkUrl,
                onTap: t.hlsUrl != null ? () => _playFrom(i) : null,
              );
            }),
        ],
      ),
    );
  }

  void _shufflePlay() {
    final playableIndices = [
      for (var i = 0; i < _tracks.length; i++)
        if (_tracks[i].hlsUrl != null && _tracks[i].hlsUrl!.isNotEmpty) i,
    ];
    if (playableIndices.isEmpty) return;
    final randomIdx = playableIndices[Random().nextInt(playableIndices.length)];
    _playFrom(randomIdx);
  }

  void _playFrom(int tappedIndex) {
    final tappedId = _tracks[tappedIndex].id;
    final queue = _tracks
        .where((t) => t.hlsUrl != null && t.hlsUrl!.isNotEmpty)
        .map((t) => PlayerTrack(
              id: t.id,
              title: t.title,
              artist: t.artistName,
              audioUrl: t.hlsUrl!,
              coverUrl: t.artworkUrl,
              duration: t.durationSeconds != null
                  ? Duration(seconds: t.durationSeconds!)
                  : null,
            ))
        .toList();
    if (queue.isEmpty) return;
    final queueIndex =
        queue.indexWhere((t) => t.id == tappedId).clamp(0, queue.length - 1);
    ref.read(playerProvider.notifier).playQueue(queue, startIndex: queueIndex);
  }

  Widget _buildOwnerAvatar(String url) {
    debugPrint('[PlaylistDetails] _buildOwnerAvatar resolved url: "$url"');
    final hasValidUrl = url.isNotEmpty && !url.contains('default-avatar');
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

// ── Playlist options sheet (from detail page) ─────────────────────────────────

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

// ── Track tile ────────────────────────────────────────────────────────────────

class _TrackTile extends StatelessWidget {
  final String title;
  final String artist;
  final bool isPaused;
  final String? playCount;
  final String? duration;
  final String? artworkUrl;
  final VoidCallback? onTap;

  const _TrackTile({
    required this.title,
    required this.artist,
    this.isPaused = false,
    this.playCount,
    this.duration,
    this.artworkUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white10,
      highlightColor: Colors.white10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: artworkUrl != null && artworkUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: artworkUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ColoredBox(
                          color: Color(0xFF2A2A2A),
                          child: Center(
                            child: Icon(Icons.music_note,
                                color: Colors.white24, size: 24),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF2A2A2A),
                          child: Center(
                            child: Icon(Icons.music_note,
                                color: Colors.white24, size: 24),
                          ),
                        ),
                      )
                    : const ColoredBox(
                        color: Color(0xFF2A2A2A),
                        child: Center(
                          child: Icon(Icons.music_note,
                              color: Colors.white24, size: 24),
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
                    const Row(
                      children: [
                        Icon(Icons.pause_rounded, color: _secondary, size: 13),
                        SizedBox(width: 4),
                        Text('Paused',
                            style: TextStyle(color: _secondary, fontSize: 12)),
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
      ),
    );
  }
}

// ── Artwork placeholder ───────────────────────────────────────────────────────

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: double.infinity,
        height: 300,
        child: ColoredBox(
          color: _surface,
          child: Center(
            child: Icon(Icons.music_note, color: Colors.white24, size: 64),
          ),
        ),
      );
}

// ── UI-only track model ───────────────────────────────────────────────────────

class _PlaylistTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final String? hlsUrl;
  final int playCount;
  final int? durationSeconds;

  const _PlaylistTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.artworkUrl,
    this.hlsUrl,
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
      hlsUrl: json['hlsUrl'] as String? ??
          json['audioUrl'] as String? ??
          json['streamUrl'] as String?,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration'] as num?)?.toInt(),
    );
  }
}
