import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../data/sources/engagement_remote_data_source.dart';
import '../../../../injection_container.dart';
import '../../../playlist/domain/entities/playlist.dart';

// ── Params ────────────────────────────────────────────────────────────────────

class EngagementParams {
  final String trackId;
  final String targetModel;
  final bool isLiked;
  final bool isReposted;
  final int likeCount;
  final int repostCount;

  const EngagementParams({
    required this.trackId,
    this.targetModel = 'Track',
    this.isLiked = false,
    this.isReposted = false,
    this.likeCount = 0,
    this.repostCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is EngagementParams &&
      other.trackId == trackId &&
      other.targetModel == targetModel;

  @override
  int get hashCode => Object.hash(trackId, targetModel);
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
  final Ref _ref;
  final String trackId;
  final String targetModel;

  /// True only after the user has actively toggled like or repost.
  /// seed() is a no-op once this is set so live toggle state is never
  /// overwritten by stale data from any API surface.
  bool _userToggled = false;

  EngagementNotifier(
    this._ref,
    this._dataSource,
    this.trackId, {
    this.targetModel = 'Track',
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

  void _setLikeHidden(bool hidden) {
    if (targetModel != 'Track') return;
    final current = _ref.read(hiddenLikedTrackIdsProvider);
    final next = <String>{...current};
    if (hidden) {
      next.add(trackId);
    } else {
      next.remove(trackId);
    }
    _ref.read(hiddenLikedTrackIdsProvider.notifier).state = next;
  }

  /// Overwrite state with authoritative values from an API response.
  /// Named params so callers only supply the fields they actually know —
  /// omitted fields preserve the current state.
  /// No-op once the user has toggled, so live toggle state is never clobbered.
  void seed(
      {bool? isLiked, bool? isReposted, int? likeCount, int? repostCount}) {
    if (_userToggled) return;
    state = state.copyWith(
      isLiked: isLiked,
      isReposted: isReposted,
      likeCount: likeCount,
      repostCount: repostCount,
    );
  }

  Future<bool> toggleLike() async {
    if (state.isLoadingLike) return false;
    _userToggled = true;
    final wasLiked = state.isLiked;
    final prevCount = state.likeCount;
    state = state.copyWith(
      isLiked: !wasLiked,
      likeCount: wasLiked ? prevCount - 1 : prevCount + 1,
      isLoadingLike: true,
    );
    _setLikeHidden(wasLiked);
    try {
      if (wasLiked) {
        await _unlike();
      } else {
        await _like();
      }
      _ref.read(likesRefreshTickProvider.notifier).state++;
      if (targetModel == 'Playlist') {
        _ref.read(likedPlaylistsRefreshTickProvider.notifier).state++;
      }
      state = state.copyWith(isLoadingLike: false);
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final rawMessage = e.response?.data is Map
          ? (e.response?.data as Map)['message']?.toString().toLowerCase()
          : e.response?.data?.toString().toLowerCase();
      final alreadyInDesiredState = (!wasLiked &&
              (status == 400 || status == 409) &&
              (rawMessage?.contains('already') ?? false)) ||
          (wasLiked &&
              (status == 400 || status == 404) &&
              ((rawMessage?.contains('not') ?? false) ||
                  (rawMessage?.contains('found') ?? false)));
      if (alreadyInDesiredState) {
        _ref.read(likesRefreshTickProvider.notifier).state++;
        if (targetModel == 'Playlist') {
          _ref.read(likedPlaylistsRefreshTickProvider.notifier).state++;
        }
        state = state.copyWith(isLoadingLike: false);
        return true;
      }
      state = state.copyWith(
        isLiked: wasLiked,
        likeCount: prevCount,
        isLoadingLike: false,
      );
      _setLikeHidden(!wasLiked);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLiked: wasLiked,
        likeCount: prevCount,
        isLoadingLike: false,
      );
      _setLikeHidden(!wasLiked);
      return false;
    }
  }

  Future<bool> removeLike() async {
    if (state.isLoadingLike) return !state.isLiked;
    if (!state.isLiked) {
      _ref.read(likesRefreshTickProvider.notifier).state++;
      return true;
    }

    _userToggled = true;
    final prevCount = state.likeCount;
    state = state.copyWith(
      isLiked: false,
      likeCount: prevCount > 0 ? prevCount - 1 : 0,
      isLoadingLike: true,
    );
    _setLikeHidden(true);

    try {
      await _unlike();
      _ref.read(likesRefreshTickProvider.notifier).state++;
      if (targetModel == 'Playlist') {
        _ref.read(likedPlaylistsRefreshTickProvider.notifier).state++;
      }
      state = state.copyWith(isLoadingLike: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLiked: true,
        likeCount: prevCount,
        isLoadingLike: false,
      );
      _setLikeHidden(false);
      return false;
    }
  }

  Future<void> toggleRepost() async {
    if (state.isLoadingRepost) return;
    _userToggled = true;
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
    } catch (e) {
      final noResponse = e is DioException && e.response == null;
      if (noResponse) {
        state = state.copyWith(
          isReposted: wasReposted,
          repostCount: prevCount,
          isLoadingRepost: false,
        );
      } else {
        state = state.copyWith(isLoadingRepost: false);
      }
    }
  }

  Future<void> _like() {
    if (targetModel == 'Track') return _dataSource.likeTrack(trackId);
    return _dataSource.likeTrack(trackId, targetModel: targetModel);
  }

  Future<void> _unlike() {
    if (targetModel == 'Track') return _dataSource.unlikeTrack(trackId);
    return _dataSource.unlikeTrack(trackId, targetModel: targetModel);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final engagementProvider = StateNotifierProvider.family<EngagementNotifier,
    EngagementState, EngagementParams>(
  (ref, params) {
    ref.watch(sessionUserIdProvider);
    return EngagementNotifier(
      ref,
      sl<EngagementRemoteDataSource>(),
      params.trackId,
      targetModel: params.targetModel,
      initialIsLiked: params.isLiked,
      initialIsReposted: params.isReposted,
      initialLikeCount: params.likeCount,
      initialRepostCount: params.repostCount,
    );
  },
);

final likesRefreshTickProvider = StateProvider<int>((ref) {
  ref.watch(sessionUserIdProvider);
  return 0;
});

final hiddenLikedTrackIdsProvider = StateProvider<Set<String>>((ref) {
  ref.watch(sessionUserIdProvider);
  return <String>{};
});

final likedTrackOverridesProvider =
    StateProvider<Map<String, TrackSummary>>((ref) {
  ref.watch(sessionUserIdProvider);
  return <String, TrackSummary>{};
});

final likedTrackOrderProvider = StateProvider<List<String>>((ref) {
  ref.watch(sessionUserIdProvider);
  return <String>[];
});

final likedPlaylistsRefreshTickProvider = StateProvider<int>((ref) {
  ref.watch(sessionUserIdProvider);
  return 0;
});

final hiddenLikedPlaylistIdsProvider = StateProvider<Set<String>>((ref) {
  ref.watch(sessionUserIdProvider);
  return <String>{};
});

final likedPlaylistOverridesProvider =
    StateProvider<Map<String, Playlist>>((ref) {
  ref.watch(sessionUserIdProvider);
  return <String, Playlist>{};
});

final backendUserLikesProvider =
    FutureProvider.autoDispose<List<TrackSummary>>((ref) async {
  ref.watch(likesRefreshTickProvider);
  final userId = ref.watch(sessionUserIdProvider);
  if (userId.isEmpty) return [];
  return sl<EngagementRemoteDataSource>().getUserLikes(userId);
});

final mergedUserLikesProvider = Provider<AsyncValue<List<TrackSummary>>>((ref) {
  final hiddenIds = ref.watch(hiddenLikedTrackIdsProvider);
  final overrides = ref.watch(likedTrackOverridesProvider);
  final backendAsync = ref.watch(backendUserLikesProvider);

  return backendAsync.whenData((backendLikes) {
    final merged = <TrackSummary>[
      ...overrides.values,
      ...backendLikes.where((track) => !overrides.containsKey(track.id)),
    ];
    return merged.where((track) => !hiddenIds.contains(track.id)).toList();
  });
});

final backendLikedPlaylistsProvider =
    FutureProvider.autoDispose<List<Playlist>>((ref) async {
  ref.watch(likedPlaylistsRefreshTickProvider);
  final userId = ref.watch(sessionUserIdProvider);
  if (userId.isEmpty) return [];
  return sl<EngagementRemoteDataSource>().getUserLikedPlaylists(userId);
});

final likedPlaylistsProvider = Provider<AsyncValue<List<Playlist>>>((ref) {
  final hiddenIds = ref.watch(hiddenLikedPlaylistIdsProvider);
  final overrides = ref.watch(likedPlaylistOverridesProvider);
  final backendAsync = ref.watch(backendLikedPlaylistsProvider);

  return backendAsync.whenData((backendLikes) {
    final merged = <Playlist>[
      ...overrides.values,
      ...backendLikes.where((playlist) => !overrides.containsKey(playlist.id)),
    ];
    return merged
        .where((playlist) => !hiddenIds.contains(playlist.id))
        .toList();
  });
});
