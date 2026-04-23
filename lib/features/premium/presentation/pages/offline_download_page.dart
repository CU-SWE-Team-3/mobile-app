import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/subscription_provider.dart';

class OfflineDownloadPage extends ConsumerWidget {
  const OfflineDownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(subscriptionProvider).isPremium;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Offline Downloads',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero icon ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFF1A3300)
                      : const Color(0xFF1C1C1E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPremium
                      ? Icons.download_done_rounded
                      : Icons.lock_outline_rounded,
                  color: isPremium
                      ? const Color(0xFF4CAF50)
                      : Colors.white38,
                  size: 48,
                ),
              ),
            ),

            const SizedBox(height: 28),

            Center(
              child: Text(
                isPremium
                    ? 'Offline Downloads Unlocked'
                    : 'Listen Anywhere, Anytime',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                isPremium
                    ? 'You can download tracks directly from the player. Look for the download button on any track.'
                    : 'Download your favorite tracks and listen without an internet connection. Available with Artist Pro and Go+ plans.',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 36),

            // ── Feature rows ───────────────────────────────────────────
            _FeatureRow(
              icon: Icons.wifi_off,
              title: 'No internet needed',
              subtitle: 'Listen offline on the go.',
              locked: !isPremium,
            ),
            _FeatureRow(
              icon: Icons.high_quality,
              title: 'High-quality audio',
              subtitle: 'Downloads in original quality.',
              locked: !isPremium,
            ),
            _FeatureRow(
              icon: Icons.library_music_outlined,
              title: 'Your library, always available',
              subtitle: 'Sync tracks and playlists.',
              locked: !isPremium,
            ),

            const Spacer(),

            // ── CTA ────────────────────────────────────────────────────
            if (!isPremium)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/upgrade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5500),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Upgrade to unlock downloads',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: locked
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFF1A3300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: locked ? Colors.white24 : const Color(0xFF4CAF50),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: locked ? Colors.white38 : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock, color: Colors.white24, size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: locked ? Colors.white24 : Colors.white54,
                    fontSize: 13,
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
