import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/services/subscription_service.dart';

class SubscriptionState {
  final bool isPremium;
  final bool isLoading;
  final String? error;
  final String? expiresAt;
  final bool cancelAtPeriodEnd;
  final String? planType;
  final bool offlineListening;
  final bool legacyArtistPro;
  // true when planType came from a local checkout fallback (backend returned null)
  final bool isLocalPlanFallback;
  final bool hasResolved;

  const SubscriptionState({
    this.isPremium = false,
    this.isLoading = false,
    this.error,
    this.expiresAt,
    this.cancelAtPeriodEnd = false,
    this.planType,
    this.offlineListening = false,
    this.legacyArtistPro = false,
    this.isLocalPlanFallback = false,
    this.hasResolved = false,
  });

  SubscriptionState copyWith({
    bool? isPremium,
    bool? isLoading,
    String? error, // null clears
    String? expiresAt,
    bool clearExpiresAt = false,
    bool? cancelAtPeriodEnd,
    String? planType,
    bool? offlineListening,
    bool? legacyArtistPro,
    bool? isLocalPlanFallback,
    bool? hasResolved,
  }) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      planType: planType ?? this.planType,
      offlineListening: offlineListening ?? this.offlineListening,
      legacyArtistPro: legacyArtistPro ?? this.legacyArtistPro,
      isLocalPlanFallback: isLocalPlanFallback ?? this.isLocalPlanFallback,
      hasResolved: hasResolved ?? this.hasResolved,
    );
  }
}

/// Maps a normalised planType key to its UI display name.
String planDisplayName(String? planType) {
  if (planType == 'Pro') return 'Artist Pro';
  if (planType == 'Artist Pro') return 'Artist Pro';
  if (planType == 'Go+') return 'Go+';
  return 'Premium';
}

/// Normalise raw backend plan strings to canonical 'Pro' or 'Go+'.
/// Returns null for Free, empty, or unrecognised values.
String? normalizeSubscriptionPlan(Object? rawPlan) {
  if (rawPlan == null) return null;
  final value = rawPlan.toString().trim();
  if (value.isEmpty) return null;
  final lower = value.toLowerCase();
  if (lower == 'pro' || lower == 'artist pro' || lower == 'artistpro') {
    return 'Pro';
  }
  if (lower == 'go+' || lower == 'go plus' || lower == 'goplus') {
    return 'Go+';
  }
  if (lower == 'free') return null;
  return value;
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final DioClient _dioClient;
  final Ref _ref;

  SubscriptionNotifier(this._dioClient, this._ref)
      : super(const SubscriptionState()) {
    loadFromLocal().then((_) => refreshFromProfile());
  }

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final localPremium = prefs.getBool('isPremium') ?? false;
    final expiresAt = prefs.getString('subscriptionExpiresAt');
    final cancelAtPeriodEnd = prefs.getBool('cancelAtPeriodEnd') ?? false;
    final offlineListening =
        prefs.getBool('subscriptionOfflineListening') ?? false;

    // Prefer the live auth state when available.
    final authUser = _ref.read(authProvider).user;
    final effectivePremium = authUser?.isPremium ?? localPremium;
    if (effectivePremium != localPremium) {
      await prefs.setBool('isPremium', effectivePremium);
    }

    // Resolve plan: backend-confirmed key first, then checkout fallback.
    final confirmedPlan = prefs.getString('subscriptionPlanType');
    final pendingPlan = prefs.getString('pendingSelectedPlan');
    String? resolvedPlan;
    bool isLocalFallback = false;
    if (confirmedPlan != null) {
      resolvedPlan = confirmedPlan;
    } else if (effectivePremium && pendingPlan != null) {
      resolvedPlan = pendingPlan;
      isLocalFallback = true;
    }

    final role = prefs.getString('role')?.toLowerCase();
    final legacyArtistPro =
        effectivePremium && resolvedPlan == null && role == 'artist';

    debugPrint(
      '[Subscription] loadFromLocal — isPremium=$effectivePremium, '
      'resolvedPlan=${resolvedPlan ?? "null"}, '
      'source=${isLocalFallback ? "localFallback" : confirmedPlan != null ? "backend" : "unknown"}',
    );

    state = SubscriptionState(
      isPremium: effectivePremium,
      expiresAt: expiresAt,
      planType: resolvedPlan,
      offlineListening: offlineListening,
      legacyArtistPro: legacyArtistPro,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      isLocalPlanFallback: isLocalFallback,
      hasResolved: true,
    );
  }

  /// Fetches live premium status from the profile API.
  /// Requires 'permalink' saved to SharedPreferences at login.
  Future<void> refreshFromProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final permalink = prefs.getString('permalink') ?? '';
      if (permalink.isEmpty) {
        state = state.copyWith(isLoading: false, hasResolved: true);
        return;
      }
      final response = await _dioClient.dio.get('/profile/$permalink');
      final user = response.data['data']['user'] as Map<String, dynamic>?;
      final isPremium = user?['isPremium'] as bool? ?? false;

      final subscription = _asStringMap(user?['subscription']);
      final remotePlanType = _readPlanType(
        user: user,
        subscription: subscription,
      );
      final offlineListening = _readBoolEntitlement(
        user: user,
        subscription: subscription,
        keys: const ['offlineListening', 'canDownload', 'downloadsEnabled'],
      );
      final role = ((user?['role'] as String?) ??
              prefs.getString('role') ??
              _ref.read(authProvider).user?.role ??
              '')
          .toLowerCase();
      if (role.isNotEmpty) await prefs.setString('role', role);
      await prefs.setBool('isPremium', isPremium);
      await prefs.setBool('subscriptionOfflineListening', offlineListening);

      // Priority: backend value -> pendingSelectedPlan fallback -> unknown.
      // Never clear pendingSelectedPlan while backend still returns null,
      // because Stripe webhook may not have fired yet.
      String? resolvedPlanType;
      bool isLocalFallback = false;

      if (remotePlanType != null) {
        // Backend confirmed the plan - persist and clear the checkout fallback.
        resolvedPlanType = remotePlanType;
        await prefs.setString('subscriptionPlanType', remotePlanType);
        await prefs.remove('pendingSelectedPlan');
      } else if (isPremium) {
        // Backend doesn't expose planType yet (webhook lag or backend limitation).
        // Try pendingSelectedPlan first, then subscriptionPlanType.
        final pending = prefs.getString('pendingSelectedPlan');
        final loginSaved = prefs.getString('subscriptionPlanType');
        final fallback = pending ?? loginSaved;
        if (fallback != null) {
          resolvedPlanType = fallback;
          isLocalFallback = true;
        }
      } else {
        await prefs.remove('subscriptionPlanType');
        await prefs.remove('pendingSelectedPlan');
      }

      final legacyArtistPro =
          isPremium && resolvedPlanType == null && role == 'artist';

      final planSource = remotePlanType != null
          ? 'backend'
          : isLocalFallback
              ? 'localFallback'
              : 'unknown';

      debugPrint(
        '[Subscription] refreshFromProfile — isPremium: $isPremium, '
        'planType: ${resolvedPlanType ?? "null"}, source: $planSource, '
        'role: $role, legacyArtistPro: $legacyArtistPro, '
        'rawPlanFields: subscription.planType=${subscription?['planType']}, '
        'subscription.subscriptionPlan=${subscription?['subscriptionPlan']}, '
        'user.planType=${user?['planType']}, '
        'user.subscriptionPlan=${user?['subscriptionPlan']}, '
        'offlineListening: $offlineListening',
      );

      state = SubscriptionState(
        isPremium: isPremium,
        isLoading: false,
        planType: resolvedPlanType,
        expiresAt: state.expiresAt,
        cancelAtPeriodEnd: state.cancelAtPeriodEnd,
        offlineListening: offlineListening,
        legacyArtistPro: legacyArtistPro,
        isLocalPlanFallback: isLocalFallback,
        hasResolved: true,
      );

      debugPrint(
        '[Entitlements] canUploadUnlimited=${state.canUploadUnlimited}, '
        'canDownload=${state.canDownload}, '
        'offlineListening=$offlineListening',
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, hasResolved: true);
    }
  }

  Future<void> checkout(String planType) async {
    if (state.isPremium && !state.cancelAtPeriodEnd) return;
    final hasAuth = (_dioClient.dio.options.headers['Authorization'] as String?)
            ?.isNotEmpty ??
        false;
    debugPrint('[Subscription] checkout — token exists: $hasAuth');
    if (!hasAuth) {
      state = state.copyWith(error: 'Please log in again.');
      return;
    }
    debugPrint(
      '[Subscription] checkout — planType: $planType, '
      'endpoint: POST /subscriptions/checkout',
    );

    final prefs = await SharedPreferences.getInstance();
    // Save as checkout fallback — kept until backend confirms the plan.
    await prefs.setString('pendingSelectedPlan', planType);
    // Also write subscriptionPlanType for immediate in-session display.
    await prefs.setString('subscriptionPlanType', planType);
    state = state.copyWith(
      isLoading: true,
      planType: planType,
      isLocalPlanFallback: false,
    );

    try {
      final service = SubscriptionService(_dioClient);
      final url = await service.checkout(planType);
      if (url.isEmpty) {
        state = state.copyWith(
            isLoading: false, error: 'Invalid checkout URL received.');
        return;
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await prefs.setBool('pendingCheckout', true);
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Could not open checkout URL.');
        return;
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) {
        state = state.copyWith(isLoading: false);
        await refreshFromProfile();
        if (state.isPremium) return;
        final msg = _bodyMessage(e.response?.data);
        state = state.copyWith(
          isLoading: false,
          error: msg.isNotEmpty ? msg : 'Checkout failed. Please try again.',
        );
        return;
      }
      state = state.copyWith(isLoading: false, error: _mapError(e));
    }
  }

  Future<void> cancelSubscription() async {
    if (!state.isPremium) {
      state = state.copyWith(error: 'No active subscription to cancel.');
      return;
    }
    final hasAuth = (_dioClient.dio.options.headers['Authorization'] as String?)
            ?.isNotEmpty ??
        false;
    debugPrint(
      '[Subscription] cancel â€” token exists: $hasAuth, '
      'endpoint: DELETE /subscriptions/cancel',
    );
    if (!hasAuth) {
      state = state.copyWith(error: 'Please log in again.');
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final service = SubscriptionService(_dioClient);
      final expiresAt = await service.cancel();

      final prefs = await SharedPreferences.getInstance();
      if (expiresAt != null) {
        await prefs.setString('subscriptionExpiresAt', expiresAt);
      }
      await prefs.setBool('cancelAtPeriodEnd', true);

      final uiMsg = expiresAt != null
          ? 'Your subscription will remain active until $expiresAt'
          : 'Subscription cancelled. Access continues until your billing period ends.';
      debugPrint('[Cancel] [6] final UI message: $uiMsg');

      state = state.copyWith(
        isLoading: false,
        expiresAt: expiresAt,
        cancelAtPeriodEnd: true,
      );
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      final body = e is DioException ? e.response?.data : null;
      String errMsg = _mapError(e);
      if (errMsg.toLowerCase().contains('route') &&
          errMsg.toLowerCase().contains('not found')) {
        errMsg = 'Cancellation is not available from backend yet.';
      }
      debugPrint(
        '[Cancel] FAILED â€” status: $status, body: $body, '
        'errorType: ${e.runtimeType}\n'
        '[Cancel] [6] final UI message: $errMsg',
      );
      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  /// DEV ONLY â€” resets all local premium state for re-testing the subscribe flow.
  Future<void> devReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', false);
    await prefs.remove('subscriptionPlanType');
    await prefs.remove('pendingSelectedPlan');
    await prefs.remove('subscriptionOfflineListening');
    await prefs.remove('subscriptionExpiresAt');
    await prefs.setBool('cancelAtPeriodEnd', false);
    await prefs.setBool('pendingCheckout', false);
    debugPrint('[Subscription] devReset â€” local premium state cleared');
    state = const SubscriptionState(hasResolved: true);
  }

  String _mapError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 401) return 'Session expired. Please log in again.';
      if (status == 400) {
        final msg = _bodyMessage(e.response?.data);
        return msg.isNotEmpty ? msg : 'Checkout failed. Please try again.';
      }
      if (status == 403) return 'This feature requires a premium plan.';
      if (status == 404)
        return 'Cancellation is not available from backend yet.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Network error. Please try again.';
      }
      final msg = _bodyMessage(e.response?.data);
      if (msg.isNotEmpty) return msg;
    }
    return 'Something went wrong. Please try again.';
  }

  String _bodyMessage(dynamic data) {
    try {
      if (data is Map) {
        return (data['message'] as String?) ??
            (data['error'] as String?) ??
            (data['msg'] as String?) ??
            '';
      }
      if (data is String && data.isNotEmpty) {
        for (final key in ['message', 'error', 'msg']) {
          final start = data.indexOf('"$key"');
          if (start != -1) {
            final colon = data.indexOf(':', start);
            if (colon != -1) {
              final q1 = data.indexOf('"', colon + 1);
              if (q1 != -1) {
                final q2 = data.indexOf('"', q1 + 1);
                if (q2 != -1) return data.substring(q1 + 1, q2);
              }
            }
          }
        }
      }
    } catch (_) {}
    return '';
  }

  bool _readBoolEntitlement({
    required Map<String, dynamic>? user,
    required Map<String, dynamic>? subscription,
    required List<String> keys,
  }) {
    final sources = <Map<String, dynamic>?>[
      subscription,
      _asStringMap(subscription?['entitlements']),
      user,
      _asStringMap(user?['entitlements']),
    ];
    for (final source in sources) {
      if (source == null) continue;
      for (final key in keys) {
        final value = source[key];
        if (value is bool) return value;
      }
    }
    return false;
  }

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _readPlanType({
    required Map<String, dynamic>? user,
    required Map<String, dynamic>? subscription,
  }) {
    final rawSubscriptionPlan = user?['subscription'] is Map
        ? null
        : normalizeSubscriptionPlan(user?['subscription']);
    if (rawSubscriptionPlan != null) return rawSubscriptionPlan;

    final sources = <Map<String, dynamic>?>[
      subscription,
      _asStringMap(subscription?['plan']),
      user,
      _asStringMap(user?['subscription']),
    ];
    const keys = [
      'planType',
      'subscriptionPlan',
      'subscription_plan',
      'plan',
    ];
    for (final source in sources) {
      if (source == null) continue;
      for (final key in keys) {
        final normalized = normalizeSubscriptionPlan(source[key]);
        if (normalized != null) return normalized;
      }
    }
    return null;
  }
}

extension SubscriptionEntitlements on SubscriptionState {
  /// True only for Pro/Artist Pro â€” the plan with unlimited uploads.
  /// Go+ and Free are capped at 3 uploads (per API v1.10).
  bool get canUploadUnlimited =>
      isPremium &&
      (planType == 'Pro' || planType == 'Artist Pro' || legacyArtistPro);

  /// True only for Go+ â€” the plan with offline downloads (per API v1.10).
  /// A backend offlineListening entitlement is also accepted when present.
  bool get canDownload => planType == 'Go+' || offlineListening;

  /// True when isPremium is known and planType has been resolved.
  bool get isPlanKnown => !isPremium || planType != null;

  String get displayPlanName {
    if (!isPremium) return 'Free';
    if (planType == 'Pro') return 'Artist Pro';
    if (planType == 'Go+') return 'Go+';
    if (legacyArtistPro) return 'Artist Pro';
    return 'Premium'; // subscribed but plan unknown
  }

  String get featureSummary {
    if (canUploadUnlimited) return 'Unlimited uploads · Ad-free listening';
    if (canDownload) return 'Offline downloads · Ad-free listening';
    if (isPremium) return 'Premium active · plan details loading…';
    return 'Free plan';
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return SubscriptionNotifier(dioClient, ref);
});

// Lightweight provider for the current user's playlist count (used by paywall).
final myPlaylistCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId') ?? '';
  if (userId.isEmpty) return 0;
  final dio = ref.watch(dioClientProvider).dio;
  final response =
      await dio.get('/playlists', queryParameters: {'creator': userId});
  final results = response.data['results'];
  if (results is int) return results;
  final data = response.data['data'];
  if (data is Map && data['playlists'] is List) {
    return (data['playlists'] as List).length;
  }
  return 0;
});
