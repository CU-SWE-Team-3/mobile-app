import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feed_provider.dart';

class FollowingFeedPage extends ConsumerStatefulWidget {
  const FollowingFeedPage({super.key});

  @override
  ConsumerState<FollowingFeedPage> createState() => _FollowingFeedPageState();
}

class _FollowingFeedPageState extends ConsumerState<FollowingFeedPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(followingFeedProvider);
      if (!s.isLoading && s.tracks.isEmpty && s.error == null) {
        ref.read(followingFeedProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(followingFeedProvider.notifier).loadNextPage();
    }
  }

  String _activityLabel(FeedTrack track) {
    final actor = track.actorName?.isNotEmpty == true
        ? track.actorName!
        : track.artistName;
    switch (track.activityType) {
      case 'repost':
        return '$actor reposted';
      case 'like':
        return '$actor liked';
      default:
        return '$actor posted';
    }
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(followingFeedProvider);

    Widget body;

    if (state.isLoading) {
      body = const Center(
        key: ValueKey('feed_following_loading'),
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    } else if (state.error != null && state.tracks.isEmpty) {
      body = Center(
        key: const ValueKey('feed_following_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                state.error!,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey('feed_retry_button'),
              onPressed: () => ref.read(followingFeedProvider.notifier).load(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
              ),
              child:
                  const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else if (state.tracks.isEmpty) {
      body = Center(
        key: const ValueKey('feed_following_empty'),
        child: Text(
          'No activity yet.\nFollow some artists to see their posts here.',
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = ListView.builder(
        key: const ValueKey('feed_track_list'),
        controller: _scrollController,
        itemCount: state.tracks.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == state.tracks.length) {
            return const Padding(
              key: ValueKey('feed_following_pagination_loader'),
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF5500)),
              ),
            );
          }
          return _ActivityTile(
            key: ValueKey('feed_following_tile_${state.tracks[i].id}'),
            track: state.tracks[i],
            activityLabel: _activityLabel(state.tracks[i]),
            relativeTime: _relativeTime(state.tracks[i].activityTimestamp),
          );
        },
      );
    }

    return Scaffold(
      key: const ValueKey('feed_following_scaffold'),
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Following',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: body,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    super.key,
    required this.track,
    required this.activityLabel,
    required this.relativeTime,
  });

  final FeedTrack track;
  final String activityLabel;
  final String relativeTime;

  @override
  Widget build(BuildContext context) {
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        !track.artworkUrl!.contains('default-artwork');
    final hasAvatar =
        track.actorAvatarUrl != null && track.actorAvatarUrl!.isNotEmpty;

    return Padding(
      key: const ValueKey('feed_track_tile'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity label row
          Row(
            children: [
              if (hasAvatar)
                CircleAvatar(
                  radius: 10,
                  backgroundImage:
                      CachedNetworkImageProvider(track.actorAvatarUrl!),
                )
              else
                const CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(0xFF2A2A2A),
                  child: Icon(Icons.person, size: 12, color: Colors.white38),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activityLabel,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (relativeTime.isNotEmpty)
                Text(
                  relativeTime,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Track row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: hasArtwork
                    ? CachedNetworkImage(
                        imageUrl: track.artworkUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _artworkFallback(),
                      )
                    : _artworkFallback(),
              ),
              const SizedBox(width: 12),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (track.artistName.isNotEmpty)
                      Text(
                        track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _artworkFallback() => Container(
        width: 60,
        height: 60,
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.music_note, color: Colors.white38, size: 26),
      );
}
