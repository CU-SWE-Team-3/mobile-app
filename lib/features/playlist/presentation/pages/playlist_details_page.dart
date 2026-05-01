import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/session_provider.dart';
import '../../domain/entities/playlist.dart';
import '../providers/playlists_provider.dart';
import '../widgets/playlist_options_sheet.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../engagement/presentation/providers/engagement_provider.dart';
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
  String _ownerAvatarUrl = '';
  // Locked while a reorder or remove API call is in flight.
  // Prevents concurrent mutations that would race on the server's track array.
  bool _isOperationInFlight = false;

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
      final rawPlaylist = data['playlist'];
      final playlistData =
          rawPlaylist is Map ? Map<String, dynamic>.from(rawPlaylist) : data;

      // When navigated by playlistId only (no Playlist object passed), build
      // one from the response so the page can render title/artwork/owner.
      if (widget.playlist == null) {
        final creatorRaw = playlistData['creator'];
        final creator = creatorRaw is Map
            ? Map<String, dynamic>.from(creatorRaw)
            : <String, dynamic>{};
        final fetched = Playlist(
          id: playlistId,
          title: playlistData['title'] as String? ?? '',
          artworkUrl: playlistData['artworkUrl'] as String?,
          ownerName: (playlistData['ownerName'] as String?) ??
              (creator['displayName'] as String?) ??
              '',
          trackCount: (playlistData['trackCount'] as num?)?.toInt() ?? 0,
          isPublic: playlistData['isPublic'] as bool? ?? true,
          permalink: playlistData['permalink'] as String?,
          ownerPermalink: creator['permalink'] as String?,
          creatorId: (creator['_id'] ?? creator['id']) as String?,
        );
        if (mounted) {
          setState(() {
            _fetchedPlaylist = fetched;
            _ownerAvatarUrl = (creator['avatarUrl'] ??
                    creator['profileImageUrl'] ??
                    creator['photoUrl'] ??
                    '')
                .toString();
          });
        }
      }

      final rawTracks = (playlistData['tracks'] as List<dynamic>?) ?? [];
      // Entries can be populated objects or bare String IDs — keep only Maps.
      final tracks = rawTracks
          .whereType<Map<String, dynamic>>()
          .map(_PlaylistTrack.fromJson)
          .toList();
      setState(() {
        _tracks = tracks;
        _firstTrackArtworkUrl =
            tracks.isNotEmpty ? tracks.first.artworkUrl : null;
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

  // ── Reorder ────────────────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    if (_isOperationInFlight) return;
    if (!_isCurrentPlaylistOwned()) return;
    // SliverReorderableList passes newIndex in the list after the item is
    // removed; adjust so removeAt + insert lands at the intended position.
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final prevTracks = List<_PlaylistTrack>.from(_tracks);
    setState(() {
      final moved = _tracks.removeAt(oldIndex);
      _tracks.insert(newIndex, moved);
      _isOperationInFlight = true;
    });

    _doReorderApi(prevTracks); // fire-and-forget
  }

  Future<void> _doReorderApi(List<_PlaylistTrack> prevTracks) async {
    final playlistId =
        widget.playlistId ?? widget.playlist?.id ?? _fetchedPlaylist?.id;
    if (playlistId == null || playlistId.isEmpty) {
      if (mounted) {
        setState(() {
          _tracks = prevTracks;
          _isOperationInFlight = false;
        });
      }
      return;
    }
    try {
      await ref.read(playlistRepositoryProvider).reorderTracks(
            playlistId,
            _tracks.map((t) => t.id).toList(),
          );
    } catch (_) {
      if (mounted) {
        setState(() => _tracks = prevTracks);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to reorder tracks. Please try again.'),
          backgroundColor: Color(0xFF3A1A1A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isOperationInFlight = false);
    }
  }

  // ── Remove ─────────────────────────────────────────────────────────────────

  void _showTrackActions(_PlaylistTrack track) {
    if (!_isCurrentPlaylistOwned()) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                key: const ValueKey('playlist_remove_track_button'),
                leading: const Icon(Icons.remove_circle_outline,
                    color: Colors.white),
                title: const Text('Remove from playlist',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _removeTrack(track);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeTrack(_PlaylistTrack track) async {
    if (_isOperationInFlight) return;
    if (!_isCurrentPlaylistOwned()) return;
    final playlistId =
        widget.playlistId ?? widget.playlist?.id ?? _fetchedPlaylist?.id;
    if (playlistId == null || playlistId.isEmpty) return;

    final prevTracks = List<_PlaylistTrack>.from(_tracks);
    setState(() {
      _tracks.removeWhere((t) => t.id == track.id);
      _isOperationInFlight = true;
    });

    try {
      final newCount = await ref
          .read(playlistRepositoryProvider)
          .removeTrack(playlistId, track.id);
      if (mounted) {
        ref
            .read(playlistsProvider.notifier)
            .updateTrackCount(playlistId, newCount);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _tracks = prevTracks);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to remove track. Please try again.'),
          backgroundColor: Color(0xFF3A1A1A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isOperationInFlight = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);
    final userId = ref.watch(sessionUserIdProvider);
    final playerState = ref.watch(playerProvider);
    final likedPlaylistsAsync = ref.watch(likedPlaylistsProvider);
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
          leading: IconButton(
            key: const ValueKey('playlist_back_button'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: const Center(
          child: Text('No playlist selected',
              style: TextStyle(color: _secondary, fontSize: 16)),
        ),
      );
    }

    final p = current;
    final isOwner = _isPlaylistOwned(
      p,
      userId: userId,
      ownedPlaylists: playlists,
    );

    final isInitiallyLiked = likedPlaylistsAsync.maybeWhen(
      data: (list) => list.any((pl) => pl.id == p.id),
      orElse: () => false,
    );
    final playlistEngParams = EngagementParams(
      trackId: p.id,
      targetModel: 'Playlist',
      isLiked: isInitiallyLiked,
    );
    final playlistEngState = ref.watch(engagementProvider(playlistEngParams));

    final currentTrackId = playerState.currentTrack?.id;
    final isThisPlaylistPlaying = currentTrackId != null &&
        _tracks.any((t) => t.id == currentTrackId && t.id.isNotEmpty);
    final showPausePlaying = isThisPlaylistPlaying && playerState.isPlaying;
    final avatarAsync = ref.watch(_avatarUrlProvider);
    final currentUserAvatarUrl = avatarAsync.maybeWhen(
      data: (url) => url,
      orElse: () => '',
    );
    final resolvedAvatarUrl = isOwner ? currentUserAvatarUrl : _ownerAvatarUrl;

    // Resolve artwork image: playlist artwork → first track artwork → user avatar
    // Only treat a URL as valid if it's a real HTTPS URL (not a default/relative path).
    bool isValidArtwork(String? url) =>
        url != null && url.startsWith('https://') && !url.contains('default');
    final hasArtwork = isValidArtwork(p.artworkUrl);
    final hasFirstTrack = isValidArtwork(_firstTrackArtworkUrl);
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

    // A track is playable as long as it has a valid ID — the player resolves the
    // actual stream URL via getStreamUrl(id), so a missing pre-known hlsUrl
    // does NOT mean the track cannot be played.
    final canPlay = !_isLoadingTracks && _tracks.any((t) => t.id.isNotEmpty);

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('playlist_back_button'),
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
      // CustomScrollView lets the header (SliverToBoxAdapter) and the
      // reorderable track list (SliverReorderableList) share one scroll axis.
      body: CustomScrollView(
        slivers: [
          // ── Header: artwork + creator row + action row ──────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero artwork with title overlaid ──────────────────────
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
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 4)
                                ],
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
                // ── Creator row ───────────────────────────────────────────
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
                // ── Action row (three-dot · like · shuffle · play) ────────
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
                          builder: (_) => PlaylistOptionsSheet(
                            playlist: p,
                            showCopyOption: true,
                            popPageOnDelete: true,
                            canManage: isOwner,
                          ),
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
                      if (!isOwner) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: playlistEngState.isLoadingLike
                              ? null
                              : () => ref
                                  .read(engagementProvider(playlistEngParams)
                                      .notifier)
                                  .toggleLike(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: playlistEngState.isLoadingLike
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white54,
                                      ),
                                    )
                                  : Icon(
                                      playlistEngState.isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: playlistEngState.isLiked
                                          ? const Color(0xFFFF5500)
                                          : Colors.white,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Shuffle
                      GestureDetector(
                        onTap: canPlay
                            ? () {
                                setState(
                                    () => _isShuffleActive = !_isShuffleActive);
                                if (_isShuffleActive) _shufflePlay();
                              }
                            : null,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _isShuffleActive
                                ? const Color(0xFFFF5500)
                                    .withValues(alpha: 0.15)
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
                      // Play / Pause
                      GestureDetector(
                        onTap: canPlay
                            ? () {
                                if (isThisPlaylistPlaying) {
                                  ref
                                      .read(playerProvider.notifier)
                                      .togglePlayPause();
                                } else {
                                  _playFrom(0);
                                }
                              }
                            : null,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: canPlay ? Colors.white : Colors.white30,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            showPausePlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: canPlay ? Colors.black : Colors.black38,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Track list ──────────────────────────────────────────────────
          if (_isLoadingTracks)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: CircularProgressIndicator(color: Colors.white54)),
              ),
            )
          else
            SliverReorderableList(
              itemCount: _tracks.length,
              itemBuilder: (_, index) {
                final t = _tracks[index];
                // Material wrapper ensures InkWell has a Material ancestor
                // even when the item is lifted into a drag proxy overlay.
                return Material(
                  key: ValueKey(t.id.isNotEmpty ? t.id : 'track_$index'),
                  color: Colors.transparent,
                  child: _TrackTile(
                    key: ValueKey(
                      'playlist_track_tile_${t.id.isNotEmpty ? t.id : index}',
                    ),
                    title: t.title,
                    artist: t.artistName,
                    playCount: _formatPlayCount(t.playCount),
                    duration: _formatDuration(t.durationSeconds),
                    artworkUrl: t.artworkUrl,
                    onTap: t.id.isNotEmpty && !_isOperationInFlight
                        ? () => _playFrom(index)
                        : null,
                    onMoreTap: !isOwner || _isOperationInFlight
                        ? null
                        : () => _showTrackActions(t),
                    // Show drag handle only when list has >1 item.
                    dragHandle: isOwner && _tracks.length > 1
                        ? ReorderableDragStartListener(
                            key: ValueKey('playlist_drag_handle_$index'),
                            index: index,
                            enabled: !_isOperationInFlight,
                            child: KeyedSubtree(
                              key: const ValueKey('playlist_drag_handle'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 18),
                                child: Icon(
                                  Icons.drag_handle,
                                  color: _isOperationInFlight
                                      ? _secondary.withValues(alpha: 0.3)
                                      : _secondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
              onReorder: _onReorder,
            ),

          // Bottom clearance for the mini player
          const SliverToBoxAdapter(child: SizedBox(height: 72)),
        ],
      ),
    );
  }

  void _shufflePlay() {
    final playableIndices = [
      for (var i = 0; i < _tracks.length; i++)
        if (_tracks[i].id.isNotEmpty) i,
    ];
    if (playableIndices.isEmpty) return;
    final randomIdx = playableIndices[Random().nextInt(playableIndices.length)];
    _playFrom(randomIdx);
  }

  bool _isCurrentPlaylistOwned() {
    final id = widget.playlistId ?? widget.playlist?.id ?? _fetchedPlaylist?.id;
    if (id == null || id.isEmpty) return false;
    final ownedPlaylists = ref.read(playlistsProvider);
    if (ownedPlaylists.any((playlist) => playlist.id == id)) return true;
    final userId = ref.read(sessionUserIdProvider);
    final current = widget.playlist ?? _fetchedPlaylist;
    return userId.isNotEmpty && current?.creatorId == userId;
  }

  bool _isPlaylistOwned(
    Playlist playlist, {
    required String userId,
    required List<Playlist> ownedPlaylists,
  }) {
    if (ownedPlaylists.any((owned) => owned.id == playlist.id)) return true;
    return userId.isNotEmpty && playlist.creatorId == userId;
  }

  void _playFrom(int tappedIndex) {
    final tappedId = _tracks[tappedIndex].id;
    // Include all tracks with a valid ID. audioUrl may be empty — the player
    // resolves the actual HLS URL via getStreamUrl(id) before playback starts.
    final queue = _tracks
        .where((t) => t.id.isNotEmpty)
        .map((t) => PlayerTrack(
              id: t.id,
              title: t.title,
              artist: t.artistName,
              audioUrl: t.hlsUrl ?? '',
              coverUrl: t.artworkUrl,
              duration: t.durationSeconds != null
                  ? Duration(seconds: t.durationSeconds!)
                  : null,
              waveform: t.waveform,
              trackPermalink: t.permalink,
            ))
        .toList();
    if (queue.isEmpty) return;
    final queueIndex =
        queue.indexWhere((t) => t.id == tappedId).clamp(0, queue.length - 1);
    ref.read(playerProvider.notifier).playQueue(queue, startIndex: queueIndex);
    // Tell the heartbeat this is a playlist context so PUT /player/state sends
    // queueContext: "playlist" and contextId: <playlist._id>.
    final playlistId =
        widget.playlistId ?? widget.playlist?.id ?? _fetchedPlaylist?.id;
    if (playlistId != null && playlistId.isNotEmpty) {
      ref
          .read(playerProvider.notifier)
          .setQueueContext('playlist', contextId: playlistId);
    }
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

// ── Track tile ────────────────────────────────────────────────────��───────────

class _TrackTile extends StatelessWidget {
  final String title;
  final String artist;
  final String? playCount;
  final String? duration;
  final String? artworkUrl;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  // Built outside and passed in so the ReorderableDragStartListener can
  // reference the item's index in SliverReorderableList.
  final Widget? dragHandle;

  const _TrackTile({
    super.key,
    required this.title,
    required this.artist,
    this.playCount,
    this.duration,
    this.artworkUrl,
    this.onTap,
    this.onMoreTap,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white10,
      highlightColor: Colors.white10,
      child: KeyedSubtree(
        key: const ValueKey('playlist_track_tile'),
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
                    Text(
                      '▶ ${playCount ?? '0'} · ${duration ?? '0:00'}',
                      style: const TextStyle(color: _secondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // More icon — tap to open per-track action sheet
              GestureDetector(
                onTap: onMoreTap,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: _secondary,
                    size: 22,
                  ),
                ),
              ),
              // Drag handle — null when list has ≤1 item
              if (dragHandle != null) dragHandle!,
            ],
          ),
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
  final List<int>? waveform;
  final String? permalink;

  const _PlaylistTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.artworkUrl,
    this.hlsUrl,
    required this.playCount,
    this.durationSeconds,
    this.waveform,
    this.permalink,
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
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      permalink: json['permalink'] as String?,
    );
  }
}
