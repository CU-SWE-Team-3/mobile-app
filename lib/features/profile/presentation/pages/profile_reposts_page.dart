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

final _userRepostsProvider =
    FutureProvider.autoDispose<List<TrackSummary>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId') ?? '';
  if (userId.isEmpty) return [];
  return sl<EngagementRemoteDataSource>().getUserReposts(userId);
});

class ProfileRepostsPage extends ConsumerWidget {
  const ProfileRepostsPage({super.key});

  static const _bg = Color(0xFF111111);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_userRepostsProvider);

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
                    key: const ValueKey('profile_reposts_back_button'),
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
                    'Reposts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    key: const ValueKey('profile_reposts_cast_button'),
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
                  child:
                      CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load reposts',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 12),
                      TextButton(
                        key: const ValueKey('profile_reposts_retry_button'),
                        onPressed: () =>
                            ref.invalidate(_userRepostsProvider),
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFFFF5500))),
                      ),
                    ],
                  ),
                ),
                data: (tracks) => tracks.isEmpty
                    ? const Center(
                        child: Text('No reposts yet',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 16)),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: tracks.length,
                        itemBuilder: (_, i) =>
                            _RepostTile(track: tracks[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepostTile extends ConsumerWidget {
  final TrackSummary track;
  const _RepostTile({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This tile only exists for reposted tracks — initialize provider with
    // isReposted:true so it shows correctly if not yet touched by the home feed.
    // If the provider already exists (toggled or seeded elsewhere), that state wins.
    final params = EngagementParams(
      trackId: track.id,
      isReposted: true,
      repostCount: track.repostCount,
      likeCount: track.likeCount,
    );
    final engState = ref.watch(engagementProvider(params));

    // Seed authoritative reposted state. Only isReposted is seeded — we don't
    // know isLiked from this API, so we leave it untouched. No-op if the user
    // has already toggled this track in the current session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(engagementProvider(params).notifier).seed(
        isReposted: true,
        likeCount: track.likeCount,
        repostCount: track.repostCount,
      );
    });

    // Hide immediately when the user un-reposts this track
    if (!engState.isReposted) return const SizedBox.shrink();

    final sub = Colors.white.withOpacity(0.55);
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        track.artworkUrl!.startsWith('http');

    return GestureDetector(
      key: const ValueKey('profile_reposts_track_tile'),
      onTap: () {
        if (track.audioUrl != null) {
          ref.read(playerProvider.notifier).playTrack(
                PlayerTrack(
                  id: track.id,
                  title: track.title,
                  artist: track.artistName,
                  audioUrl: track.audioUrl!,
                  coverUrl: track.artworkUrl,
                  artistId: track.artistId,
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
            // Thumbnail
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
            // Info
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
            Icon(Icons.more_vert_rounded, color: sub, size: 20),
          ],
        ),
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
