import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/mock_audio_ad_provider.dart';
import 'package:soundcloud_clone/features/premium/presentation/providers/subscription_provider.dart';

void main() {
  group('shouldShowAdsForSubscription', () {
    test('free resolved user sees ads', () {
      expect(
        shouldShowAdsForSubscription(
          const SubscriptionState(hasResolved: true),
        ),
        isTrue,
      );
    });

    test('artist pro user does not see ads', () {
      expect(
        shouldShowAdsForSubscription(
          const SubscriptionState(
            hasResolved: true,
            isPremium: true,
            planType: 'Pro',
          ),
        ),
        isFalse,
      );
    });

    test('go plus user does not see ads', () {
      expect(
        shouldShowAdsForSubscription(
          const SubscriptionState(
            hasResolved: true,
            isPremium: true,
            planType: 'Go+',
          ),
        ),
        isFalse,
      );
    });

    test('loading subscription does not show ads', () {
      expect(
        shouldShowAdsForSubscription(
          const SubscriptionState(isLoading: true),
        ),
        isFalse,
      );
    });
  });
}
