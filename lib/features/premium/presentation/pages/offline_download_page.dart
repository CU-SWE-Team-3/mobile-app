import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/offline_downloads_repository.dart';
import '../providers/subscription_provider.dart';

class OfflineDownloadPage extends ConsumerWidget {
  const OfflineDownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);
    final isGoPlus = sub.isPremium && sub.planType == 'Go+';
    final downloadsAsync = ref.watch(offlineDownloadsProvider);

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
      body: !isGoPlus
          ? _nonGoPlusBody(context, sub)
          : Column(
              children: [
                // Plan + download availability banner
                _PlanBanner(planType: sub.planType),
                Expanded(
                  child: downloadsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF5500)),
                    ),
                    error: (_, __) => const Center(
                      child: Text('Could not load downloads.',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    data: (tracks) => tracks.isEmpty
                        ? _emptyState(context)
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 32),
                            itemCount: tracks.length,
                            itemBuilder: (_, i) =>
                                _DownloadedTrackTile(track: tracks[i]),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _nonGoPlusBody(BuildContext context, SubscriptionState sub) {
    final isPro = sub.isPremium && sub.planType == 'Pro';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: Colors.white38, size: 48),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              isPro ? 'Go+ Required' : 'Listen Anywhere, Anytime',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              isPro
                  ? 'Artist Pro unlocks creator tools. Offline downloads require a Go+ subscription.'
                  : 'Download your favorite tracks and listen without an internet connection. Available with Go+.',
              style: const TextStyle(
                  color: Colors.white60, fontSize: 15, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          const _FeatureRow(
            icon: Icons.wifi_off,
            title: 'No internet needed',
            subtitle: 'Listen offline on the go.',
            locked: true,
          ),
          const _FeatureRow(
            icon: Icons.high_quality,
            title: 'High-quality audio',
            subtitle: 'Downloads in original quality.',
            locked: true,
          ),
          const _FeatureRow(
            icon: Icons.library_music_outlined,
            title: 'Your library, always available',
            subtitle: 'Sync tracks and playlists.',
            locked: true,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.go(isPro ? '/upgrade/status' : '/upgrade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
              child: Text(
                isPro ? 'Manage subscription' : 'Upgrade to unlock downloads',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1A3300),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.download_done_rounded,
                color: Color(0xFF4CAF50), size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Offline Downloads Unlocked',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'No offline downloads yet.',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Download tracks from the player to listen offline.',
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: const Text('Browse Tracks',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan banner ───────────────────────────────────────────────────────────────

class _PlanBanner extends StatelessWidget {
  final String? planType;
  const _PlanBanner({this.planType});

  @override
  Widget build(BuildContext context) {
    final isGoPlus = planType == 'Go+';
    final label = isGoPlus ? 'Offline downloads enabled' : 'Go+ required';
    final plan = planType ?? 'Free';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium,
              color: Color(0xFFFF5500), size: 18),
          const SizedBox(width: 8),
          Text(
            '$plan · $label',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Downloaded track tile ─────────────────────────────────────────────────────

class _DownloadedTrackTile extends StatelessWidget {
  final dynamic track; // OfflineDownloadedTrack

  const _DownloadedTrackTile({required this.track});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final artworkUrl = track.artworkUrl as String?;
    final hasArt = artworkUrl != null && artworkUrl.isNotEmpty;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 52,
                height: 52,
                color: const Color(0xFF2A2A2A),
                child: hasArt
                    ? CachedNetworkImage(
                        imageUrl: artworkUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.music_note,
                                color: Colors.white38, size: 24),
                      )
                    : const Icon(Icons.music_note,
                        color: Colors.white38, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            // Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artistName as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.download_done,
                          color: Color(0xFF4CAF50), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(track.downloadedAt as DateTime),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                      if (track.localPath != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.storage,
                            color: Colors.white24, size: 11),
                        const SizedBox(width: 2),
                        const Text('Saved',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature row (non-premium view only) ──────────────────────────────────────

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
            child: Icon(icon,
                color: locked ? Colors.white24 : const Color(0xFF4CAF50),
                size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: locked ? Colors.white38 : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (locked) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock,
                          color: Colors.white24, size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: locked ? Colors.white24 : Colors.white54,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
