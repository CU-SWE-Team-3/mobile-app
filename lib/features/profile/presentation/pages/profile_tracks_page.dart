import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/features/library/domain/entities/upload_track.dart';
import 'package:soundcloud_clone/features/library/presentation/providers/my_tracks_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/widgets/mini_player_widget.dart';

class ProfileTracksPage extends ConsumerWidget {
  const ProfileTracksPage({super.key});

  static const _bg = Color(0xFF111111);

  List<PlayerTrack> _playableQueue(List<UploadTrack> tracks) => tracks
      .where((track) => track.hlsUrl != null && track.hlsUrl!.isNotEmpty)
      .map(
        (track) => PlayerTrack(
          id: track.id ?? track.hlsUrl!,
          title: track.title,
          artist: track.artist,
          audioUrl: track.hlsUrl!,
          coverUrl: track.artworkUrl,
          waveform: track.waveform,
          duration: track.duration != null
              ? Duration(seconds: track.duration!)
              : null,
        ),
      )
      .toList();

  void _playFrom(
    BuildContext context,
    WidgetRef ref,
    List<UploadTrack> tracks,
    int index,
  ) {
    final tapped = tracks[index];
    if (tapped.hlsUrl == null || tapped.hlsUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This track is still processing.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final queue = _playableQueue(tracks);
    if (queue.isEmpty) return;

    final startIndex = queue.indexWhere(
      (track) => track.id == (tapped.id ?? tapped.hlsUrl),
    );
    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: startIndex < 0 ? 0 : startIndex,
        );
  }

  void _playAll(WidgetRef ref, List<UploadTrack> tracks,
      {bool shuffle = false}) {
    final queue = _playableQueue(tracks);
    if (queue.isEmpty) return;
    if (shuffle) queue.shuffle(Random());
    ref.read(playerProvider.notifier).playQueue(queue);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(myTracksProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) context.pop();
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tracks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                tracksAsync.maybeWhen(
                  data: (tracks) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _playAll(ref, tracks, shuffle: true),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shuffle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _playAll(ref, tracks),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  orElse: () => const SizedBox(height: 76),
                ),
                Expanded(
                  child: tracksAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (_, __) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Failed to load tracks',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => ref.invalidate(myTracksProvider),
                            child: const Text(
                              'Retry',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    data: (tracks) {
                      if (tracks.isEmpty) {
                        return const Center(
                          child: Text(
                            'No tracks yet',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 132),
                        itemCount: tracks.length,
                        itemBuilder: (_, index) => _TrackTile(
                          key: ValueKey(
                            'profile_tracks_tile_${tracks[index].id ?? index}_$index',
                          ),
                          track: tracks[index],
                          onTap: () => _playFrom(context, ref, tracks, index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerWidget(),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final UploadTrack track;
  final VoidCallback onTap;

  const _TrackTile({
    super.key,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withValues(alpha: 0.55);
    final durationLabel = _formatDuration(track.duration);
    final isProcessing =
        track.processingState != null && track.processingState != 'Finished';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (track.artworkUrl != null && track.artworkUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: track.artworkUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: sub, fontSize: 13),
                  ),
                  if (durationLabel.isNotEmpty || isProcessing) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (durationLabel.isNotEmpty)
                          Text(
                            durationLabel,
                            style: TextStyle(color: sub, fontSize: 12),
                          ),
                        if (durationLabel.isNotEmpty && isProcessing)
                          const SizedBox(width: 8),
                        if (isProcessing)
                          const Text(
                            'Processing',
                            style: TextStyle(
                              color: Color(0xFFFF5500),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.more_vert_rounded, color: sub, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF6699BB),
        child: const Icon(Icons.music_note, color: Colors.white70, size: 30),
      );

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final minutes = seconds ~/ 60;
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }
}
