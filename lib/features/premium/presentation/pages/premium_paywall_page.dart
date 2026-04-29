import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/subscription_provider.dart' show subscriptionProvider, planDisplayName;

class PremiumPaywallPage extends ConsumerWidget {
  const PremiumPaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);

    // Already subscribed — show management view instead of subscribe UI
    if (sub.isPremium) {
      return const _SubscribedView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ── Hero image area ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 380,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A0533), Color(0xFF3D1A00)],
                      ),
                    ),
                  ),
                  // Decorative circles mimicking artist photo feel
                  Positioned(
                    top: 40,
                    left: 60,
                    child: _GlowCircle(size: 220, color: const Color(0xFFFF5500).withOpacity(0.18)),
                  ),
                  Positioned(
                    top: 20,
                    right: 30,
                    child: _GlowCircle(size: 160, color: const Color(0xFF9B3FFF).withOpacity(0.22)),
                  ),
                  // Simulated stacked-card look
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: 0.12,
                            child: Container(
                              width: 220,
                              height: 260,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C1A00),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          Container(
                            width: 220,
                            height: 260,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF3A2200), Color(0xFF1A1000)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              color: Color(0xFFFF5500),
                              size: 80,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Badge row
                  const Row(
                    children: [
                      _Pill(
                        label: '✦ ARTIST PRO',
                        color: Colors.white,
                        textColor: Colors.black,
                      ),
                      SizedBox(width: 8),
                      _Pill(
                        label: 'FOR ARTISTS',
                        color: Color(0xFF1A6FFF),
                        textColor: Colors.white,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Headline
                  const Text(
                    'Unlock artist tools\n& unlimited uploads.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Price line
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(
                          text: 'For EGP 175.00, billed monthly.\nCancel anytime. ',
                        ),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => context.push('/upgrade/pricing'),
                            child: const Text(
                              'See all plans',
                              style: TextStyle(
                                color: Color(0xFF1A6FFF),
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: sub.isLoading
                          ? null
                          : () => ref
                              .read(subscriptionProvider.notifier)
                              .checkout('Pro'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        elevation: 0,
                      ),
                      child: sub.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Get Artist Pro',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  // View all plans link
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/upgrade/pricing'),
                      child: const Text(
                        'See all plans',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  if (sub.error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sub.error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Feature list
                  const _FeatureRow(
                    icon: Icons.cloud_upload_outlined,
                    text: 'Unlimited audio uploads',
                  ),
                  const _FeatureRow(
                    icon: Icons.playlist_add,
                    text: 'Unlimited playlists',
                  ),
                  const _FeatureRow(
                    icon: Icons.music_off,
                    text: 'Ad-free listening',
                  ),
                  const _FeatureRow(
                    icon: Icons.download_outlined,
                    text: 'Offline downloads',
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Already-subscribed management view ────────────────────────────────────────

class _SubscribedView extends ConsumerWidget {
  const _SubscribedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);
    final planName = planDisplayName(sub.planType);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.verified,
                    color: Color(0xFF00C853), size: 40),
              ),
              const SizedBox(height: 24),

              Text(
                'You are on $planName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Your subscription is active.\nExplore all your premium features.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 15, height: 1.55),
              ),

              if (sub.cancelAtPeriodEnd) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sub.expiresAt != null
                        ? 'Active until ${_formatDate(sub.expiresAt!)}. Renew below.'
                        : 'Cancels at end of billing period.',
                    style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],

              if (sub.error != null) ...[
                const SizedBox(height: 12),
                Text(sub.error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13)),
              ],

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.push('/upgrade/features'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5500),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Explore Features',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.push('/upgrade/status'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                  ),
                  child: const Text(
                    'Manage Subscription',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel subscription — only shown if not already canceling
              if (!sub.cancelAtPeriodEnd)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: sub.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.redAccent, strokeWidth: 2))
                      : OutlinedButton(
                          onPressed: () =>
                              _confirmCancel(context, ref),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side:
                                const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32)),
                          ),
                          child: const Text(
                            'Cancel Subscription',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Cancel subscription?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You will keep premium access until your current billing period ends.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep plan',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(subscriptionProvider.notifier)
                  .cancelSubscription();
            },
            child: const Text('Cancel plan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF5500), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
