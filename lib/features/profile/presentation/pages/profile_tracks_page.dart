import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileTracksPage extends StatelessWidget {
  const ProfileTracksPage({super.key});

  static const _bg = Color(0xFF111111);

  // Mock tracks — replace with real data later
  static const _tracks = [
    _Track('It_is_realme.mp3', 'SUNDER', '1:20', null),
    _Track('Sad N Black', 'SUNDER', '1:47', null),
    _Track('I am in tiny room', 'SUNDER', '2:44', null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
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
                  // Cast icon
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
                  // Shuffle
                  GestureDetector(
                    key: const ValueKey('profile_tracks_shuffle_button'),
                    onTap: () {},
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
                  // Play
                  GestureDetector(
                    key: const ValueKey('profile_tracks_play_all_button'),
                    onTap: () {},
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 28),
                    ),
                  ),
                ],
              ),
            ),

            // ── track list ───────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _tracks.length,
                itemBuilder: (_, i) =>
                    _TrackTile(track: _tracks[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── track tile ───────────────────────────────────────────────────────
class _TrackTile extends StatelessWidget {
  final _Track track;
  const _TrackTile({required this.track});

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withOpacity(0.55);
    return GestureDetector(
      key: const ValueKey('profile_tracks_tile'),
      onTap: () {},
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 56,
                height: 56,
                color: const Color(0xFF6699BB),
                child: track.imageColor != null
                    ? ColoredBox(color: track.imageColor!)
                    : const Icon(Icons.person,
                        color: Colors.white70, size: 30),
              ),
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
                  const SizedBox(height: 3),
                  Text(track.duration,
                      style: TextStyle(color: sub, fontSize: 12)),
                ],
              ),
            ),
            // More button
            GestureDetector(
              key: const ValueKey('profile_tracks_more_button'),
              onTap: () {},
              child: Icon(Icons.more_vert_rounded,
                  color: sub, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── model ────────────────────────────────────────────────────────────
class _Track {
  final String title;
  final String artist;
  final String duration;
  final Color? imageColor;
  const _Track(this.title, this.artist, this.duration, this.imageColor);
}