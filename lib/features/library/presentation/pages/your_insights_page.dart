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

         Image.asset('assets/images/SoundCloud_Insignts.1.png',
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
          

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

          // ── Upload button ────────────────────────────────────────────────
SizedBox(
  width: double.infinity,
  child: OutlinedButton(
    onPressed: () => context.push('/upload'),
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Colors.white),
      //backgroundColor: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    child: const Text(
      'Upload',
      style: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
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
          
          Image.asset('assets/images/SoundCloud_Ins.2.png', 
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
                        const SizedBox(height: 24),

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

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Upgrade to Artist Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 60),

        ],
      ),
    );
  }
}