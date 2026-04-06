import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          // White circle play/pause button — ONLY toggles playback, no navigation
          GestureDetector(
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
          const SizedBox(width: 12),

          // Center: track title + artist — tapping navigates to /player
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.go('/player'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentTrack.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentTrack.artist,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Add-person icon — no action
          IconButton(
            icon: const Icon(
              Icons.person_add_outlined,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {},
          ),

          // Heart icon — local UI toggle only
          IconButton(
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
