import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/subscription_provider.dart';

class PricingTiersPage extends ConsumerStatefulWidget {
  const PricingTiersPage({super.key});

  @override
  ConsumerState<PricingTiersPage> createState() => _PricingTiersPageState();
}

class _PricingTiersPageState extends ConsumerState<PricingTiersPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
              // ── Close button ─────────────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  onPressed: () => context.pop(),
                ),
              ),

              // ── Header ───────────────────────────────────────────────
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
                      'Whether you want to share your sound or enjoy\nad-free listening, we have the right plan for you.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Plan cards ───────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _PlanCard(
                      badge: 'FOR ARTISTS',
                      title: 'Artist Pro',
                      titleIcon: '✦',
                      price: 'EGP 1,055.00/year',
                      priceMonthly: 'or EGP 175.00/month',
                      features: const [
                        'Unlock unlimited upload time',
                        'Get paid fairly for your plays',
                        'Access advanced audience insights',
                        'Replace your track without losing its stats',
                        'Pin your favorite tracks',
                      ],
                      isLoading: sub.isLoading,
                      onSubscribe: () => ref
                          .read(subscriptionProvider.notifier)
                          .checkout('Pro'),
                      error: sub.error,
                    ),
                    _PlanCard(
                      badge: 'FOR LISTENERS',
                      title: 'Go+',
                      titleIcon: '♦',
                      price: 'EGP 790.00/year',
                      priceMonthly: 'or EGP 99.00/month',
                      features: const [
                        'Ad-free listening',
                        'Offline listening & downloads',
                        'High-quality audio',
                        'Unlimited skips',
                        'Early access to new releases',
                      ],
                      isLoading: sub.isLoading,
                      onSubscribe: () => ref
                          .read(subscriptionProvider.notifier)
                          .checkout('Go+'),
                      error: sub.error,
                    ),
                  ],
                ),
              ),

              // ── Page indicator ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(2, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage ? Colors.white : Colors.white38,
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

class _PlanCard extends StatelessWidget {
  final String badge;
  final String title;
  final String titleIcon;
  final String price;
  final String priceMonthly;
  final List<String> features;
  final bool isLoading;
  final VoidCallback onSubscribe;
  final String? error;

  const _PlanCard({
    required this.badge,
    required this.title,
    required this.titleIcon,
    required this.price,
    required this.priceMonthly,
    required this.features,
    required this.isLoading,
    required this.onSubscribe,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A6FFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    titleIcon,
                    style: const TextStyle(
                      color: Color(0xFFFFAA00),
                      fontSize: 20,
                    ),
                  ),
                ],
              ),

              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                priceMonthly,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),

              const SizedBox(height: 20),

              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, color: Color(0xFFFF5500), size: 20),
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

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
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
                      : const Text(
                          'Subscribe now',
                          style: TextStyle(
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
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
