import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/subscription_provider.dart';

class SubscriptionStatusPage extends ConsumerWidget {
  const SubscriptionStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Your Subscription',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: () =>
                ref.read(subscriptionProvider.notifier).refreshFromProfile(),
          ),
        ],
      ),
      body: sub.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            )
          : _StatusBody(sub: sub),
    );
  }
}

class _StatusBody extends ConsumerWidget {
  final SubscriptionState sub;
  const _StatusBody({required this.sub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status card ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sub.isPremium
                  ? const Color(0xFF1A3300)
                  : const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sub.isPremium
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF3A3A3C),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      sub.isPremium ? Icons.verified : Icons.lock_outline,
                      color: sub.isPremium
                          ? const Color(0xFF4CAF50)
                          : Colors.white38,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      sub.isPremium ? 'Premium Active' : 'Free Plan',
                      style: TextStyle(
                        color: sub.isPremium
                            ? const Color(0xFF4CAF50)
                            : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                if (sub.isPremium && sub.planType != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Plan: ${sub.planType}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],

                if (sub.cancelAtPeriodEnd && sub.expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Active until ${_formatDate(sub.expiresAt!)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Actions ──────────────────────────────────────────────────
          if (sub.isPremium && !sub.cancelAtPeriodEnd) ...[
            const Text(
              'Manage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => _confirmCancel(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: const Text(
                  'Cancel Subscription',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You will retain access until the end of your current billing period.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],

          if (!sub.isPremium) ...[
            const SizedBox(height: 8),
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
                  'Upgrade to Premium',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],

          if (sub.error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

          // ── Perks reminder ───────────────────────────────────────────
          if (sub.isPremium) ...[
            const Text(
              'Your perks',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const _PerkTile(Icons.cloud_upload_outlined, 'Unlimited uploads'),
            const _PerkTile(Icons.bar_chart, 'Advanced audience insights'),
            const _PerkTile(Icons.download_outlined, 'Track downloads'),
            const _PerkTile(Icons.attach_money, 'Revenue sharing'),
            const _PerkTile(Icons.push_pin_outlined, 'Pin favorite tracks'),
          ],
        ],
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
          'You will keep premium features until your current billing period ends.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep plan',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(subscriptionProvider.notifier).cancelSubscription();
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

class _PerkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PerkTile(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
