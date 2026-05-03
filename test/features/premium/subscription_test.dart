import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/premium/domain/entities/subscription.dart';
import 'package:soundcloud_clone/features/premium/presentation/providers/subscription_provider.dart';
import 'package:soundcloud_clone/features/premium/data/models/offline_downloaded_track.dart';

void main() {
  // ── Subscription entity ────────────────────────────────────────────────────

  group('Subscription entity', () {
    test('can be constructed as free user', () {
      const sub = Subscription(isPremium: false);
      expect(sub.isPremium, isFalse);
      expect(sub.planType, isNull);
      expect(sub.expiresAt, isNull);
      expect(sub.cancelAtPeriodEnd, isFalse);
    });

    test('can be constructed as Pro premium user', () {
      const sub = Subscription(isPremium: true, planType: 'Pro');
      expect(sub.isPremium, isTrue);
      expect(sub.planType, 'Pro');
    });

    test('can be constructed as Go+ premium user', () {
      const sub = Subscription(isPremium: true, planType: 'Go+');
      expect(sub.isPremium, isTrue);
      expect(sub.planType, 'Go+');
    });

    test('cancelAtPeriodEnd is false by default', () {
      const sub = Subscription(isPremium: true);
      expect(sub.cancelAtPeriodEnd, isFalse);
    });

    test('can carry expiresAt ISO string', () {
      const sub = Subscription(isPremium: true, expiresAt: '2025-12-31T00:00:00.000Z');
      expect(sub.expiresAt, '2025-12-31T00:00:00.000Z');
    });
  });

  // ── normalizeSubscriptionPlan ──────────────────────────────────────────────

  group('normalizeSubscriptionPlan', () {
    group('Pro variants', () {
      test('"pro" (lowercase) maps to "Pro"', () {
        expect(normalizeSubscriptionPlan('pro'), 'Pro');
      });
      test('"Pro" maps to "Pro"', () {
        expect(normalizeSubscriptionPlan('Pro'), 'Pro');
      });
      test('"artist pro" maps to "Pro"', () {
        expect(normalizeSubscriptionPlan('artist pro'), 'Pro');
      });
      test('"Artist Pro" maps to "Pro"', () {
        expect(normalizeSubscriptionPlan('Artist Pro'), 'Pro');
      });
      test('"artistpro" maps to "Pro"', () {
        expect(normalizeSubscriptionPlan('artistpro'), 'Pro');
      });
    });

    group('Go+ variants', () {
      test('"go+" maps to "Go+"', () {
        expect(normalizeSubscriptionPlan('go+'), 'Go+');
      });
      test('"Go+" maps to "Go+"', () {
        expect(normalizeSubscriptionPlan('Go+'), 'Go+');
      });
      test('"go plus" maps to "Go+"', () {
        expect(normalizeSubscriptionPlan('go plus'), 'Go+');
      });
      test('"goplus" maps to "Go+"', () {
        expect(normalizeSubscriptionPlan('goplus'), 'Go+');
      });
    });

    group('Free / null / empty', () {
      test('null returns null', () {
        expect(normalizeSubscriptionPlan(null), isNull);
      });
      test('empty string returns null', () {
        expect(normalizeSubscriptionPlan(''), isNull);
      });
      test('"free" returns null', () {
        expect(normalizeSubscriptionPlan('free'), isNull);
      });
      test('"Free" returns null', () {
        expect(normalizeSubscriptionPlan('Free'), isNull);
      });
    });

    group('whitespace handling', () {
      test('leading/trailing spaces are trimmed before matching', () {
        expect(normalizeSubscriptionPlan('  Pro  '), 'Pro');
        expect(normalizeSubscriptionPlan('  Go+  '), 'Go+');
      });
    });

    group('unrecognised value', () {
      test('unrecognised non-empty value is returned as-is (trimmed)', () {
        expect(normalizeSubscriptionPlan('SomeFuturePlan'), 'SomeFuturePlan');
      });
    });
  });

  // ── planDisplayName ────────────────────────────────────────────────────────

  group('planDisplayName', () {
    test('"Pro" returns "Artist Pro"', () {
      expect(planDisplayName('Pro'), 'Artist Pro');
    });

    test('"Artist Pro" returns "Artist Pro"', () {
      expect(planDisplayName('Artist Pro'), 'Artist Pro');
    });

    test('"Go+" returns "Go+"', () {
      expect(planDisplayName('Go+'), 'Go+');
    });

    test('null returns "Premium"', () {
      expect(planDisplayName(null), 'Premium');
    });

    test('empty string returns "Premium"', () {
      expect(planDisplayName(''), 'Premium');
    });

    test('unrecognised value returns "Premium"', () {
      expect(planDisplayName('Legacy'), 'Premium');
    });
  });

  // ── SubscriptionState ──────────────────────────────────────────────────────

  group('SubscriptionState', () {
    group('default values', () {
      test('initial state has safe defaults', () {
        const state = SubscriptionState();
        expect(state.isPremium, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        expect(state.expiresAt, isNull);
        expect(state.cancelAtPeriodEnd, isFalse);
        expect(state.planType, isNull);
        expect(state.offlineListening, isFalse);
        expect(state.legacyArtistPro, isFalse);
        expect(state.isLocalPlanFallback, isFalse);
        expect(state.hasResolved, isFalse);
      });
    });

    group('copyWith', () {
      test('isPremium can be toggled', () {
        const state = SubscriptionState();
        final premium = state.copyWith(isPremium: true);
        expect(premium.isPremium, isTrue);
      });

      test('planType can be set', () {
        const state = SubscriptionState(isPremium: true);
        final withPlan = state.copyWith(planType: 'Pro');
        expect(withPlan.planType, 'Pro');
      });

      test('offlineListening can be enabled', () {
        const state = SubscriptionState(isPremium: true);
        final withDownload = state.copyWith(offlineListening: true);
        expect(withDownload.offlineListening, isTrue);
      });

      test('error clears when null passed', () {
        const state = SubscriptionState(error: 'Error!');
        final cleared = state.copyWith(error: null);
        expect(cleared.error, isNull);
      });

      test('clearExpiresAt=true nullifies expiresAt', () {
        const state = SubscriptionState(expiresAt: '2025-01-01');
        final cleared = state.copyWith(clearExpiresAt: true);
        expect(cleared.expiresAt, isNull);
      });

      test('isLoading can be set', () {
        const state = SubscriptionState();
        final loading = state.copyWith(isLoading: true);
        expect(loading.isLoading, isTrue);
      });

      test('hasResolved can be set to true', () {
        const state = SubscriptionState();
        final resolved = state.copyWith(hasResolved: true);
        expect(resolved.hasResolved, isTrue);
      });

      test('cancelAtPeriodEnd can be set', () {
        const state = SubscriptionState(isPremium: true);
        final cancelled = state.copyWith(cancelAtPeriodEnd: true);
        expect(cancelled.cancelAtPeriodEnd, isTrue);
      });

      test('unchanged fields are preserved', () {
        const state = SubscriptionState(
          isPremium: true,
          planType: 'Go+',
          offlineListening: true,
        );
        final updated = state.copyWith(isLoading: false);
        expect(updated.isPremium, isTrue);
        expect(updated.planType, 'Go+');
        expect(updated.offlineListening, isTrue);
      });
    });
  });

  // ── SubscriptionEntitlements extension ────────────────────────────────────

  group('SubscriptionEntitlements extension', () {
    group('canUploadUnlimited', () {
      test('true for Pro plan', () {
        const s = SubscriptionState(isPremium: true, planType: 'Pro');
        expect(s.canUploadUnlimited, isTrue);
      });

      test('true for Artist Pro plan', () {
        const s = SubscriptionState(isPremium: true, planType: 'Artist Pro');
        expect(s.canUploadUnlimited, isTrue);
      });

      test('true for legacyArtistPro even when planType is null', () {
        const s = SubscriptionState(isPremium: true, legacyArtistPro: true);
        expect(s.canUploadUnlimited, isTrue);
      });

      test('false for Go+ plan', () {
        const s = SubscriptionState(isPremium: true, planType: 'Go+');
        expect(s.canUploadUnlimited, isFalse);
      });

      test('false for free user', () {
        const s = SubscriptionState(isPremium: false);
        expect(s.canUploadUnlimited, isFalse);
      });

      test('false when isPremium but planType is null and not legacyArtistPro', () {
        const s = SubscriptionState(isPremium: true);
        expect(s.canUploadUnlimited, isFalse);
      });
    });

    group('canDownload', () {
      test('true for Go+ plan', () {
        const s = SubscriptionState(isPremium: true, planType: 'Go+');
        expect(s.canDownload, isTrue);
      });

      test('true when offlineListening entitlement is true regardless of plan', () {
        const s = SubscriptionState(isPremium: true, planType: 'Pro', offlineListening: true);
        expect(s.canDownload, isTrue);
      });

      test('false for Pro plan without offlineListening', () {
        const s = SubscriptionState(isPremium: true, planType: 'Pro');
        expect(s.canDownload, isFalse);
      });

      test('false for free user', () {
        const s = SubscriptionState(isPremium: false);
        expect(s.canDownload, isFalse);
      });

      test('false when planType is null and offlineListening is false', () {
        const s = SubscriptionState(isPremium: true);
        expect(s.canDownload, isFalse);
      });
    });

    group('isPlanKnown', () {
      test('true for free user (isPremium=false)', () {
        const s = SubscriptionState(isPremium: false);
        expect(s.isPlanKnown, isTrue);
      });

      test('true when premium and planType is known', () {
        const s = SubscriptionState(isPremium: true, planType: 'Pro');
        expect(s.isPlanKnown, isTrue);
      });

      test('false when premium but planType is null', () {
        const s = SubscriptionState(isPremium: true);
        expect(s.isPlanKnown, isFalse);
      });
    });

    group('displayPlanName', () {
      test('"Free" for non-premium user', () {
        const s = SubscriptionState(isPremium: false);
        expect(s.displayPlanName, 'Free');
      });

      test('"Artist Pro" for Pro plan', () {
        const s = SubscriptionState(isPremium: true, planType: 'Pro');
        expect(s.displayPlanName, 'Artist Pro');
      });

      test('"Go+" for Go+ plan', () {
        const s = SubscriptionState(isPremium: true, planType: 'Go+');
        expect(s.displayPlanName, 'Go+');
      });

      test('"Artist Pro" for legacyArtistPro', () {
        const s = SubscriptionState(isPremium: true, legacyArtistPro: true);
        expect(s.displayPlanName, 'Artist Pro');
      });

      test('"Premium" when isPremium=true but planType unknown', () {
        const s = SubscriptionState(isPremium: true);
        expect(s.displayPlanName, 'Premium');
      });
    });

    group('featureSummary', () {
      test('unlimited upload summary for Pro user', () {
        const s = SubscriptionState(isPremium: true, planType: 'Pro');
        expect(s.featureSummary.contains('Unlimited uploads'), isTrue);
      });

      test('offline download summary for Go+ user', () {
        const s = SubscriptionState(isPremium: true, planType: 'Go+');
        expect(s.featureSummary.contains('Offline downloads'), isTrue);
      });

      test('loading summary when premium but plan unknown', () {
        const s = SubscriptionState(isPremium: true);
        expect(s.featureSummary.contains('loading'), isTrue);
      });

      test('"Free plan" summary for free user', () {
        const s = SubscriptionState(isPremium: false);
        expect(s.featureSummary, 'Free plan');
      });
    });
  });

  // ── OfflineDownloadedTrack ─────────────────────────────────────────────────

  group('OfflineDownloadedTrack', () {
    final baseDate = DateTime(2024, 1, 15, 10, 30, 0);

    OfflineDownloadedTrack makeTrack({
      String trackId = 'track-123',
      String downloadMode = 'file',
      bool fileAvailable = true,
      bool backendDownloadAllowed = true,
      bool isMockDownload = false,
    }) =>
        OfflineDownloadedTrack(
          trackId: trackId,
          title: 'Test Track',
          artistName: 'Test Artist',
          downloadedAt: baseDate,
          downloadMode: downloadMode,
          fileAvailable: fileAvailable,
          backendDownloadAllowed: backendDownloadAllowed,
          isMockDownload: isMockDownload,
        );

    group('constructor defaults', () {
      test('downloadMode defaults to "file"', () {
        expect(makeTrack().downloadMode, 'file');
      });

      test('fileAvailable defaults to true', () {
        expect(makeTrack().fileAvailable, isTrue);
      });

      test('backendDownloadAllowed defaults to true', () {
        expect(makeTrack().backendDownloadAllowed, isTrue);
      });

      test('isMockDownload defaults to false', () {
        expect(makeTrack().isMockDownload, isFalse);
      });
    });

    group('toJson / fromJson round-trip', () {
      test('round-trips required fields', () {
        final track = makeTrack();
        final json = track.toJson();
        final restored = OfflineDownloadedTrack.fromJson(json);
        expect(restored.trackId, track.trackId);
        expect(restored.title, track.title);
        expect(restored.artistName, track.artistName);
        expect(restored.downloadedAt, track.downloadedAt);
      });

      test('round-trips optional fields when present', () {
        final track = OfflineDownloadedTrack(
          trackId: 'tid',
          title: 'T',
          artistName: 'A',
          downloadedAt: baseDate,
          artworkUrl: 'https://art.jpg',
          audioUrl: 'https://audio.m3u8',
          localPath: '/storage/offline_tid.mp3',
          planType: 'Go+',
          genre: 'Electronic',
          duration: 240,
          downloadMode: 'file',
          fileAvailable: true,
          backendDownloadAllowed: true,
          isMockDownload: false,
        );
        final restored = OfflineDownloadedTrack.fromJson(track.toJson());
        expect(restored.artworkUrl, 'https://art.jpg');
        expect(restored.audioUrl, 'https://audio.m3u8');
        expect(restored.localPath, '/storage/offline_tid.mp3');
        expect(restored.planType, 'Go+');
        expect(restored.genre, 'Electronic');
        expect(restored.duration, 240);
      });

      test('round-trips downloadMode "file"', () {
        final track = makeTrack(downloadMode: 'file');
        final restored = OfflineDownloadedTrack.fromJson(track.toJson());
        expect(restored.downloadMode, 'file');
      });

      test('round-trips downloadMode "metadataOnly"', () {
        final track = makeTrack(downloadMode: 'metadataOnly', fileAvailable: false);
        final restored = OfflineDownloadedTrack.fromJson(track.toJson());
        expect(restored.downloadMode, 'metadataOnly');
        expect(restored.fileAvailable, isFalse);
      });

      test('round-trips isMockDownload=true', () {
        final track = makeTrack(isMockDownload: true);
        final restored = OfflineDownloadedTrack.fromJson(track.toJson());
        expect(restored.isMockDownload, isTrue);
      });

      test('round-trips backendDownloadAllowed=false', () {
        final track = makeTrack(backendDownloadAllowed: false);
        final restored = OfflineDownloadedTrack.fromJson(track.toJson());
        expect(restored.backendDownloadAllowed, isFalse);
      });

      test('downloadedAt survives toJson/fromJson without loss of precision', () {
        final track = makeTrack();
        final restored = OfflineDownloadedTrack.fromJson(track.toJson());
        // Compare to the second level to avoid sub-millisecond ISO string drift
        expect(
          restored.downloadedAt.toIso8601String().substring(0, 19),
          track.downloadedAt.toIso8601String().substring(0, 19),
        );
      });

      test('blockedReason survives round-trip', () {
        final track = OfflineDownloadedTrack(
          trackId: 'tid',
          title: 'T',
          artistName: 'A',
          downloadedAt: baseDate,
          downloadMode: 'metadataOnly',
          fileAvailable: false,
          backendDownloadAllowed: false,
          blockedReason: 'Artist has not enabled direct downloads',
        );
        final restored = OfflineDownloadedTrack.fromJson(track.toJson());
        expect(restored.blockedReason, 'Artist has not enabled direct downloads');
      });
    });

    group('business logic: download modes', () {
      test('file mode track has fileAvailable=true', () {
        final track = makeTrack(downloadMode: 'file', fileAvailable: true);
        expect(track.fileAvailable, isTrue);
        expect(track.downloadMode, 'file');
      });

      test('metadataOnly mode track has fileAvailable=false', () {
        final track = makeTrack(downloadMode: 'metadataOnly', fileAvailable: false, backendDownloadAllowed: false);
        expect(track.fileAvailable, isFalse);
        expect(track.backendDownloadAllowed, isFalse);
      });
    });
  });
}
