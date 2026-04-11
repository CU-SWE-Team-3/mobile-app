import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/features/library/domain/entities/upload_track.dart';
import 'package:soundcloud_clone/features/library/presentation/providers/my_tracks_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class ProfileTracksPage extends ConsumerWidget {
  const ProfileTracksPage({super.key});

  static const _bg = Color(0xFF111111);

  /// Filters to tracks that can actually be streamed.
  List<UploadTrack> _playable(List<UploadTrack> all) =>
      all.where((t) => t.hlsUrl != null && t.hlsUrl!.isNotEmpty).toList();

  void _playFrom(WidgetRef ref, List<UploadTrack> tracks, int index) {
    if (tracks.isEmpty) return;
    final queue = tracks
        .map((t) => PlayerTrack(
              id: t.id ?? t.hlsUrl!,
              title: t.title,
              artist: t.artist,
              audioUrl: t.hlsUrl!,
              coverUrl: t.artworkUrl,
              waveform: t.waveform,
            ))
        .toList();
    ref.read(playerProvider.notifier).playQueue(queue, startIndex: index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(myTracksProvider);

    // Derive the playable list now so shuffle/play buttons can use it
    // even while the list area renders via .when().
    final playable = _playable(tracksAsync.valueOrNull ?? []);

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
                    key: const ValueKey('profile_tracks_back_button'),
                    onTap: () =>
                        context.canPop() ? context.pop() : null,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18),
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
                  GestureDetector(
                    key: const ValueKey('profile_tracks_cast_button'),
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

            // ── shuffle + play row ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  const Spacer(),
                  GestureDetector(
                    key: const ValueKey('profile_tracks_shuffle_button'),
                    onTap: () {
                      if (playable.isEmpty) return;
                      _playFrom(ref, playable,
                          Random().nextInt(playable.length));
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shuffle_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Builder(builder: (context) {
                    final playerState = ref.watch(playerProvider);
                    final currentId = playerState.currentTrack?.id;
                    final isFromHere = currentId != null &&
                        playable.any((t) => t.id == currentId);
                    final showPause = isFromHere && playerState.isPlaying;

                    return GestureDetector(
                      key: const ValueKey('profile_tracks_play_all_button'),
                      onTap: () {
                        if (isFromHere) {
                          ref
                              .read(playerProvider.notifier)
                              .togglePlayPause();
                        } else if (playable.isNotEmpty) {
                          _playFrom(ref, playable, 0);
                        }
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
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── list area ─────────────────────────────────────────────
            Expanded(
              child: tracksAsync.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: Colors.white)),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load tracks',
                          style:
                              TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      TextButton(
                        key: const ValueKey(
                            'profile_tracks_retry_button'),
                        onPressed: () =>
                            ref.invalidate(myTracksProvider),
                        child: const Text('Retry',
                            style: TextStyle(
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                data: (_) => playable.isEmpty
                    ? const Center(
                        child: Text('No tracks yet',
                            style: TextStyle(
                                color: Colors.white54)))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: playable.length,
                        itemBuilder: (_, i) => _TrackTile(
                          track: playable[i],
                          onTap: () =>
                              _playFrom(ref, playable, i),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Track tile ────────────────────────────────────────────────────────────────

class _TrackTile extends StatelessWidget {
  final UploadTrack track;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withOpacity(0.55);
    // API returns duration in seconds
    final dur = track.duration;
    final durationLabel = dur != null
        ? '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}'
        : '';

    return GestureDetector(
      key: const ValueKey('profile_tracks_tile'),
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (track.artworkUrl != null &&
                      track.artworkUrl!.isNotEmpty)
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
            // Title + artist + duration
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
                  Text(track.artist,
                      style: TextStyle(color: sub, fontSize: 13)),
                  if (durationLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(durationLabel,
                        style: TextStyle(color: sub, fontSize: 12)),
                  ],
                ],
              ),
            ),
            // More button (placeholder)
            GestureDetector(
              key: const ValueKey('profile_tracks_more_button'),
              onTap: () {},
              child:
                  Icon(Icons.more_vert_rounded, color: sub, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF6699BB),
        child: const Icon(Icons.music_note,
            color: Colors.white70, size: 30),
      );
}
