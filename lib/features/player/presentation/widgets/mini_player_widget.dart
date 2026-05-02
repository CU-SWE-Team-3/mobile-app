import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/core/providers/session_provider.dart';
import 'package:soundcloud_clone/core/themes/app_theme.dart';
import 'package:soundcloud_clone/core/utils/profile_navigation.dart';
import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/follow_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

class MiniPlayerWidget extends ConsumerStatefulWidget {
  const MiniPlayerWidget({super.key});

  @override
  ConsumerState<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends ConsumerState<MiniPlayerWidget> {
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final currentTrack = playerState.currentTrack;

    if (currentTrack == null) return const SizedBox.shrink();

    final isPlaying = playerState.isPlaying;
    final notifier = ref.read(playerProvider.notifier);
    final durationMs = playerState.duration.inMilliseconds;
    final progress = durationMs <= 0
        ? 0.0
        : (playerState.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
    final myUserId = ref.watch(sessionUserIdProvider);
    final artistId = currentTrack.artistId;
    final showFollowButton = artistId != null && artistId != myUserId;
    final followArtistId = artistId ?? '';
    final followState = showFollowButton
        ? ref.watch(followProvider(followArtistId))
        : const FollowState(isChecking: false);
    final engParams = EngagementParams(trackId: currentTrack.id);
    final engState = ref.watch(engagementProvider(engParams));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (currentTrack.coverUrl != null &&
                    currentTrack.coverUrl!.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: 6,
                    bottom: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Opacity(
                        opacity: 0.42,
                        child: SizedBox(
                          width: 64,
                          child: CachedNetworkImage(
                            imageUrl: currentTrack.coverUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const _MiniArtworkPlaceholder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
                  child: Row(
                    children: [
                      GestureDetector(
                        key: const ValueKey('mini_player_play_button'),
                        onTap: notifier.togglePlayPause,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 3,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.18),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF5500),
                                  ),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.black,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          key: const ValueKey('mini_player_expand_button'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push('/player'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentTrack.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  final id = currentTrack.artistId;
                                  final permalink =
                                      currentTrack.artistPermalink;
                                  if (id != null && permalink != null) {
                                    navigateToUserProfile(
                                      context,
                                      userId: id,
                                      permalink: permalink,
                                      displayName: currentTrack.artist,
                                    );
                                  } else {
                                    context.push('/player');
                                  }
                                },
                                child: Text(
                                  currentTrack.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFD4D4D4),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (showFollowButton)
                        GestureDetector(
                          key: const ValueKey('mini_player_follow_button'),
                          onTap: (followState.isLoading || followState.isChecking)
                              ? null
                              : () => ref
                                  .read(followProvider(followArtistId).notifier)
                                  .toggle(followArtistId),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: followState.isLoading || followState.isChecking
                                ? const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    followState.isFollowing
                                        ? Icons.person
                                        : Icons.person_add_outlined,
                                    color: followState.isFollowing
                                        ? AppTheme.primary
                                        : Colors.white,
                                    size: 22,
                                  ),
                          ),
                        ),
                      if (showFollowButton) const SizedBox(width: 2),
                      GestureDetector(
                        key: const ValueKey('mini_player_like_button'),
                        onTap: engState.isLoadingLike
                            ? null
                            : () async {
                                final wasLiked = engState.isLiked;
                                final overrides =
                                    ref.read(likedTrackOverridesProvider.notifier);
                                void writeOverride({
                                  required bool liked,
                                  required int likeCount,
                                }) {
                                  final current =
                                      Map<String, TrackSummary>.from(
                                    ref.read(likedTrackOverridesProvider),
                                  );
                                  if (liked) {
                                    current[currentTrack.id] = TrackSummary(
                                      id: currentTrack.id,
                                      title: currentTrack.title,
                                      artistName: currentTrack.artist,
                                      artistId: currentTrack.artistId,
                                      artistPermalink:
                                          currentTrack.artistPermalink,
                                      artworkUrl: currentTrack.coverUrl,
                                      audioUrl: currentTrack.audioUrl,
                                      waveform: currentTrack.waveform,
                                      likeCount: likeCount,
                                    );
                                  } else {
                                    current.remove(currentTrack.id);
                                  }
                                  overrides.state = current;
                                }

                                writeOverride(
                                  liked: !wasLiked,
                                  likeCount: wasLiked
                                      ? engState.likeCount
                                      : engState.likeCount + 1,
                                );
                                final success = await ref
                                    .read(
                                        engagementProvider(engParams).notifier)
                                    .toggleLike();
                                if (!success) {
                                  writeOverride(
                                    liked: wasLiked,
                                    likeCount: engState.likeCount,
                                  );
                                }
                              },
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            engState.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: engState.isLiked
                                ? const Color(0xFFFF5500)
                                : Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniArtworkPlaceholder extends StatelessWidget {
  const _MiniArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2F2F2F),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white24,
          size: 22,
        ),
      ),
    );
  }
}
