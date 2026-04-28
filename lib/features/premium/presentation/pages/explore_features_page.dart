import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/subscription_provider.dart';

class ExploreFeaturesPage extends ConsumerWidget {
  const ExploreFeaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);
    final planType = sub.planType ?? 'Pro';
    final features = _featuresForPlan(planType);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: Text(
          '$planType — Your Features',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: features.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFF2A2A2A), height: 1),
        itemBuilder: (context, i) {
          final f = features[i];
          final isAdFree = f.title == 'Ad-free Listening';
          final hasAction = f.route != null || isAdFree;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5500).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(f.icon, color: const Color(0xFFFF5500), size: 22),
            ),
            title: Text(
              f.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                f.subtitle,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ),
            trailing: hasAction
                ? const Icon(Icons.chevron_right,
                    color: Colors.white38, size: 22)
                : null,
            onTap: hasAction
                ? () {
                    if (isAdFree) {
                      _showAdFreeDialog(context);
                    } else if (f.route != null) {
                      context.push(f.route!);
                    }
                  }
                : null,
          );
        },
      ),
    );
  }

  void _showAdFreeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.music_off, color: Color(0xFFFF5500), size: 22),
            SizedBox(width: 10),
            Text('Ad-free Listening',
                style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Your plan includes ad-free listening. No ads exist in this build — if ads are introduced in the future, your plan will keep them off automatically.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it',
                style: TextStyle(color: Color(0xFFFF5500))),
          ),
        ],
      ),
    );
  }

  List<_Feature> _featuresForPlan(String planType) {
    if (planType == 'Go+') {
      return [
        // Ad-free is a subscription perk label; no ad system exists in-app yet.
        const _Feature(
          icon: Icons.music_off,
          title: 'Ad-free Listening',
          subtitle: 'Enjoy uninterrupted music with no ads between tracks.',
          route: null,
        ),
        const _Feature(
          icon: Icons.download_outlined,
          title: 'Offline Downloads',
          subtitle: 'Download tracks and listen without internet.',
          route: '/upgrade/offline',
        ),
        const _Feature(
          icon: Icons.headphones,
          title: 'Premium Streaming Access',
          subtitle: 'Access the full SoundCloud catalog without restrictions.',
          route: '/home',
        ),
      ];
    }

    // Artist Pro plan
    return [
      const _Feature(
        icon: Icons.cloud_upload_outlined,
        title: 'Unlimited Uploads',
        subtitle: 'Upload as many tracks as you want — no cap.',
        route: '/library/uploads',
      ),
      const _Feature(
        icon: Icons.playlist_add,
        title: 'Unlimited Playlists',
        subtitle: 'Create as many playlists as you need.',
        route: '/playlist/create',
      ),
      // Ad-free is a subscription perk label; no ad system exists in-app yet.
      const _Feature(
        icon: Icons.music_off,
        title: 'Ad-free Listening',
        subtitle: 'Enjoy uninterrupted music with no ads between tracks.',
        route: null,
      ),
      const _Feature(
        icon: Icons.download_outlined,
        title: 'Offline Downloads',
        subtitle: 'Download and listen without internet.',
        route: '/upgrade/offline',
      ),
    ];
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;

  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
  });
}
