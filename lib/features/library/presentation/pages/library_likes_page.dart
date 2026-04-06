import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection_container.dart';
import '../../../engagement/data/sources/engagement_remote_data_source.dart';
import '../../../player/presentation/providers/player_provider.dart';

final _likedTracksProvider =
    FutureProvider.autoDispose<List<TrackSummary>>((ref) async {
  return sl<EngagementRemoteDataSource>().getLikedTracks();
});

class LibraryLikesPage extends ConsumerWidget {
  const LibraryLikesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_likedTracksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text('Likes', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: async.when(
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
                onPressed: () => ref.invalidate(_likedTracksProvider),
                child: const Text('Retry',
                    style: TextStyle(color: Color(0xFFFF5500))),
              ),
            ],
          ),
        ),
        data: (tracks) => tracks.isEmpty
            ? const Center(
                child: Text('No liked tracks yet',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
              )
            : ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (_, i) => _TrackTile(track: tracks[i]),
              ),
      ),
    );
  }
}

class _TrackTile extends ConsumerWidget {
  final TrackSummary track;
  const _TrackTile({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        track.artworkUrl!.startsWith('http');

    return ListTile(
      onTap: () {
        if (track.audioUrl != null) {
          ref.read(playerProvider.notifier).playTrack(
                PlayerTrack(
                  id: track.id,
                  title: track.title,
                  artist: track.artistName,
                  audioUrl: track.audioUrl!,
                  coverUrl: track.artworkUrl,
                ),
              );
          context.push('/player');
        }
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 48,
          height: 48,
          child: hasArtwork
              ? CachedNetworkImage(
                  imageUrl: track.artworkUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
      title: Text(track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(track.artistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.favorite, color: Color(0xFFFF5500), size: 18),
    );
  }

  Widget _placeholder() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
            child: Icon(Icons.music_note, color: Color(0xFF666666), size: 22)),
      );
}
