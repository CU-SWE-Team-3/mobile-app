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
  }) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      expiresAt: expiresAt ?? this.expiresAt,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      planType: planType ?? this.planType,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final DioClient _dioClient;
  final Ref _ref;

  SubscriptionNotifier(this._dioClient, this._ref)
      : super(const SubscriptionState()) {
    loadFromLocal();
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
      await prefs.setBool('isPremium', isPremium);
      state = state.copyWith(isPremium: isPremium, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> checkout(String planType) async {
    if (state.isPremium) {
      state = state.copyWith(error: 'You are already subscribed.');
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final service = SubscriptionService(_dioClient);
      final url = await service.checkout(planType);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        state = state.copyWith(isLoading: false, error: 'Could not open checkout URL.');
        return;
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> cancelSubscription() async {
    if (!state.isPremium) {
      state = state.copyWith(error: 'No active subscription to cancel.');
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
      state = state.copyWith(
        isLoading: false,
        expiresAt: expiresAt,
        cancelAtPeriodEnd: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
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
  final response = await dio.get('/playlists', queryParameters: {'creator': userId});
  final results = response.data['results'];
  if (results is int) return results;
  final data = response.data['data'];
  if (data is Map && data['playlists'] is List) {
    return (data['playlists'] as List).length;
  }
  return 0;
});
