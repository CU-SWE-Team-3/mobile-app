import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../playlist/domain/entities/playlist.dart';
import '../providers/engagement_provider.dart';

class LikeButton extends ConsumerWidget {
  final String trackId;
  final bool initialIsLiked;
  final int initialLikeCount;
  final bool showCount;
  final double iconSize;
  final String targetModel;

  const LikeButton({
    super.key,
    required this.trackId,
    this.initialIsLiked = false,
    this.initialLikeCount = 0,
    this.showCount = false,
    this.iconSize = 24,
    this.targetModel = 'Track',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = EngagementParams(
      trackId: trackId,
      targetModel: targetModel,
      isLiked: initialIsLiked,
      likeCount: initialLikeCount,
    );
    final state = ref.watch(engagementProvider(params));

    return GestureDetector(
      key: const ValueKey('engagement_like_button'),
      onTap: state.isLoadingLike
          ? null
          : () => ref.read(engagementProvider(params).notifier).toggleLike(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.isLiked ? Icons.favorite : Icons.favorite_border,
              color: state.isLiked ? const Color(0xFFFF5500) : Colors.white54,
              size: iconSize,
            ),
            if (showCount && state.likeCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${state.likeCount}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PlaylistLikeButton extends ConsumerWidget {
  final Playlist playlist;
  final double iconSize;

  const PlaylistLikeButton({
    super.key,
    required this.playlist,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedPlaylists = ref.watch(likedPlaylistsProvider);
    final isLiked = likedPlaylists.maybeWhen(
      data: (playlists) => playlists.any((p) => p.id == playlist.id),
      orElse: () => false,
    );
    final params = EngagementParams(
      trackId: playlist.id,
      targetModel: 'Playlist',
      isLiked: isLiked,
    );
    final state = ref.watch(engagementProvider(params));
    ref.listen<AsyncValue<List<Playlist>>>(likedPlaylistsProvider, (_, next) {
      final bool? liked = next.maybeWhen<bool?>(
        data: (playlists) => playlists.any((p) => p.id == playlist.id),
        orElse: () => null,
      );
      if (liked != null) {
        ref.read(engagementProvider(params).notifier).seed(isLiked: liked);
      }
    });

    return IconButton(
      key: ValueKey('playlist_like_button_${playlist.id}'),
      onPressed: state.isLoadingLike
          ? null
          : () async {
              final wasLiked = state.isLiked;
              final ok = await ref
                  .read(engagementProvider(params).notifier)
                  .toggleLike();
              if (!ok) return;

              final hidden = ref.read(hiddenLikedPlaylistIdsProvider);
              final overrides = ref.read(likedPlaylistOverridesProvider);
              if (wasLiked) {
                ref.read(hiddenLikedPlaylistIdsProvider.notifier).state = {
                  ...hidden,
                  playlist.id,
                };
                final next = Map<String, Playlist>.from(overrides)
                  ..remove(playlist.id);
                ref.read(likedPlaylistOverridesProvider.notifier).state = next;
              } else {
                final nextHidden = <String>{...hidden}..remove(playlist.id);
                ref.read(hiddenLikedPlaylistIdsProvider.notifier).state =
                    nextHidden;
                ref.read(likedPlaylistOverridesProvider.notifier).state = {
                  ...overrides,
                  playlist.id: playlist,
                };
              }
            },
      icon: Icon(
        state.isLiked ? Icons.favorite : Icons.favorite_border,
        color: state.isLiked ? const Color(0xFFFF5500) : Colors.white,
        size: iconSize,
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.28),
      ),
      tooltip: state.isLiked ? 'Unlike playlist' : 'Like playlist',
    );
  }
}
