import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/premium/presentation/providers/subscription_provider.dart';

void main() {
  group('SubscriptionState defaults', () {
    test('isPremium is false',
        () => expect(const SubscriptionState().isPremium, isFalse));
    test('isLoading is false',
        () => expect(const SubscriptionState().isLoading, isFalse));
    test(
        'error is null', () => expect(const SubscriptionState().error, isNull));
    test('expiresAt is null',
        () => expect(const SubscriptionState().expiresAt, isNull));
    test('cancelAtPeriodEnd is false',
        () => expect(const SubscriptionState().cancelAtPeriodEnd, isFalse));
    test('planType is null',
        () => expect(const SubscriptionState().planType, isNull));
    test('offlineListening is false',
        () => expect(const SubscriptionState().offlineListening, isFalse));
    test('legacyArtistPro is false',
        () => expect(const SubscriptionState().legacyArtistPro, isFalse));
    test('isLocalPlanFallback is false',
        () => expect(const SubscriptionState().isLocalPlanFallback, isFalse));
    test('hasResolved is false',
        () => expect(const SubscriptionState().hasResolved, isFalse));
  });

  group('SubscriptionState.copyWith', () {
    const base = SubscriptionState();

    test('isPremium',
        () => expect(base.copyWith(isPremium: true).isPremium, isTrue));
    test('isLoading',
        () => expect(base.copyWith(isLoading: true).isLoading, isTrue));
    test('error', () => expect(base.copyWith(error: 'oops').error, 'oops'));
    test(
        'expiresAt',
        () => expect(
            base.copyWith(expiresAt: '2025-01-01').expiresAt, '2025-01-01'));
    test('clearExpiresAt', () {
      final s = base.copyWith(expiresAt: '2025-01-01');
      expect(s.copyWith(clearExpiresAt: true).expiresAt, isNull);
    });
    test(
        'cancelAtPeriodEnd',
        () => expect(
            base.copyWith(cancelAtPeriodEnd: true).cancelAtPeriodEnd, isTrue));
    test('planType',
        () => expect(base.copyWith(planType: 'premium').planType, 'premium'));
    test(
        'offlineListening',
        () => expect(
            base.copyWith(offlineListening: true).offlineListening, isTrue));
    test(
        'legacyArtistPro',
        () => expect(
            base.copyWith(legacyArtistPro: true).legacyArtistPro, isTrue));
    test(
        'isLocalPlanFallback',
        () => expect(
            base.copyWith(isLocalPlanFallback: true).isLocalPlanFallback,
            isTrue));
    test('hasResolved',
        () => expect(base.copyWith(hasResolved: true).hasResolved, isTrue));

    test('preserves all fields when no args given', () {
      const s = SubscriptionState(
        isPremium: true,
        planType: 'go+',
        hasResolved: true,
        offlineListening: true,
      );
      final copy = s.copyWith();
      expect(copy.isPremium, isTrue);
      expect(copy.planType, 'go+');
      expect(copy.hasResolved, isTrue);
      expect(copy.offlineListening, isTrue);
    });

    test('full premium user state', () {
      final s = base.copyWith(
        isPremium: true,
        planType: 'premium',
        hasResolved: true,
        offlineListening: true,
        expiresAt: '2026-01-01',
        cancelAtPeriodEnd: false,
      );
      expect(s.isPremium, isTrue);
      expect(s.planType, 'premium');
      expect(s.hasResolved, isTrue);
      expect(s.offlineListening, isTrue);
      expect(s.expiresAt, '2026-01-01');
    });

    test('free user state', () {
      final s = base.copyWith(
        isPremium: false,
        planType: 'free',
        hasResolved: true,
      );
      expect(s.isPremium, isFalse);
      expect(s.planType, 'free');
      expect(s.hasResolved, isTrue);
    });

    test('loading state', () {
      final s = base.copyWith(isLoading: true);
      expect(s.isLoading, isTrue);
      expect(s.hasResolved, isFalse);
    });

    test('error state', () {
      final s = base.copyWith(error: 'network error', isLoading: false);
      expect(s.error, 'network error');
      expect(s.isLoading, isFalse);
    });

    test('local plan fallback state', () {
      final s = base.copyWith(
        isPremium: true,
        isLocalPlanFallback: true,
        planType: 'premium',
      );
      expect(s.isLocalPlanFallback, isTrue);
      expect(s.isPremium, isTrue);
    });
  });
}
