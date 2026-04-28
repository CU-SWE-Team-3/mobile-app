import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/core/utils/profile_navigation.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

import '../pages/likers_list_page.dart';
import '../pages/reposters_list_page.dart';
import '../../../playlist/presentation/pages/add_to_playlist_page.dart';

class TrackOptionsSheet extends ConsumerWidget {
  final String trackId;
  final String? title;
  final String? artistName;
  final String? artworkUrl;
  final String? artistId;
  final String? artistPermalink;
  final List<PlayerTrack>? queue;

  const TrackOptionsSheet({
    super.key,
    required this.trackId,
    this.title,
    this.artistName,
    this.artworkUrl,
    this.artistId,
    this.artistPermalink,
    this.queue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDetails = title != null && artistName != null;
    final playerTrack = PlayerTrack(
      id: trackId,
      title: title ?? 'Track',
      artist: artistName ?? 'Unknown artist',
      artistId: artistId,
      artistPermalink: artistPermalink,
      audioUrl: '',
      coverUrl: artworkUrl,
    );

    void showSoon(String label) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          backgroundColor: const Color(0xFF333333),
        ),
      );
    }

    void playLast() {
      ref.read(playerProvider.notifier).addToQueue(playerTrack);
      Navigator.pop(context);
    }

    void playNext() {
      final state = ref.read(playerProvider);
      ref.read(playerProvider.notifier).addToQueue(playerTrack);
      if (state.queue.isNotEmpty) {
        final oldIndex = state.queue.length;
        final insertAt = (state.currentQueueIndex + 1).clamp(0, oldIndex);
        if (insertAt < oldIndex) {
          ref.read(playerProvider.notifier).reorderQueue(oldIndex, insertAt);
        }
      }
      Navigator.pop(context);
    }

    return Container(
      color: const Color(0xFF111111),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDetails) _TrackSheetHeader(title: title!, artist: artistName!, artworkUrl: artworkUrl),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text(
                  'SEND TO',
                  style: TextStyle(
                    color: Color(0xFFB6B6B6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: const [
                    _SendToAvatar(name: 'Mohamed Hany'),
                    SizedBox(width: 10),
                    _SendToAvatar(name: 'Marwan Pablo'),
                    SizedBox(width: 10),
                    _SendToAvatar(name: 'Two Feet'),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 22, 16, 8),
                child: Text(
                  'SHARE',
                  style: TextStyle(
                    color: Color(0xFFB6B6B6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: const [
                    _ShareButton(icon: Icons.send_outlined, label: 'Message'),
                    SizedBox(width: 10),
                    _ShareButton(icon: Icons.content_copy_outlined, label: 'Copy Link'),
                    SizedBox(width: 10),
                    _ShareButton(icon: Icons.chat, label: 'WhatsApp', green: true),
                    SizedBox(width: 10),
                    _ShareButton(icon: Icons.check_circle_outline, label: 'Status', green: true),
                    SizedBox(width: 10),
                    _ShareButton(icon: Icons.sms_outlined, label: 'SMS'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _OptionTile(icon: Icons.favorite_border, label: 'Like', onTap: () => showSoon('Like coming soon')),
              _OptionTile(icon: Icons.format_list_bulleted, label: 'Play Next', onTap: playNext),
              _OptionTile(icon: Icons.format_list_numbered, label: 'Play Last', onTap: playLast),
              _OptionTile(
                icon: Icons.playlist_add_outlined,
                label: 'Add to playlist',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddToPlaylistPage(trackId: trackId),
                    ),
                  );
                },
              ),
              _OptionTile(icon: Icons.wifi_tethering_outlined, label: 'Start station', onTap: () => showSoon('Start station coming soon')),
              const Divider(color: Color(0xFF2A2A2A), height: 1),
              _OptionTile(
                icon: Icons.person_outline,
                label: 'Go to artist profile',
                onTap: () {
                  if (artistId != null && artistPermalink != null && artistName != null) {
                    Navigator.pop(context);
                    navigateToUserProfile(
                      context,
                      userId: artistId!,
                      permalink: artistPermalink!,
                      displayName: artistName!,
                    );
                  } else {
                    showSoon('Artist profile unavailable');
                  }
                },
              ),
              _OptionTile(
                icon: Icons.chat_bubble_outline,
                label: 'View comments',
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '/comments',
                    extra: {
                      'trackId': trackId,
                      'trackTitle': title,
                      'trackArtist': artistName,
                      'trackArtworkUrl': artworkUrl,
                      'currentPositionSeconds': 0,
                    },
                  );
                },
              ),
              _OptionTile(
                icon: Icons.repeat,
                label: 'Repost on SoundCloud',
                onTap: () => showSoon('Repost coming soon'),
              ),
              const Divider(color: Color(0xFF2A2A2A), height: 1),
              _OptionTile(
                icon: Icons.people_outline,
                label: 'People who liked this track',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LikersListPage(trackId: trackId),
                    ),
                  );
                },
              ),
              _OptionTile(
                icon: Icons.people_alt_outlined,
                label: 'People who reposted this track',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RepostersListPage(trackId: trackId),
                    ),
                  );
                },
              ),
              _OptionTile(icon: Icons.graphic_eq, label: 'Behind this track', onTap: () => showSoon('Behind this track coming soon')),
              _OptionTile(icon: Icons.outlined_flag, label: 'Report', onTap: () => showSoon('Report coming soon')),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackSheetHeader extends StatelessWidget {
  final String title;
  final String artist;
  final String? artworkUrl;

  const _TrackSheetHeader({
    required this.title,
    required this.artist,
    required this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 166,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F283B), Color(0xFF7E576F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 104,
              height: 104,
              child: artworkUrl == null || artworkUrl!.isEmpty
                  ? const _SheetArtworkPlaceholder()
                  : CachedNetworkImage(
                      imageUrl: artworkUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _SheetArtworkPlaceholder(),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  artist,
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendToAvatar extends StatelessWidget {
  final String name;

  const _SendToAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF3A3A3A),
            child: Icon(Icons.person, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool green;

  const _ShareButton({
    required this.icon,
    required this.label,
    this.green = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: green ? const Color(0xFF28D366) : const Color(0xFF2F2F2F),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: onTap,
    );
  }
}

class _SheetArtworkPlaceholder extends StatelessWidget {
  const _SheetArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF303030),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 34),
      ),
    );
  }
}
