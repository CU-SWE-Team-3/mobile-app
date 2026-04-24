import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/utils/profile_navigation.dart';
import 'package:soundcloud_clone/features/followers/presentation/widgets/suggested_row.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/engagement/presentation/widgets/like_button.dart';
import 'package:soundcloud_clone/features/engagement/presentation/widgets/repost_button.dart';
import 'package:soundcloud_clone/features/engagement/presentation/widgets/track_options_sheet.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _FeedTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
  final String? artworkUrl;
  final String hlsUrl;
  final int playCount;
  final int likeCount;
  final int repostCount;
  final bool isLiked;
  final bool isReposted;
  final List<int>? waveform;

  _FeedTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artworkUrl,
    required this.hlsUrl,
    required this.playCount,
    this.artistId,
    this.artistPermalink,
    this.likeCount = 0,
    this.repostCount = 0,
    this.isLiked = false,
    this.isReposted = false,
    this.waveform,
  });

  factory _FeedTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    return _FeedTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artistId: artist['_id'] as String?,
      artistPermalink: artist['permalink'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String? ?? '',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isReposted: json['isReposted'] as bool? ?? false,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

String _formatPlayCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M plays';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K plays';
  return '$count plays';
}

// ── Page ──────────────────────────────────────────────────────────────────────

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const List<String> _genres = [
    'Electronic', 'Folk', 'House', 'Techno', 'Pop',
    'Hip-Hop', 'Jazz', 'Classical', 'R&B', 'Metal',
  ];

  int _selectedGenreIndex = 0;

  List<_FeedTrack> _tracks = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSuggestedDialog();
    });
  }

  Future<void> _maybeShowSuggestedDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('suggested_dialog_shown') ?? false;
    if (alreadyShown || !mounted) return;
    await prefs.setBool('suggested_dialog_shown', true);
    if (mounted) _showSuggestedDialog(context);
  }

  Future<void> _fetchFeed() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final response = await dioClient.dio.get('/network/feed');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      var tracks = data
          .map((e) => _FeedTrack.fromJson(e as Map<String, dynamic>))
          .toList();

      // Fetch the user's liked and reposted track IDs so we can correctly
      // reflect engagement state on the feed — the feed endpoint itself does
      // not return per-user isLiked / isReposted fields.
      Set<String> likedIds = {};
      Set<String> repostedIds = {};
      if (userId.isNotEmpty) {
        await Future.wait([
          dioClient.dio.get('/profile/$userId/likes').then((r) {
            final d = r.data['data'] as Map<String, dynamic>? ?? {};
            final raw = d['likedTracks'] as List<dynamic>? ?? [];
            for (final item in raw) {
              final trackId =
                  ((item as Map<String, dynamic>)['track']
                          as Map<String, dynamic>?)?['_id'] as String?;
              if (trackId != null && trackId.isNotEmpty) likedIds.add(trackId);
            }
          }).catchError((_) {}),
          dioClient.dio.get('/profile/$userId/reposts').then((r) {
            final d = r.data['data'] as Map<String, dynamic>? ?? {};
            final raw = d['repostedTracks'] as List<dynamic>? ?? [];
            for (final item in raw) {
              final trackId =
                  ((item as Map<String, dynamic>)['track']
                          as Map<String, dynamic>?)?['_id'] as String?;
              if (trackId != null && trackId.isNotEmpty) repostedIds.add(trackId);
            }
          }).catchError((_) {}),
        ]);
      }

      // Rebuild tracks with correct isLiked / isReposted from the sets above.
      tracks = tracks.map((t) => _FeedTrack(
            id: t.id,
            title: t.title,
            artistName: t.artistName,
            artworkUrl: t.artworkUrl,
            hlsUrl: t.hlsUrl,
            playCount: t.playCount,
            artistId: t.artistId,
            artistPermalink: t.artistPermalink,
            isLiked: likedIds.contains(t.id),
            isReposted: repostedIds.contains(t.id),
            likeCount: likedIds.contains(t.id) ? max(t.likeCount, 1) : t.likeCount,
            repostCount: repostedIds.contains(t.id) ? max(t.repostCount, 1) : t.repostCount,
            waveform: t.waveform,
          )).toList();

      if (mounted) {
        // Seed engagement providers BEFORE setState so every LikeButton /
        // RepostButton sees the correct isLiked / isReposted the first time
        // it calls ref.watch — no flicker, no dependency on addPostFrameCallback.
        for (final track in tracks) {
          if (track.id.isEmpty) continue;
          ref
              .read(engagementProvider(
                      EngagementParams(trackId: track.id))
                  .notifier)
              .seed(
                isLiked: track.isLiked,
                isReposted: track.isReposted,
                likeCount: track.likeCount,
                repostCount: track.repostCount,
              );
        }
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _showSuggestedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'People you might like',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('home_suggested_close_button'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF999999)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SuggestedRow(title: null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)),
        ),
      );
    }

    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              const Text(
                'Couldn\'t load feed',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('home_retry_button'),
                onPressed: _fetchFeed,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFFFF5500), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Follow some artists to see their tracks here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF999999), fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      children: _tracks.asMap().entries.map((entry) => _TrackRow(
        track: entry.value,
        allTracks: _tracks,
        index: entry.key,
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('home_get_pro_button'),
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'GET PRO',
              style: TextStyle(
                color: Color(0xFFFF5500),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('home_cast_button'),
            onPressed: () {},
            icon: const Icon(Icons.cast, color: Colors.white, size: 22),
          ),
          IconButton(
            key: const ValueKey('home_upload_button'),
            onPressed: () {},
            icon: const Icon(Icons.upload_rounded, color: Colors.white, size: 22),
          ),
          IconButton(
            key: const ValueKey('home_messages_button'),
            onPressed: () {},
            icon: const Icon(Icons.mail_outline, color: Colors.white, size: 22),
          ),
          IconButton(
            key: const ValueKey('home_notifications_button'),
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFeed,
        color: const Color(0xFFFF5500),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // Section 1 — Trending by genre
          const Text(
            'Trending by genre',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = _selectedGenreIndex == index;
                return GestureDetector(
                  key: const ValueKey('home_genre_chip'),
                  onTap: () => setState(() => _selectedGenreIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF5500)
                            : Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _genres[index],
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFFF5500)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Section 2 — Feed tracks
          _buildTrackSection(),
          const SizedBox(height: 24),

          // Section 3 — Suggested users
          const SuggestedRow(),
          const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }
}

// ── Track row ─────────────────────────────────────────────────────────────────

class _TrackRow extends ConsumerWidget {
  final _FeedTrack track;
  final List<_FeedTrack> allTracks;
  final int index;

  const _TrackRow({
    required this.track,
    required this.allTracks,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: const ValueKey('home_track_row'),
      onTap: () {
        if (track.hlsUrl.isEmpty) return;
        final queue = allTracks
            .where((t) => t.hlsUrl.isNotEmpty)
            .map((t) => PlayerTrack(
                  id: t.id,
                  title: t.title,
                  artist: t.artistName,
                  artistId: t.artistId,
                  artistPermalink: t.artistPermalink,
                  audioUrl: t.hlsUrl,
                  coverUrl: t.artworkUrl,
                  waveform: t.waveform,
                ))
            .toList();
        final startIndex = allTracks
            .where((t) => t.hlsUrl.isNotEmpty)
            .toList()
            .indexWhere((t) => t.id == track.id);
        ref.read(playerProvider.notifier).playQueue(
              queue,
              startIndex: startIndex < 0 ? 0 : startIndex,
            );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // Artwork
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child:
                    track.artworkUrl != null && track.artworkUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: track.artworkUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const _ArtworkPlaceholder(),
                          )
                        : const _ArtworkPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),

            // Title + artist + play count
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
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
                        color: Color(0xFF999999),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatPlayCount(track.playCount),
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Like + Repost + 3-dot
            if (track.id.isNotEmpty) ...[
              LikeButton(
                trackId: track.id,
                initialIsLiked: track.isLiked,
                initialLikeCount: track.likeCount,
                iconSize: 20,
                showCount: true,
              ),
              RepostButton(
                trackId: track.id,
                initialIsReposted: track.isReposted,
                initialRepostCount: track.repostCount,
                iconSize: 20,
                showCount: true,
              ),
            ],
            IconButton(
              key: const ValueKey('home_track_more_button'),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF1E1E1E),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => TrackOptionsSheet(trackId: track.id),
                );
              },
              icon: const Icon(
                Icons.more_vert,
                color: Color(0xFF999999),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2A2A2A),
      child: Center(
        child: Icon(Icons.music_note, color: Color(0xFF666666), size: 28),
      ),
    );
  }
}
