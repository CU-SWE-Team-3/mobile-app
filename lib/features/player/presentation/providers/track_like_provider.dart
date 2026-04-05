import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';

class LikeState {
  final bool isLiked;
  final bool isLiking;

  const LikeState({this.isLiked = false, this.isLiking = false});

  LikeState copyWith({bool? isLiked, bool? isLiking}) => LikeState(
        isLiked: isLiked ?? this.isLiked,
        isLiking: isLiking ?? this.isLiking,
      );
}

class LikeNotifier extends StateNotifier<LikeState> {
  LikeNotifier() : super(const LikeState());

  Future<void> toggle(String trackId) async {
    if (state.isLiking) return;
    final wasLiked = state.isLiked;
    // Optimistic update
    state = state.copyWith(isLiked: !wasLiked, isLiking: true);
    try {
      if (wasLiked) {
        await dioClient.dio.delete('/tracks/$trackId/like');
      } else {
        await dioClient.dio.post('/tracks/$trackId/like');
      }
      state = state.copyWith(isLiking: false);
    } catch (_) {
      // Revert on failure
      state = state.copyWith(isLiked: wasLiked, isLiking: false);
    }
  }
}

/// Keyed by trackId. Auto-disposed when the track changes so state resets
/// cleanly for each new track.
final trackLikeProvider = StateNotifierProvider.autoDispose
    .family<LikeNotifier, LikeState, String>(
  (ref, trackId) => LikeNotifier(),
);
