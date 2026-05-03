import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/profile_navigation.dart';
import '../../../engagement/data/sources/engagement_remote_data_source.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/station_providers.dart';

// HLS URL pattern used as fallback when a track has no explicit audioUrl.
// Matches the same fallback used in TrackSummary.fromJson.
String _hlsFallback(String id) =>
    'https://biobeatsstorage2026.blob.core.windows.net/biobeats-audio/hls/$id/playlist.m3u8';

class StationPage extends ConsumerStatefulWidget {
  final String trackId;
  final String? title;
  final String? artistName;
  final String? artworkUrl;

  const StationPage({
    super.key,
    required this.trackId,
    this.title,
    this.artistName,
    this.artworkUrl,
  });

  String get _stationId => 'track_$trackId';

  @override
  ConsumerState<StationPage> createState() => _StationPageState();
}

class _StationPageState extends ConsumerState<StationPage> {
  String get _stationId => widget._stationId;

  @override
  void initState() {
    super.initState();
    // Write current page metadata into the session cache so that
    // Library → StationPage navigation can recover artworkUrl / artistName.
    final effectiveTitle = widget.title;
    if (effectiveTitle != null && effectiveTitle.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(stationMetaCacheProvider.notifier).update((map) {
          return {
            ...map,
            _stationId: StationMeta(
              title: effectiveTitle,
              artistName: widget.artistName,
              artworkUrl: widget.artworkUrl,
            ),
          };
        });
      });
    }
  }

  /// Builds the full display list: source track first, then related (deduped).
  List<TrackSummary> _buildDisplayList(List<TrackSummary> related) {
    final sourceTitle = widget.title?.trim() ?? '';
    final hasSourceMetadata = sourceTitle.isNotEmpty &&
        sourceTitle.toLowerCase() != 'station' &&
        ((widget.artistName?.trim().isNotEmpty ?? false) ||
            (widget.artworkUrl?.trim().isNotEmpty ?? false));
    if (!hasSourceMetadata) {
      return related.where((t) => t.id != widget.trackId).toList();
    }

    final sourceTrack = TrackSummary(
      id: widget.trackId,
      title: sourceTitle,
      artistName: widget.artistName ?? '',
      artworkUrl: widget.artworkUrl,
      audioUrl: _hlsFallback(widget.trackId),
    );
    return [
      sourceTrack,
      ...related.where((t) => t.id != widget.trackId),
    ];
  }

  void _playQueue(List<TrackSummary> tracks, {bool shuffle = false}) {
    final playable = tracks
        .where((t) => t.audioUrl != null && t.audioUrl!.isNotEmpty)
        .map((t) => PlayerTrack(
              id: t.id,
              title: t.title,
              artist: t.artistName,
              artistId: t.artistId,
              artistPermalink: t.artistPermalink,
              audioUrl: t.audioUrl!,
              coverUrl: t.artworkUrl,
              waveform: t.waveform,
            ))
        .toList();
    if (playable.isEmpty) return;
    if (shuffle) playable.shuffle();
    ref.read(playerProvider.notifier).playQueue(playable);
  }

  bool _isStationQueueActive(
      PlayerState playerState, List<TrackSummary> tracks) {
    final stationTrackIds = tracks.map((track) => track.id).toSet();
    final currentId = playerState.currentTrack?.id;
    return currentId != null && stationTrackIds.contains(currentId);
  }

  void _toggleStationPlayback(List<TrackSummary> tracks) {
    final playerState = ref.read(playerProvider);
    if (_isStationQueueActive(playerState, tracks)) {
      ref.read(playerProvider.notifier).togglePlayPause();
      return;
    }
    _playQueue(tracks);
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(stationTracksProvider(widget.trackId));
    final likeState = ref.watch(stationLikeProvider(_stationId));
    final playerState = ref.watch(playerProvider);

    // Build display list eagerly when data is available so both the header
    // track-count and the list body use the same derived value.
    final displayTracks = tracksAsync.hasValue
        ? _buildDisplayList(tracksAsync.value!)
        : <TrackSummary>[];
    final firstTrack = displayTracks.isNotEmpty ? displayTracks.first : null;
    final headerArtworkUrl =
        _firstNonEmpty(widget.artworkUrl, firstTrack?.artworkUrl);
    final headerTitle = _stationTitle(
      widget.title,
      fallback: firstTrack?.title,
    );
    final headerArtistName =
        _firstNonEmpty(widget.artistName, firstTrack?.artistName);
    final isStationActive = _isStationQueueActive(playerState, displayTracks);
    final isStationPlaying = isStationActive && playerState.isPlaying;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _StationHeader(
              artworkUrl: headerArtworkUrl,
              title: headerTitle,
              artistName: headerArtistName,
              trackCount: tracksAsync.hasValue ? displayTracks.length : null,
              likeState: likeState,
              onLikeTap: () =>
                  ref.read(stationLikeProvider(_stationId).notifier).toggle(),
              onShuffleTap: () => _playQueue(displayTracks, shuffle: true),
              onPlayTap: () => _toggleStationPlayback(displayTracks),
              isPlaying: isStationPlaying,
            ),
          ),
          tracksAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
              ),
            ),
            error: (_, __) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load station tracks',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref
                            .invalidate(stationTracksProvider(widget.trackId)),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Color(0xFFFF5500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (_) {
              if (displayTracks.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text(
                        'No related tracks found',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _StationTrackTile(
                    track: displayTracks[i],
                    allTracks: displayTracks,
                    index: i,
                  ),
                  childCount: displayTracks.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 132)),
        ],
      ),
    );
  }

  String? _firstNonEmpty(String? primary, String? fallback) {
    final trimmedPrimary = primary?.trim();
    if (trimmedPrimary != null && trimmedPrimary.isNotEmpty) {
      return trimmedPrimary;
    }
    final trimmedFallback = fallback?.trim();
    if (trimmedFallback != null && trimmedFallback.isNotEmpty) {
      return trimmedFallback;
    }
    return null;
  }

  String? _stationTitle(String? primary, {String? fallback}) {
    final trimmedPrimary = primary?.trim();
    if (trimmedPrimary != null &&
        trimmedPrimary.isNotEmpty &&
        trimmedPrimary.toLowerCase() != 'station') {
      return trimmedPrimary;
    }
    return _firstNonEmpty(fallback, trimmedPrimary);
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _StationHeader extends StatelessWidget {
  final String? artworkUrl;
  final String? title;
  final String? artistName;
  final int? trackCount;
  final StationLikeState likeState;
  final VoidCallback onLikeTap;
  final VoidCallback onShuffleTap;
  final VoidCallback onPlayTap;
  final bool isPlaying;

  const _StationHeader({
    required this.artworkUrl,
    required this.title,
    required this.artistName,
    required this.trackCount,
    required this.likeState,
    required this.onLikeTap,
    required this.onShuffleTap,
    required this.onPlayTap,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final hasArtwork = artworkUrl != null && artworkUrl!.startsWith('http');
    final statusBarH = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 320 + statusBarH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background artwork
          hasArtwork
              ? CachedNetworkImage(
                  imageUrl: artworkUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Color(0xFF2A2A2A)),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF2A2A2A)),
                )
              : Container(
                  color: const Color(0xFF2A2A2A),
                  child: const Center(
                    child: Icon(
                      Icons.wifi_tethering_rounded,
                      color: Colors.white24,
                      size: 72,
                    ),
                  ),
                ),

          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x44000000),
                  Color(0xBB111111),
                  Color(0xFF111111),
                ],
                stops: [0.0, 0.65, 1.0],
              ),
            ),
          ),

          // Back button
          Positioned(
            top: statusBarH + 4,
            left: 12,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),

          // Bottom content
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STATION',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title ?? 'Station',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (artistName != null && artistName!.isNotEmpty)
                    Text(
                      'Based on $artistName · ${title ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  if (trackCount != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '$trackCount tracks',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  // Action row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: likeState.isLoading ? null : onLikeTap,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: likeState.isLiked
                                  ? const Color(0xFFFF5500)
                                  : Colors.white38,
                              width: 1.5,
                            ),
                          ),
                          child: likeState.isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFF5500),
                                    ),
                                  ),
                                )
                              : Icon(
                                  likeState.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: likeState.isLiked
                                      ? const Color(0xFFFF5500)
                                      : Colors.white60,
                                  size: 22,
                                ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onShuffleTap,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shuffle_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: onPlayTap,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 30,
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
    );
  }
}

// ── Track tile ─────────────────────────────────────────────────────────────────

class _StationTrackTile extends ConsumerWidget {
  final TrackSummary track;
  final List<TrackSummary> allTracks;
  final int index;

  const _StationTrackTile({
    required this.track,
    required this.allTracks,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final isCurrent = playerState.currentTrack?.id == track.id;
    final isPlaying = isCurrent && playerState.isPlaying;
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        track.artworkUrl!.startsWith('http');

    return GestureDetector(
      onTap: () {
        if (track.audioUrl == null || track.audioUrl!.isEmpty) return;
        final playable = allTracks
            .where((t) => t.audioUrl != null && t.audioUrl!.isNotEmpty)
            .map((t) => PlayerTrack(
                  id: t.id,
                  title: t.title,
                  artist: t.artistName,
                  artistId: t.artistId,
                  artistPermalink: t.artistPermalink,
                  audioUrl: t.audioUrl!,
                  coverUrl: t.artworkUrl,
                  waveform: t.waveform,
                ))
            .toList();
        final startIdx = playable.indexWhere((t) => t.id == track.id);
        ref.read(playerProvider.notifier).playQueue(
              playable,
              startIndex: startIdx < 0 ? 0 : startIdx,
            );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: hasArtwork
                    ? CachedNetworkImage(
                        imageUrl: track.artworkUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? const Color(0xFFFF5500) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () {
                      final id = track.artistId;
                      final permalink = track.artistPermalink;
                      if (id != null && permalink != null) {
                        navigateToUserProfile(
                          context,
                          userId: id,
                          permalink: permalink,
                          displayName: track.artistName,
                        );
                      }
                    },
                    child: Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isPlaying)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.equalizer_rounded,
                  color: Color(0xFFFF5500),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.music_note, color: Colors.white38, size: 24),
        ),
      );
}
