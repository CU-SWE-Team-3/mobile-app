import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ── Mock data — replace with real data later ──
const _mockReposts = [
  _Repost(
    title: 'Nasser _ ناصر',
    artist: 'wigexpress',
    plays: '1M',
    duration: '2:52',
    imageUrl: null,
    imageColor: Color(0xFF1A1A2E),
  ),
  _Repost(
    title: 'ZIAD ZAZA - SAM3 AKHINA | ... زياد',
    artist: 'Abouelhassan',
    plays: '1.7M',
    duration: '2:13',
    imageUrl: null,
    imageColor: Color(0xFFB03A2E),
  ),
  _Repost(
    title: 'ZIAD ZAZA - EMSHI | زياد ظاظا - إمشي',
    artist: 'Maro mafia',
    plays: '2.3M',
    duration: '3:40',
    imageUrl: null,
    imageColor: Color(0xFF1F618D),
  ),
];

class ProfileRepostsPage extends StatelessWidget {
  const ProfileRepostsPage({super.key});

  static const _bg = Color(0xFF111111);

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
                    onTap: () => context.pop(),
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
                    'Reposts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
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

            // ── repost list ──────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _mockReposts.length,
                itemBuilder: (_, i) =>
                    _RepostTile(repost: _mockReposts[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── repost tile ──────────────────────────────────────────────────────────
class _RepostTile extends StatelessWidget {
  final _Repost repost;
  const _RepostTile({required this.repost});

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withOpacity(0.55);
    return GestureDetector(
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
                color: repost.imageColor,
                child: repost.imageUrl != null
                    ? Image.network(repost.imageUrl!,
                        fit: BoxFit.cover)
                    : const Icon(Icons.music_note,
                        color: Colors.white38, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repost.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(repost.artist,
                      style: TextStyle(color: sub, fontSize: 13)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 13, color: sub),
                      Text(
                        '  ${repost.plays} · ${repost.duration}',
                        style: TextStyle(color: sub, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // More button
            GestureDetector(
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

// ── model ────────────────────────────────────────────────────────────────
class _Repost {
  final String title;
  final String artist;
  final String plays;
  final String duration;
  final String? imageUrl;
  final Color imageColor;

  const _Repost({
    required this.title,
    required this.artist,
    required this.plays,
    required this.duration,
    this.imageUrl,
    required this.imageColor,
  });
}