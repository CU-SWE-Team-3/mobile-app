import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/subscription_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Plan data model
// ─────────────────────────────────────────────────────────────────────────────

class _PlanData {
  final String displayName;
  final String backendPlanType; // sent to checkout(); billingCycle is UI-only
  final String billingCycle;   // "Yearly" | "Monthly" — NOT sent to backend
  final String badge;
  final String titleIcon;
  final String price;
  final String? priceSecondary;
  final List<String> features;

  const _PlanData({
    required this.displayName,
    required this.backendPlanType,
    required this.billingCycle,
    required this.badge,
    required this.titleIcon,
    required this.price,
    this.priceSecondary,
    required this.features,
  });
}

// 4 cards: Artist Pro Yearly, Artist Pro Monthly, Go+ Yearly, Go+ Monthly.
// billingCycle is UI-only — the backend checkout endpoint accepts only
// { planType: "Pro" } or { planType: "Go+" } without a billing-cycle field.
const _kPlans = [
  _PlanData(
    displayName: 'Artist Pro',
    backendPlanType: 'Pro',
    billingCycle: 'Yearly',
    badge: 'FOR ARTISTS',
    titleIcon: '✦',
    price: 'EGP 1,055.00/year',
    priceSecondary: 'or EGP 175.00/month',
    features: [
      'Unlimited audio uploads',
      'Unlimited playlists',
      'Ad-free listening',
      'Offline downloads',
    ],
  ),
  _PlanData(
    displayName: 'Artist Pro',
    backendPlanType: 'Pro',
    billingCycle: 'Monthly',
    badge: 'FOR ARTISTS',
    titleIcon: '✦',
    price: 'EGP 175.00/month',
    priceSecondary: null,
    features: [
      'Unlimited audio uploads',
      'Unlimited playlists',
      'Ad-free listening',
      'Offline downloads',
    ],
  ),
  _PlanData(
    displayName: 'Go+',
    backendPlanType: 'Go+',
    billingCycle: 'Yearly',
    badge: 'FOR LISTENERS',
    titleIcon: '♦',
    price: 'EGP 790.00/year',
    priceSecondary: 'or EGP 99.00/month',
    features: [
      'Ad-free listening',
      'Offline downloads',
      'Premium streaming access',
    ],
  ),
  _PlanData(
    displayName: 'Go+',
    backendPlanType: 'Go+',
    billingCycle: 'Monthly',
    badge: 'FOR LISTENERS',
    titleIcon: '♦',
    price: 'EGP 99.00/month',
    priceSecondary: null,
    features: [
      'Ad-free listening',
      'Offline downloads',
      'Premium streaming access',
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class PricingTiersPage extends ConsumerStatefulWidget {
  const PricingTiersPage({super.key});

  @override
  ConsumerState<PricingTiersPage> createState() => _PricingTiersPageState();
}

class _PricingTiersPageState extends ConsumerState<PricingTiersPage> {
  // viewportFraction < 1 lets neighboring cards peek in from the sides.
  // clipBehavior: Clip.none on the PageView is required to actually show them.
  final PageController _pageController =
      PageController(viewportFraction: 0.86);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('[PricingTiers] total plan cards: ${_kPlans.length}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _currentPage = i);
    final plan = _kPlans[i];
    debugPrint(
      '[PricingTiers] page=$i  name="${plan.displayName}"  '
      'backendPlanType="${plan.backendPlanType}"  billing="${plan.billingCycle}"',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B1DC8), Color(0xFFE0188A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Close ──────────────────────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  onPressed: () => context.pop(),
                ),
              ),

              // ── Header ─────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's next in music is\nfirst on SoundCloud",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Whether you want to share your sound or enjoy\n'
                      'ad-free listening, we have the right plan for you.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Active plan banner ──────────────────────────────────────
              if (sub.isPremium && sub.planType != null && !sub.cancelAtPeriodEnd)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified,
                            color: Color(0xFF00C853), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Active: ${sub.planType}',
                          style: const TextStyle(
                            color: Color(0xFF00C853),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Plan cards carousel ─────────────────────────────────────
              // clipBehavior: Clip.none is required so that the neighboring
              // cards (visible because viewportFraction < 1) are not clipped.
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  clipBehavior: Clip.none,
                  itemCount: _kPlans.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) {
                    final plan = _kPlans[i];
                    final alreadySubscribed =
                        sub.isPremium && !sub.cancelAtPeriodEnd;
                    return _PlanCard(
                      plan: plan,
                      isLoading: sub.isLoading,
                      isCurrentPlan:
                          sub.isPremium && sub.planType == plan.backendPlanType,
                      onSubscribe: () {
                        if (alreadySubscribed) {
                          // Do not call checkout — user is subscribed.
                          // Navigate to subscription management instead.
                          context.push('/upgrade/status');
                        } else {
                          ref
                              .read(subscriptionProvider.notifier)
                              .checkout(plan.backendPlanType);
                        }
                      },
                      error: sub.error,
                    );
                  },
                ),
              ),

              // ── 4-dot page indicator ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_kPlans.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan card
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _PlanData plan;
  final bool isLoading;
  final bool isCurrentPlan;
  final VoidCallback onSubscribe;
  final String? error;

  const _PlanCard({
    required this.plan,
    required this.isLoading,
    required this.isCurrentPlan,
    required this.onSubscribe,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: isCurrentPlan
              ? Border.all(color: const Color(0xFF00C853), width: 1.5)
              : null,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Audience + billing badges ─────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Badge(label: plan.badge, color: const Color(0xFF1A6FFF)),
                  _Badge(
                    label: plan.billingCycle.toUpperCase(),
                    color: plan.billingCycle == 'Yearly'
                        ? const Color(0xFF6B1DC8)
                        : const Color(0xFF444446),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Plan name ─────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    plan.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    plan.titleIcon,
                    style: const TextStyle(
                      color: Color(0xFFFFAA00),
                      fontSize: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // ── Price ─────────────────────────────────────────────────
              Text(
                plan.price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (plan.priceSecondary != null)
                Text(
                  plan.priceSecondary!,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 13),
                ),

              const SizedBox(height: 20),

              // ── Features ──────────────────────────────────────────────
              ...plan.features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check,
                          color: Color(0xFFFF5500), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Subscribe button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isCurrentPlan || isLoading ? null : onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isCurrentPlan ? const Color(0xFF00C853) : Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isCurrentPlan ? '✓ Current Plan' : 'Subscribe now',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 10),

              RichText(
                text: const TextSpan(
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  children: [
                    TextSpan(text: 'Cancel anytime. '),
                    TextSpan(
                      text: 'Restrictions apply',
                      style: TextStyle(color: Color(0xFF1A6FFF)),
                    ),
                  ],
                ),
              ),

              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
