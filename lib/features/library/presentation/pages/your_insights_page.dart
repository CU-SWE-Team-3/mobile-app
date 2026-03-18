import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class YourInsightsPage extends StatefulWidget {
  const YourInsightsPage({super.key});

  @override
  State<YourInsightsPage> createState() => _YourInsightsPageState();
}

class _YourInsightsPageState extends State<YourInsightsPage> {
  int _selectedTab = 0; // 0 = SoundCloud, 1 = All Platforms

  static const _bg = Color(0xFF111111);
  static const _orange = Color(0xFFFF5500);

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
                    'Your insights',
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── tab bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _TabItem(
                    label: 'SoundCloud',
                    selected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  const SizedBox(width: 24),
                  _TabItem(
                    label: 'All Platforms',
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ],
              ),
            ),

            // ── tab content ───────────────────────────────────────────
            Expanded(
              child: _selectedTab == 0
                  ? _SoundCloudTab()
                  : _AllPlatformsTab(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab indicator ────────────────────────────────────────────────────────
class _TabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white38,
              fontSize: 15,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          if (selected)
            Container(
              height: 2,
              width: label.length * 8.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

// ── SoundCloud Tab ───────────────────────────────────────────────────────
class _SoundCloudTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // ── illustration placeholder ─────────────────────────────
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Orange waveform bars illustration
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(18, (i) {
                    final heights = [
                      20.0, 35.0, 50.0, 30.0, 60.0, 45.0, 70.0,
                      55.0, 80.0, 65.0, 90.0, 70.0, 55.0, 40.0,
                      60.0, 35.0, 25.0, 15.0
                    ];
                    final isOrange = i > 8;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: heights[i],
                      decoration: BoxDecoration(
                        color: isOrange
                            ? const Color(0xFFFF5500)
                            : Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Knobs
                    for (int i = 0; i < 3; i++) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5500),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.black, width: 2),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // Slider bar
                    Container(
                      width: 80,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5500),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── headline ─────────────────────────────────────────────
          const Text(
            'Get unmatched insights into your listeners that you won\'t find anywhere else.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 20),

          // ── description ──────────────────────────────────────────
          Text(
            'SoundCloud is the only platform that lets you easily identify and connect with your top fans based on their listening and engagement habits.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'To get started, all it takes is an upload.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 28),

          // ── Upload button (button only, no navigation) ────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Upload',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ── All Platforms Tab ────────────────────────────────────────────────────
class _AllPlatformsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // ── illustration placeholder ─────────────────────────────
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Purple/pink device illustration
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1B6B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF6B3FA0), width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Waveform
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(8, (i) {
                          final h = [8.0, 16.0, 12.0, 20.0,
                              14.0, 18.0, 10.0, 6.0];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 2),
                            width: 6,
                            height: h[i],
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius:
                                  BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      // Playback controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fast_rewind_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 20),
                          const SizedBox(width: 12),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 18),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.fast_forward_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
                // Pink music note decoration
                Positioned(
                  top: 30,
                  right: 60,
                  child: Icon(Icons.music_note,
                      color: Colors.pink[300], size: 40),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── headline ─────────────────────────────────────────────
          const Text(
            'Unlock key performance and audience insights across multiple platforms for your music',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 20),

          // ── description ──────────────────────────────────────────
          Text(
            'Access audience and performance insights for your distributed tracks from Spotify, Apple Music, and SoundCloud all from one dashboard.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Upgrade your account, upload and distribute your track to get started.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 28),

          // ── Upgrade to Artist Pro button (button only) ────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Upgrade to Artist Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}