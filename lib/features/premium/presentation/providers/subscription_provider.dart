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

  const SubscriptionState({
    this.isPremium = false,
    this.isLoading = false,
    this.error,
    this.expiresAt,
    this.cancelAtPeriodEnd = false,
    this.planType,
  });

  SubscriptionState copyWith({
    bool? isPremium,
    bool? isLoading,
    String? error, // null clears
    String? expiresAt,
    bool? cancelAtPeriodEnd,
    String? planType,
    bool clearExpiresAt = false,
    bool clearPlanType = false,
  }) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      planType: clearPlanType ? null : (planType ?? this.planType),
    );
  }
}

/// Maps the raw backend planType ("Pro", "Go+") to a display name.
String planDisplayName(String? planType) {
  if (planType == 'Pro') return 'Artist Pro';
  if (planType == 'Go+') return 'Go+';
  return 'Premium';
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final DioClient _dioClient;
  final Ref _ref;

  SubscriptionNotifier(this._dioClient, this._ref)
      : super(const SubscriptionState()) {
    // Load cached state first, then immediately fetch live state from backend.
    // This ensures isPremium and planType are always up-to-date even in cold
    // sessions where the user never triggered an app-resume cycle.
    loadFromLocal().then((_) => refreshFromProfile());
  }

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final localPremium = prefs.getBool('isPremium') ?? false;
    final expiresAt = prefs.getString('subscriptionExpiresAt');
    final planType = prefs.getString('subscriptionPlanType');
    final cancelAtPeriodEnd = prefs.getBool('cancelAtPeriodEnd') ?? false;

    // Prefer the live auth state when available
    final authUser = _ref.read(authProvider).user;
    final effectivePremium = authUser?.isPremium ?? localPremium;
    if (effectivePremium != localPremium) {
      await prefs.setBool('isPremium', effectivePremium);
    }

    state = SubscriptionState(
      isPremium: effectivePremium,
      expiresAt: expiresAt,
      planType: planType,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
    );
  }

  // Fetches live premium status from the profile API.
  // Requires 'permalink' to have been saved to SharedPreferences at login.
  Future<void> refreshFromProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final permalink = prefs.getString('permalink') ?? '';
      if (permalink.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final response = await _dioClient.dio.get('/profile/$permalink');
      final user = response.data['data']['user'] as Map<String, dynamic>?;
      final isPremium = user?['isPremium'] as bool? ?? false;

      // Try to read planType from various possible backend response structures.
      // The API spec names this field subscriptionPlan on the user object.
      final subscription = user?['subscription'] as Map<String, dynamic>?;
      final remotePlanType = subscription?['planType'] as String? ??
          subscription?['subscriptionPlan'] as String? ??
          user?['planType'] as String? ??
          user?['subscriptionPlan'] as String?;
      final remoteExpiresAt = subscription?['expiresAt']?.toString() ??
          subscription?['subscriptionExpiresAt']?.toString() ??
          user?['expiresAt']?.toString() ??
          user?['subscriptionExpiresAt']?.toString();
      final remoteCancelAtPeriodEnd =
          subscription?['cancelAtPeriodEnd'] as bool? ??
              user?['cancelAtPeriodEnd'] as bool? ??
              false;

      await prefs.setBool('isPremium', isPremium);
      if (remotePlanType != null) {
        await prefs.setString('subscriptionPlanType', remotePlanType);
      } else {
        await prefs.remove('subscriptionPlanType');
      }
      if (remoteExpiresAt != null) {
        await prefs.setString('subscriptionExpiresAt', remoteExpiresAt);
      } else {
        await prefs.remove('subscriptionExpiresAt');
      }
      await prefs.setBool('cancelAtPeriodEnd', remoteCancelAtPeriodEnd);

      debugPrint(
        '[Subscription] refreshFromProfile — isPremium: $isPremium, '
        'planType: $remotePlanType, expiresAt: $remoteExpiresAt, '
        'cancelAtPeriodEnd: $remoteCancelAtPeriodEnd',
      );

      state = state.copyWith(
        isPremium: isPremium,
        isLoading: false,
        planType: remotePlanType,
        clearPlanType: remotePlanType == null,
        expiresAt: remoteExpiresAt,
        clearExpiresAt: remoteExpiresAt == null,
        cancelAtPeriodEnd: remoteCancelAtPeriodEnd,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> checkout(String planType) async {
    // Already subscribed and not canceling — navigate to management UI.
    if (state.isPremium && !state.cancelAtPeriodEnd) {
      return;
    }
    final hasAuth =
        (_dioClient.dio.options.headers['Authorization'] as String?)
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
    // Store plan type now so success page can display it even before API refresh
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscriptionPlanType', planType);
    state = state.copyWith(isLoading: true, planType: planType);
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
        // Mark that a checkout was started so app-resume knows to show
        // PaymentSuccessPage only when returning from Stripe, not from any
        // other background event (file picker, login, etc.).
        await prefs.setBool('pendingCheckout', true);
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Could not open checkout URL.');
        return;
      }
      state = state.copyWith(isLoading: false);
      // Profile refresh is handled on app resume (WidgetsBindingObserver in main).
    } catch (e) {
      // On any 400, refresh profile first — the user may already be subscribed
      // (backend may return 400 for already-subscribed state with various messages).
      if (e is DioException && e.response?.statusCode == 400) {
        state = state.copyWith(isLoading: false);
        await refreshFromProfile();
        if (state.isPremium) {
          // Confirmed: user is already subscribed — treat as success.
          return;
        }
        // Not subscribed — show the backend message.
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
    final hasAuth =
        (_dioClient.dio.options.headers['Authorization'] as String?)
                ?.isNotEmpty ??
            false;
    debugPrint(
      '[Subscription] cancel — token exists: $hasAuth, '
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
        '[Cancel] FAILED — status: $status, body: $body, '
        'errorType: ${e.runtimeType}\n'
        '[Cancel] [6] final UI message: $errMsg',
      );

      state = state.copyWith(isLoading: false, error: errMsg);
    }
  }

  /// DEV ONLY — resets all local premium state for re-testing the subscribe flow.
  Future<void> devReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', false);
    await prefs.remove('subscriptionPlanType');
    await prefs.remove('subscriptionExpiresAt');
    await prefs.setBool('cancelAtPeriodEnd', false);
    await prefs.setBool('pendingCheckout', false);
    debugPrint('[Subscription] devReset — local premium state cleared');
    state = const SubscriptionState();
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
      if (status == 404) return 'Cancellation is not available from backend yet.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Network error. Please try again.';
      }
      // Surface backend message for any other status before falling back.
      final msg = _bodyMessage(e.response?.data);
      if (msg.isNotEmpty) return msg;
    }
    return 'Something went wrong. Please try again.';
  }

  /// Extracts a human-readable message from a Dio response body.
  /// Checks 'message', 'error', 'msg' fields in order.
  String _bodyMessage(dynamic data) {
    try {
      if (data is Map) {
        return (data['message'] as String?) ??
            (data['error'] as String?) ??
            (data['msg'] as String?) ??
            '';
      }
      if (data is String && data.isNotEmpty) {
        // Check 'message' key first, then 'error'
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
