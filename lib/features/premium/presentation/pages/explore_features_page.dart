import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/subscription_provider.dart'
    show SubscriptionEntitlements, subscriptionProvider;

class ExploreFeaturesPage extends ConsumerWidget {
  const ExploreFeaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);

    // Derive plan key strictly from planType — never infer from isPremium alone.
    // null planType with isPremium=true → unknown plan UI.
    final String? resolvedKey =
        !sub.isPremium ? 'Free' : sub.planType; // 'Pro', 'Go+', or null

    final String appBarTitle;
    if (resolvedKey == 'Pro') {
      appBarTitle = 'Artist Pro - Your Features';
    } else if (resolvedKey == 'Go+') {
      appBarTitle = 'Go+ - Your Features';
    } else if (resolvedKey == 'Free') {
      appBarTitle = 'Free Plan - Features';
    } else {
      appBarTitle = 'Your Subscription';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: Text(
          appBarTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
            onPressed: () =>
                ref.read(subscriptionProvider.notifier).refreshFromProfile(),
          ),
        ],
      ),
      body: resolvedKey == null
          ? _UnknownPlanBody(
              isLocalFallback: sub.isLocalPlanFallback,
              onRefresh: () =>
                  ref.read(subscriptionProvider.notifier).refreshFromProfile(),
              onManage: () => context.push('/upgrade/status'),
            )
          : _FeatureList(
              planKey: resolvedKey,
              sub: sub,
            ),
    );
  }
}

// ── Unknown plan body ─────────────────────────────────────────────────────────

class _UnknownPlanBody extends StatelessWidget {
  final bool isLocalFallback;
  final VoidCallback onRefresh;
  final VoidCallback onManage;

  const _UnknownPlanBody({
    required this.isLocalFallback,
    required this.onRefresh,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline_rounded,
                color: Colors.orange, size: 38),
          ),
          const SizedBox(height: 24),
          const Text(
            'Subscription Active',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isLocalFallback
                ? 'Your payment was received. Plan details are still syncing from the server — try refreshing in a moment.'
                : 'Your subscription is active, but plan details could not be loaded. Sign out and back in to restore your plan, or tap Refresh.',
            style:
                const TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: onManage,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
              ),
              child: const Text('Manage Subscription',
                  style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature list ──────────────────────────────────────────────────────────────

class _FeatureList extends ConsumerWidget {
  final String planKey; // 'Free', 'Pro', 'Go+'
  final dynamic sub;

  const _FeatureList({required this.planKey, required this.sub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = _featuresForPlan(planKey);

    return ListView.separated(
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
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          trailing: hasAction
              ? const Icon(Icons.chevron_right, color: Colors.white38, size: 22)
              : null,
          onTap: hasAction
              ? () {
                  if (isAdFree) {
                    _showAdFreeDialog(context, planKey);
                  } else if (f.route != null) {
                    context.push(f.route!);
                  }
                }
              : null,
        );
      },
    );
  }

  void _showAdFreeDialog(BuildContext context, String planKey) {
    final message = planKey == 'Free'
        ? 'Upgrade to Artist Pro or Go+ to remove ads.'
        : planKey == 'Go+'
            ? 'Go+ removes mock audio ads from playback.'
            : 'Artist Pro removes mock audio ads from playback.';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.music_off, color: Color(0xFFFF5500), size: 22),
            SizedBox(width: 10),
            Text(
              'Ad-free Listening',
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          message,
          style:
              const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
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

  List<_Feature> _featuresForPlan(String planKey) {
    if (planKey == 'Free') {
      return [
        const _Feature(
          icon: Icons.lock_outline,
          title: 'Ad-free Listening',
          subtitle: 'Upgrade to remove mock audio ads from playback.',
          route: null,
        ),
        const _Feature(
          icon: Icons.cloud_upload_outlined,
          title: 'Starter Uploads',
          subtitle: 'Upload up to 3 tracks and share your sound.',
          route: '/library/uploads',
        ),
        const _Feature(
          icon: Icons.playlist_add,
          title: 'Playlists',
          subtitle: 'Create playlists and organize your favorite tracks.',
          route: '/playlist/create',
        ),
      ];
    }

    if (planKey == 'Go+') {
      return [
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
          icon: Icons.cloud_upload_outlined,
          title: 'Uploads (up to 3)',
          subtitle: 'Go+ includes 3 track uploads.',
          route: '/library/uploads',
        ),
      ];
    }

    // 'Pro' / Artist Pro
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
      const _Feature(
        icon: Icons.music_off,
        title: 'Ad-free Listening',
        subtitle: 'Enjoy uninterrupted music with no ads between tracks.',
        route: null,
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
