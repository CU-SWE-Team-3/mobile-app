import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/history_provider.dart';
import '../providers/player_provider.dart';

class RecentlyPlayedPage extends ConsumerWidget {
  const RecentlyPlayedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);
    final playerState = ref.watch(playerProvider);
    final tracks = historyState.recentlyPlayed;
    final notifier = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Recently Played',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: historyState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            )
          : tracks.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, color: Colors.white12, size: 72),
                      SizedBox(height: 16),
                      Text(
                        'Nothing played yet',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tracks you listen to will show up here',
                        style: TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 32),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isCurrent = playerState.currentTrack?.id == track.id;
                    return ListTile(
                      key: const ValueKey('player_recently_played_track_tile'),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: track.coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: track.coverUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _coverFallback(),
                                errorWidget: (_, __, ___) => _coverFallback(),
                              )
                            : _coverFallback(),
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: _TrackSubtitle(
                        artist: track.artist,
                        progress: _trackProgress(playerState, track),
                      ),
                      trailing: Icon(
                        isCurrent && playerState.isPlaying
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        color: Colors.white38,
                        size: 28,
                      ),
                      onTap: () => notifier.playTrack(track),
                    );
                  },
                ),
    );
  }

  static Widget _coverFallback() => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 22),
      );

  static double? _trackProgress(PlayerState playerState, PlayerTrack track) {
    if (playerState.currentTrack?.id != track.id) return null;
    final duration = playerState.duration > Duration.zero
        ? playerState.duration
        : (track.duration ?? Duration.zero);
    if (duration <= Duration.zero) return null;
    return (playerState.position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

class _TrackSubtitle extends StatelessWidget {
  final String artist;
  final double? progress;

  const _TrackSubtitle({required this.artist, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        if (progress != null) ...[
          const SizedBox(height: 6),
          _MiniProgressBar(progress: progress!),
        ],
      ],
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final double progress;

  const _MiniProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        minHeight: 3,
        value: progress,
        backgroundColor: Colors.white12,
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5500)),
      ),
    );
  }
}
