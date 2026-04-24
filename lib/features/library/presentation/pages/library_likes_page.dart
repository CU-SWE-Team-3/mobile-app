import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/profile_navigation.dart';
import '../../../../injection_container.dart';
import '../../../engagement/data/sources/engagement_remote_data_source.dart';
import '../../../engagement/presentation/providers/engagement_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';

final _userLikesProvider =
    FutureProvider.autoDispose<List<TrackSummary>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId') ?? '';
  if (userId.isEmpty) return [];
  return sl<EngagementRemoteDataSource>().getUserLikes(userId);
});

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
  final Set<String> _removedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrackSummary> _applyFiltersAndSort(List<TrackSummary> tracks) {
    var result = tracks.where((t) => !_removedIds.contains(t.id)).toList();
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
        result.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'artist':
        result.sort((a, b) =>
            a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase()));
        break;
      default:
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
    final async = ref.watch(_userLikesProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── top bar ──────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('library_likes_back_button'),
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Likes',
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
                        color: Colors.white.withOpacity(0.1),
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
                        onPressed: () => ref.invalidate(_userLikesProvider),
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFFFF5500))),
                      ),
                    ],
                  ),
                ),
                data: (allTracks) {
                  final totalCount = allTracks
                      .where((t) => !_removedIds.contains(t.id))
                      .length;
                  final tracks = _applyFiltersAndSort(allTracks);

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
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search $totalCount track${totalCount == 1 ? '' : 's'}',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: Colors.white.withOpacity(0.4),
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
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: Colors.white.withOpacity(0.7),
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
                                color: Colors.white.withOpacity(0.7),
                                size: 26,
                              ),
                            ),
                            const Spacer(),
                            // Shuffle
                            GestureDetector(
                              onTap: () {
                                final pt = _toPlayerTracks(tracks);
                                if (pt.isEmpty) return;
                                final shuffled = List<PlayerTrack>.from(pt)
                                  ..shuffle(Random());
                                ref
                                    .read(playerProvider.notifier)
                                    .playQueue(shuffled);
                                context.push('/player');
                              },
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
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
                                final pt = _toPlayerTracks(tracks);
                                if (pt.isEmpty) return;
                                ref
                                    .read(playerProvider.notifier)
                                    .playQueue(pt);
                                context.push('/player');
                              },
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5500),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
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
                                physics: const BouncingScrollPhysics(),
                                itemCount: tracks.length,
                                itemBuilder: (_, i) => _LikeTile(
                                  track: tracks[i],
                                  onRemove: () => setState(
                                      () => _removedIds.add(tracks[i].id)),
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
  final VoidCallback onRemove;

  const _LikeTile({required this.track, required this.onRemove});

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

    final sub = Colors.white.withOpacity(0.55);
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        track.artworkUrl!.startsWith('http');

    return GestureDetector(
      key: const ValueKey('library_likes_track_tile'),
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
          context.push('/player');
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
              onTap: () => _showTrackMenu(context, ref, params),
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

  void _showTrackMenu(
      BuildContext context, WidgetRef ref, EngagementParams params) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
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
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.queue_play_next_rounded,
                  color: Colors.white70),
              title: const Text('Play next',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                final playerState = ref.read(playerProvider);
                final notifier = ref.read(playerProvider.notifier);
                notifier.addToQueue(_buildPlayerTrack());
                // Move the appended track to right after the current index.
                final endIndex = playerState.queue.length;
                final insertAt = playerState.currentQueueIndex + 1;
                if (endIndex > insertAt) {
                  notifier.reorderQueue(endIndex, insertAt);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Playing next'),
                      duration: Duration(seconds: 2)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue_rounded,
                  color: Colors.white70),
              title: const Text('Play last',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(playerProvider.notifier)
                    .addToQueue(_buildPlayerTrack());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Added to queue'),
                      duration: Duration(seconds: 2)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded,
                  color: Colors.white70),
              title: const Text('Go to artist profile',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
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
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border_rounded,
                  color: Colors.white70),
              title: const Text('Remove from likes',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(engagementProvider(params).notifier).toggleLike();
                onRemove();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  PlayerTrack _buildPlayerTrack() => PlayerTrack(
        id: track.id,
        title: track.title,
        artist: track.artistName,
        artistId: track.artistId,
        audioUrl: track.audioUrl ?? '',
        coverUrl: track.artworkUrl,
        waveform: track.waveform,
        artistPermalink: track.artistPermalink,
      );

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
