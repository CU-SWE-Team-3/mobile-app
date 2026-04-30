import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/profile_navigation.dart';
import '../../../engagement/data/sources/engagement_remote_data_source.dart';
import '../../../engagement/presentation/providers/engagement_provider.dart';
import '../../../engagement/presentation/widgets/track_options_sheet.dart';
import '../../../player/presentation/providers/player_provider.dart';

// ─── Page ──────────────────────────────────────────────────────────────────────

class LibraryLikesPage extends ConsumerStatefulWidget {
  const LibraryLikesPage({super.key});

  @override
  ConsumerState<LibraryLikesPage> createState() => _LibraryLikesPageState();
}

class _LibraryLikesPageState extends ConsumerState<LibraryLikesPage> {
  static const _bg = Color(0xFF111111);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'recently_added';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrackSummary> _applyFiltersAndSort(
    List<TrackSummary> tracks,
    Set<String> hiddenIds,
    List<String> likedOrder,
  ) {
    var result = tracks.where((t) => !hiddenIds.contains(t.id)).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.artistName.toLowerCase().contains(q))
          .toList();
    }
    switch (_sortBy) {
      case 'first_added':
        result = result.reversed.toList();
        break;
      case 'title':
        result.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'artist':
        result.sort((a, b) =>
            a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase()));
        break;
      default:
        if (likedOrder.isNotEmpty) {
          final order = {
            for (var i = 0; i < likedOrder.length; i++) likedOrder[i]: i,
          };
          result.sort((a, b) {
            final ai = order[a.id];
            final bi = order[b.id];
            if (ai == null && bi == null) return 0;
            if (ai == null) return 1;
            if (bi == null) return -1;
            return ai.compareTo(bi);
          });
        }
        break;
    }
    return result;
  }

  List<PlayerTrack> _toPlayerTracks(List<TrackSummary> tracks) => tracks
      .where((t) => t.audioUrl != null)
      .map((t) => PlayerTrack(
            id: t.id,
            title: t.title,
            artist: t.artistName,
            artistId: t.artistId,
            audioUrl: t.audioUrl!,
            coverUrl: t.artworkUrl,
            waveform: t.waveform,
            artistPermalink: t.artistPermalink,
          ))
      .toList();

  bool _sameQueue(List<PlayerTrack> a, List<PlayerTrack> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SortSheet(
        current: _sortBy,
        onSelect: (value) {
          setState(() => _sortBy = value);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final async = ref.watch(mergedUserLikesProvider);
    final likedOrder = ref.watch(likedTrackOrderProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('library_likes_back_button'),
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Your likes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    key: const ValueKey('library_likes_cast_button'),
                    onTap: () {},
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cast_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── content ──────────────────────────────────────────────
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load likes',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 12),
                      TextButton(
                        key: const ValueKey('library_likes_retry_button'),
                        onPressed: () =>
                            ref.invalidate(backendUserLikesProvider),
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFFFF5500))),
                      ),
                    ],
                  ),
                ),
                data: (allTracks) {
                  final tracks =
                      _applyFiltersAndSort(allTracks, const <String>{}, likedOrder);
                  final playableTracks =
                      tracks.where((t) => t.audioUrl != null).toList();
                  final playableQueue = _toPlayerTracks(playableTracks);
                  final currentTrackId = playerState.currentTrack?.id;
                  final queueMatchesPage =
                      _sameQueue(playerState.queue, playableQueue);
                  final isFromThisPage = currentTrackId != null &&
                      queueMatchesPage &&
                      playableTracks.any((track) => track.id == currentTrackId);
                  final showPause = isFromThisPage && playerState.isPlaying;
                  final visibleTotalCount = allTracks.length;

                  return Column(
                    children: [
                      // ── search + sort ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search $visibleTotalCount track${visibleTotalCount == 1 ? '' : 's'}',
                                    hintStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _showSortSheet,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── action row ────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          children: [
                            // Download (placeholder)
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Coming soon'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.download_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 26,
                              ),
                            ),
                            const Spacer(),
                            // Shuffle
                            GestureDetector(
                              onTap: () {
                                final shuffledTracks =
                                    List<TrackSummary>.from(tracks)
                                      ..shuffle(Random());
                                ref
                                    .read(likedTrackOrderProvider.notifier)
                                    .state = shuffledTracks
                                        .map((track) => track.id)
                                        .toList();
                                final shuffled = _toPlayerTracks(shuffledTracks);
                                if (shuffled.isEmpty) return;
                                ref
                                    .read(playerProvider.notifier)
                                    .playQueue(shuffled);
                              },
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
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
                            // Play all
                            GestureDetector(
                              onTap: () {
                                if (isFromThisPage) {
                                  ref
                                      .read(playerProvider.notifier)
                                      .togglePlayPause();
                                  return;
                                }
                                if (playableQueue.isEmpty) return;
                                ref
                                    .read(playerProvider.notifier)
                                    .playQueue(playableQueue);
                              },
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  showPause
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: showPause ? 28 : 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── track list ────────────────────────────────
                      Expanded(
                        child: tracks.isEmpty
                            ? Center(
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? 'No liked tracks yet'
                                      : 'No results',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 132),
                                physics: const BouncingScrollPhysics(),
                                itemCount: tracks.length,
                                itemBuilder: (_, i) => _LikeTile(
                                  key: ValueKey(
                                    'library_likes_track_tile_${tracks[i].id}',
                                  ),
                                  track: tracks[i],
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sort Bottom Sheet ──────────────────────────────────────────────────────────

class _SortSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;

  const _SortSheet({required this.current, required this.onSelect});

  static const _values = [
    'recently_added',
    'first_added',
    'title',
    'artist',
  ];

  static const _labels = [
    'Recently added',
    'First added',
    'Title',
    'Artist',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < _values.length; i++)
            ListTile(
              title: Text(
                _labels[i],
                style: TextStyle(
                  color: current == _values[i]
                      ? const Color(0xFFFF5500)
                      : Colors.white,
                  fontWeight: current == _values[i]
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              trailing: current == _values[i]
                  ? const Icon(Icons.check_rounded,
                      color: Color(0xFFFF5500), size: 20)
                  : null,
              onTap: () => onSelect(_values[i]),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Like Tile ──────────────────────────────────────────────────────────────────

class _LikeTile extends ConsumerWidget {
  final TrackSummary track;

  const _LikeTile({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = EngagementParams(
      trackId: track.id,
      isLiked: true,
      likeCount: track.likeCount,
      repostCount: track.repostCount,
    );
    ref.watch(engagementProvider(params));

    // Seed authoritative liked state. Only isLiked is seeded — we don't know
    // isReposted from this API, so we leave it untouched. No-op if user has
    // already toggled this track in the current session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(engagementProvider(params).notifier).seed(
            isLiked: true,
            likeCount: track.likeCount,
            repostCount: track.repostCount,
          );
    });

    final sub = Colors.white.withValues(alpha: 0.55);
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        track.artworkUrl!.startsWith('http');

    return GestureDetector(
      onTap: () {
        if (track.audioUrl != null) {
          ref.read(playerProvider.notifier).playTrack(
                PlayerTrack(
                  id: track.id,
                  title: track.title,
                  artist: track.artistName,
                  artistId: track.artistId,
                  audioUrl: track.audioUrl!,
                  coverUrl: track.artworkUrl,
                  waveform: track.waveform,
                  artistPermalink: track.artistPermalink,
                ),
              );
        }
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
                    style: const TextStyle(
                      color: Colors.white,
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
                    child: Text(track.artistName,
                        style: TextStyle(color: sub, fontSize: 13)),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 13, color: sub),
                      Text(
                        '  ${_formatCount(track.playCount)}',
                        style: TextStyle(color: sub, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showTrackMenu(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.more_vert_rounded, color: sub, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TrackOptionsSheet(
        trackId: track.id,
        title: track.title,
        artistName: track.artistName,
        artworkUrl: track.artworkUrl,
        audioUrl: track.audioUrl,
        waveform: track.waveform,
        artistId: track.artistId,
        artistPermalink: track.artistPermalink,
        showSendTo: false,
        showShare: false,
        showReport: false,
        initialIsLiked: true,
        initialLikeCount: track.likeCount,
        initialRepostCount: track.repostCount,
      ),
    );
  }

  Widget _placeholder() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
            child: Icon(Icons.music_note, color: Colors.white38, size: 24)),
      );

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}
