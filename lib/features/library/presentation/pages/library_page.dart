import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/providers/session_provider.dart';
import 'package:soundcloud_clone/features/library/presentation/pages/library_albums_page.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/history_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

import 'package:soundcloud_clone/features/settings/presentation/pages/settings_main_page.dart';

final _libraryAvatarUrlProvider = FutureProvider<String>((ref) async {
  ref.watch(sessionUserIdProvider);
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('avatarUrl') ?? '';
});

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarAsync = ref.watch(_libraryAvatarUrlProvider);
    final localHistory = ref.watch(historyProvider);
    final serverHistory = ref.watch(serverHistoryProvider);
    final recentTracks = localHistory.recentlyPlayed.isNotEmpty
        ? localHistory.recentlyPlayed
        : serverHistory.history.map((entry) => entry.track).toList();
    final historyEntries = serverHistory.history.isNotEmpty
        ? serverHistory.history
        : localHistory.history;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  GestureDetector(
                    key: const ValueKey('library_get_pro_button'),
                    onTap: () => context.push('/upgrade'),
                    child: const Text(
                      'GET PRO',
                      style: TextStyle(
                        color: Color(0xFFFF5500),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                  IconButton(
                    key: const ValueKey('library_upload_button'),
                    icon: const Icon(Icons.arrow_circle_up_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () => context.push('/library/uploads'),
                  ),
                  const SizedBox(width: 1),

                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsMainPage()),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Grey circle avatar with person icon — no photo
                  // Avatar → opens Profile page
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: _LibraryAvatar(avatarAsync: avatarAsync),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Menu list ─────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {},
                color: const Color(0xFFFF5500),
                backgroundColor: const Color(0xFF1A1A1A),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _LibraryMenuItem(
                        key: const ValueKey('library_likes_item'),
                        title: 'Your likes',
                        onTap: () => context.push('/library/likes')),
                    _LibraryMenuItem(
                        key: const ValueKey('library_playlists_item'),
                        title: 'Playlists',
                        onTap: () => context.push('/library/playlists')),
                    _LibraryMenuItem(
                      key: const ValueKey('library_albums_item'),
                      title: 'Albums',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LibraryAlbumsPage()),
                      ),
                    ),
                    _LibraryMenuItem(
                      key: const ValueKey('library_following_item'),
                      title: 'Following',
                      onTap: () => context.push('/library/following'),
                    ),
                    _LibraryMenuItem(
                      key: const ValueKey('library_stations_item'),
                      title: 'Stations',
                      onTap: () => context.push('/library/stations'),
                    ),
                    _LibraryMenuItem(
                      key: const ValueKey('library_insights_item'),
                      title: 'Your insights',
                      onTap: () => context.push('/library/insights'),
                    ),
                    _LibraryMenuItem(
                      key: const ValueKey('library_uploads_item'),
                      title: 'Your uploads',
                      onTap: () => context.push('/library/uploads'),
                    ),

                    const SizedBox(height: 32),

                    // ── Recently played ───────────
                    GestureDetector(
                      onTap: () => context.push('/player/recent'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Recently played',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RecentTracksPreview(
                      tracks: recentTracks,
                      isLoading:
                          localHistory.isLoading || serverHistory.isLoading,
                      onOpen: () => context.push('/player/recent'),
                      onTrackTap: (track) =>
                          ref.read(playerProvider.notifier).playTrack(track),
                    ),

                    const SizedBox(height: 32),

                    // ── Listening history ─────────
                    GestureDetector(
                      onTap: () => context.push('/player/history'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Listening history',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _HistoryPreview(
                      entries: historyEntries,
                      isLoading:
                          serverHistory.isLoading || localHistory.isLoading,
                      onOpen: () => context.push('/player/history'),
                      onTrackTap: (track) =>
                          ref.read(playerProvider.notifier).playTrack(track),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _LibraryMenuItem({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 15),
          ],
        ),
      ),
    );
  }
}

class _LibraryAvatar extends StatelessWidget {
  final AsyncValue<String> avatarAsync;

  const _LibraryAvatar({required this.avatarAsync});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = avatarAsync.maybeWhen(
      data: (value) => value,
      orElse: () => '',
    );
    final hasAvatar = avatarUrl.isNotEmpty &&
        avatarUrl.startsWith('http') &&
        !avatarUrl.contains('default-avatar');

    return CircleAvatar(
      key: ValueKey(avatarUrl),
      radius: 18,
      backgroundColor: const Color(0xFF2A2A2A),
      backgroundImage: hasAvatar ? CachedNetworkImageProvider(avatarUrl) : null,
      child: hasAvatar
          ? null
          : const Icon(Icons.person, color: Colors.white, size: 34),
    );
  }
}

class _RecentTracksPreview extends StatelessWidget {
  final List<PlayerTrack> tracks;
  final bool isLoading;
  final VoidCallback onOpen;
  final ValueChanged<PlayerTrack> onTrackTap;

  const _RecentTracksPreview({
    required this.tracks,
    required this.isLoading,
    required this.onOpen,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return _EmptyLibraryPreview(
        isLoading: isLoading,
        text: 'Find all your recently played content here.',
        onTap: onOpen,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: tracks
            .take(3)
            .map((track) => _LibraryTrackTile(
                  track: track,
                  onTap: () => onTrackTap(track),
                ))
            .toList(),
      ),
    );
  }
}

class _HistoryPreview extends StatelessWidget {
  final List<HistoryEntry> entries;
  final bool isLoading;
  final VoidCallback onOpen;
  final ValueChanged<PlayerTrack> onTrackTap;

  const _HistoryPreview({
    required this.entries,
    required this.isLoading,
    required this.onOpen,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyLibraryPreview(
        isLoading: isLoading,
        text: "Find all the tracks you've listened to here.",
        onTap: onOpen,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: entries
            .take(3)
            .map((entry) => _LibraryTrackTile(
                  track: entry.track,
                  trailing: _formatTime(entry.playedAt),
                  onTap: () => onTrackTap(entry.track),
                ))
            .toList(),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _EmptyLibraryPreview extends StatelessWidget {
  final bool isLoading;
  final String text;
  final VoidCallback onTap;

  const _EmptyLibraryPreview({
    required this.isLoading,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF5500),
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

class _LibraryTrackTile extends StatelessWidget {
  final PlayerTrack track;
  final String? trailing;
  final VoidCallback onTap;

  const _LibraryTrackTile({
    required this.track,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = track.coverUrl;
    final hasCover = coverUrl != null && coverUrl.startsWith('http');

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 44,
          height: 44,
          child: hasCover
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _coverFallback(),
                )
              : _coverFallback(),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: trailing == null
          ? const Icon(Icons.play_arrow_rounded,
              color: Colors.white38, size: 20)
          : Text(
              trailing!,
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
      onTap: onTap,
    );
  }

  static Widget _coverFallback() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.music_note, color: Colors.white24, size: 22),
        ),
      );
}
