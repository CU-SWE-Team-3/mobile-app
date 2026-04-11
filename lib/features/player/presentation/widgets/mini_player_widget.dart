import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/core/utils/profile_navigation.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/follow_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

class MiniPlayerWidget extends ConsumerStatefulWidget {
  const MiniPlayerWidget({super.key});

  @override
  ConsumerState<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends ConsumerState<MiniPlayerWidget> {
  bool _isLiked = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final currentTrack = playerState.currentTrack;

    if (currentTrack == null) return const SizedBox.shrink();

    final artistId = currentTrack.artistId;
    final followState = artistId != null
        ? ref.watch(followProvider(artistId))
        : const FollowState();

    final isPlaying = playerState.isPlaying;
    final notifier = ref.read(playerProvider.notifier);

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // White circle play/pause button
          GestureDetector(
            key: const ValueKey('mini_player_play_button'),
            onTap: notifier.togglePlayPause,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Center: title taps to expand player; artist taps to profile
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  key: const ValueKey('mini_player_expand_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push('/player'),
                  child: Text(
                    currentTrack.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final id = currentTrack.artistId;
                    final permalink = currentTrack.artistPermalink;
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Follow/unfollow icon
          if (artistId == null)
            const Icon(Icons.person_add_outlined, color: Colors.white, size: 22)
          else
            IconButton(
              key: const ValueKey('mini_player_follow_button'),
              icon: followState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      followState.isFollowing
                          ? Icons.person
                          : Icons.person_add_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
              onPressed: () =>
                  ref.read(followProvider(artistId).notifier).toggle(artistId),
            ),

          // Heart icon — local UI toggle only
          IconButton(
            key: const ValueKey('mini_player_like_button'),
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _isLiked = !_isLiked;
              });
            },
          ),
        ],
      ),
    );
  }
}
