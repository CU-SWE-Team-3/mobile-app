import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/engagement_remote_data_source.dart';
import '../../../../injection_container.dart';

// ── Params ────────────────────────────────────────────────────────────────────

class EngagementParams {
  final String trackId;
  final bool isLiked;
  final bool isReposted;
  final int likeCount;
  final int repostCount;

  const EngagementParams({
    required this.trackId,
    this.isLiked = false,
    this.isReposted = false,
    this.likeCount = 0,
    this.repostCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is EngagementParams && other.trackId == trackId;

  @override
  int get hashCode => trackId.hashCode;
}

// ── State ─────────────────────────────────────────────────────────────────────

class EngagementState {
  final bool isLiked;
  final bool isReposted;
  final int likeCount;
  final int repostCount;
  final bool isLoadingLike;
  final bool isLoadingRepost;

  const EngagementState({
    this.isLiked = false,
    this.isReposted = false,
    this.likeCount = 0,
    this.repostCount = 0,
    this.isLoadingLike = false,
    this.isLoadingRepost = false,
  });

  EngagementState copyWith({
    bool? isLiked,
    bool? isReposted,
    int? likeCount,
    int? repostCount,
    bool? isLoadingLike,
    bool? isLoadingRepost,
  }) =>
      EngagementState(
        isLiked: isLiked ?? this.isLiked,
        isReposted: isReposted ?? this.isReposted,
        likeCount: likeCount ?? this.likeCount,
        repostCount: repostCount ?? this.repostCount,
        isLoadingLike: isLoadingLike ?? this.isLoadingLike,
        isLoadingRepost: isLoadingRepost ?? this.isLoadingRepost,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class EngagementNotifier extends StateNotifier<EngagementState> {
  final EngagementRemoteDataSource _dataSource;
  final String trackId;

  EngagementNotifier(
    this._dataSource,
    this.trackId, {
    required bool initialIsLiked,
    required bool initialIsReposted,
    required int initialLikeCount,
    required int initialRepostCount,
  }) : super(EngagementState(
          isLiked: initialIsLiked,
          isReposted: initialIsReposted,
          likeCount: initialLikeCount,
          repostCount: initialRepostCount,
        ));

  /// Overwrite state with fresh values from an API response.
  /// Safe to call when the provider already exists with stale/default values.
  void seed(bool isLiked, bool isReposted, int likeCount, int repostCount) {
    state = state.copyWith(
      isLiked: isLiked,
      isReposted: isReposted,
      likeCount: likeCount,
      repostCount: repostCount,
    );
  }

  Future<void> toggleLike() async {
    if (state.isLoadingLike) return;
    final wasLiked = state.isLiked;
    final prevCount = state.likeCount;
    state = state.copyWith(
      isLiked: !wasLiked,
      likeCount: wasLiked ? prevCount - 1 : prevCount + 1,
      isLoadingLike: true,
    );
    try {
      if (wasLiked) {
        await _dataSource.unlikeTrack(trackId);
      } else {
        await _dataSource.likeTrack(trackId);
      }
      state = state.copyWith(isLoadingLike: false);
    } catch (_) {
      state = state.copyWith(
        isLiked: wasLiked,
        likeCount: prevCount,
        isLoadingLike: false,
      );
    }
  }

  Future<void> toggleRepost() async {
    if (state.isLoadingRepost) return;
    final wasReposted = state.isReposted;
    final prevCount = state.repostCount;
    state = state.copyWith(
      isReposted: !wasReposted,
      repostCount: wasReposted ? prevCount - 1 : prevCount + 1,
      isLoadingRepost: true,
    );
    try {
      if (wasReposted) {
        await _dataSource.unRepostTrack(trackId);
      } else {
        await _dataSource.repostTrack(trackId);
      }
      state = state.copyWith(isLoadingRepost: false);
    } catch (_) {
      state = state.copyWith(
        isReposted: wasReposted,
        repostCount: prevCount,
        isLoadingRepost: false,
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final engagementProvider =
    StateNotifierProvider.family<EngagementNotifier, EngagementState, EngagementParams>(
  (ref, params) => EngagementNotifier(
    sl<EngagementRemoteDataSource>(),
    params.trackId,
    initialIsLiked: params.isLiked,
    initialIsReposted: params.isReposted,
    initialLikeCount: params.likeCount,
    initialRepostCount: params.repostCount,
  ),
);
