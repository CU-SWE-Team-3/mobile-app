import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';

class LikeState {
  final bool isLiked;
  final bool isLiking;
  final String? error;

  const LikeState({
    this.isLiked = false,
    this.isLiking = false,
    this.error,
  });

  LikeState copyWith({bool? isLiked, bool? isLiking, String? error}) =>
      LikeState(
        isLiked: isLiked ?? this.isLiked,
        isLiking: isLiking ?? this.isLiking,
        error: error,
      );
}

class LikeNotifier extends StateNotifier<LikeState> {
  LikeNotifier() : super(const LikeState());

  Future<void> toggle(String trackId) async {
    if (state.isLiking) return;
    final wasLiked = state.isLiked;
    state = state.copyWith(isLiked: !wasLiked, isLiking: true, error: null);
    try {
      // Debug — remove after confirming token is present
      debugPrint('AUTH HEADER: ${dioClient.dio.options.headers['Authorization']}');
      if (wasLiked) {
        await dioClient.dio.delete('/tracks/$trackId/like');
      } else {
        await dioClient.dio.post('/tracks/$trackId/like');
      }
      state = state.copyWith(isLiking: false);
    } catch (e) {
      debugPrint('LIKE ERROR: $e');
      final msg = e.toString().contains('401')
          ? 'Please log in to like tracks'
          : 'Failed to update like';
      state = state.copyWith(isLiked: wasLiked, isLiking: false, error: msg);
    }
  }
}

/// Keyed by trackId. Auto-disposed when the track changes.
final trackLikeProvider = StateNotifierProvider.autoDispose
    .family<LikeNotifier, LikeState, String>(
  (ref, trackId) => LikeNotifier(),
);