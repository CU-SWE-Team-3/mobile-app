import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/user_session.dart';

class FollowState {
  final bool isFollowing;
  final bool isLoading;

  const FollowState({
    this.isFollowing = false,
    this.isLoading = false,
  });

  FollowState copyWith({bool? isFollowing, bool? isLoading}) => FollowState(
        isFollowing: isFollowing ?? this.isFollowing,
        isLoading: isLoading ?? this.isLoading,
      );
}

class FollowNotifier extends StateNotifier<FollowState> {
  FollowNotifier() : super(const FollowState());

  Future<void> checkStatus(String artistId) async {
    try {
      final myUserId = await UserSession.getUserId();
      if (myUserId == null) return;
      final response = await dioClient.dio.get(
        '/network/$myUserId/following',
        queryParameters: {'limit': 200},
      );
      final data = response.data['data'];
      if (data is List && mounted) {
        state = state.copyWith(
          isFollowing: data.any((u) => u['_id'] == artistId),
        );
      }
    } catch (_) {}
  }

  Future<void> toggle(String artistId) async {
    if (state.isLoading) return;
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

/// Keyed by artistId. Auto-disposes when no widget is watching.
/// Automatically triggers [checkStatus] when first created for an artistId.
final followProvider = StateNotifierProvider.autoDispose
    .family<FollowNotifier, FollowState, String>((ref, artistId) {
  final notifier = FollowNotifier();
  Future.microtask(() => notifier.checkStatus(artistId));
  return notifier;
});
