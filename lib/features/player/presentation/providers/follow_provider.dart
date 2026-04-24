import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/user_session.dart';

class FollowState {
  final bool isFollowing;
  final bool isLoading;
  final bool isChecking;

  const FollowState({
    this.isFollowing = false,
    this.isLoading = false,
    this.isChecking = true,
  });

  FollowState copyWith({bool? isFollowing, bool? isLoading, bool? isChecking}) =>
      FollowState(
        isFollowing: isFollowing ?? this.isFollowing,
        isLoading: isLoading ?? this.isLoading,
        isChecking: isChecking ?? this.isChecking,
      );
}

class FollowNotifier extends StateNotifier<FollowState> {
  FollowNotifier() : super(const FollowState(isChecking: true));

  Future<void> checkStatus(String artistId) async {
    if (mounted) state = state.copyWith(isChecking: true);
    try {
      final myUserId = await UserSession.getUserId();
      if (myUserId == null) return;
      final response = await dioClient.dio.get(
        '/network/$myUserId/following',
        queryParameters: {'limit': 1000},
      );
      final data = response.data['data'];
      if (data is List && mounted) {
        state = state.copyWith(
          isFollowing: data.any((u) => u['_id'] == artistId),
        );
      }
    } catch (_) {} finally {
      if (mounted) state = state.copyWith(isChecking: false);
    }
  }

  Future<void> toggle(String artistId) async {
    if (state.isChecking || state.isLoading) return;
    final wasFollowing = state.isFollowing;
    state = state.copyWith(isFollowing: !wasFollowing, isLoading: true);
    try {
      if (wasFollowing) {
        await dioClient.dio.delete('/network/$artistId/follow');
      } else {
        await dioClient.dio.post('/network/$artistId/follow');
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isFollowing: wasFollowing);
    } finally {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }
}

/// Keyed by artistId. Stays alive for the session so follow state is consistent
/// across FullPlayerPage and MiniPlayerWidget.
/// Automatically triggers [checkStatus] when first created for an artistId.
final followProvider = StateNotifierProvider
    .family<FollowNotifier, FollowState, String>((ref, artistId) {
  final notifier = FollowNotifier();
  Future.microtask(() => notifier.checkStatus(artistId));
  return notifier;
});
