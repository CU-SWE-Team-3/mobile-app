class Subscription {
  final bool isPremium;
  final String? planType; // "Pro" or "Go+"
  final String? expiresAt;
  final bool cancelAtPeriodEnd;

  const Subscription({
    required this.isPremium,
    this.planType,
    this.expiresAt,
    this.cancelAtPeriodEnd = false,
  });
}
