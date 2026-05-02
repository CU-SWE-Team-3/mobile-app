import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../injection_container.dart';
import '../../../engagement/data/sources/engagement_remote_data_source.dart';
import '../../data/datasources/station_remote_data_source.dart';

export '../../data/datasources/station_remote_data_source.dart'
    show LikedStation;

// ── Station metadata cache (session-scoped) ───────────────────────────────────
// Keyed by stationId ("track_{trackId}"). Written when StationPage opens so
// that Library → StationPage navigation can recover artworkUrl / artistName
// even when GET /stations/liked doesn't return those fields.

class StationMeta {
  final String title;
  final String? artistName;
  final String? artworkUrl;

  const StationMeta({
    required this.title,
    this.artistName,
    this.artworkUrl,
  });
}

final stationMetaCacheProvider =
    StateProvider<Map<String, StationMeta>>((ref) {
  ref.watch(sessionUserIdProvider);
  return {};
});

// ── Refresh tick ───────────────────────────────────────────────────────────────

final likedStationsRefreshTickProvider = StateProvider<int>((ref) {
  ref.watch(sessionUserIdProvider);
  return 0;
});

// ── Related tracks for a station (keyed by seed trackId) ──────────────────────

final stationTracksProvider =
    FutureProvider.family<List<TrackSummary>, String>((ref, trackId) {
  return sl<StationRemoteDataSource>().getRelatedTracks(trackId);
});

// ── Per-station like state ────────────────────────────────────────────────────

class StationLikeState {
  final bool isLiked;
  final bool isLoading;

  const StationLikeState({this.isLiked = false, this.isLoading = false});

  StationLikeState copyWith({bool? isLiked, bool? isLoading}) =>
      StationLikeState(
        isLiked: isLiked ?? this.isLiked,
        isLoading: isLoading ?? this.isLoading,
      );
}

class StationLikeNotifier extends StateNotifier<StationLikeState> {
  final StationRemoteDataSource _ds;
  final Ref _ref;
  final String stationId;

  StationLikeNotifier(this._ref, this._ds, this.stationId)
      : super(const StationLikeState(isLoading: true)) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final liked = await _ds.isStationLiked(stationId);
      state = StationLikeState(isLiked: liked);
    } catch (_) {
      state = const StationLikeState();
    }
  }

  Future<bool> toggle() async {
    if (state.isLoading) return false;
    final wasLiked = state.isLiked;
    state = state.copyWith(isLiked: !wasLiked, isLoading: true);
    try {
      if (wasLiked) {
        await _ds.unlikeStation(stationId);
      } else {
        await _ds.likeStation(stationId);
      }
      _ref.read(likedStationsRefreshTickProvider.notifier).state++;
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException {
      state = StationLikeState(isLiked: wasLiked);
      return false;
    } catch (_) {
      state = StationLikeState(isLiked: wasLiked);
      return false;
    }
  }
}

final stationLikeProvider = StateNotifierProvider.family<StationLikeNotifier,
    StationLikeState, String>(
  (ref, stationId) {
    ref.watch(sessionUserIdProvider);
    return StationLikeNotifier(ref, sl<StationRemoteDataSource>(), stationId);
  },
);

// ── Liked stations list (Library → Stations tab) ──────────────────────────────

final likedStationsProvider =
    FutureProvider.autoDispose<List<LikedStation>>((ref) async {
  ref.watch(likedStationsRefreshTickProvider);
  final userId = ref.watch(sessionUserIdProvider);
  if (userId.isEmpty) return [];
  return sl<StationRemoteDataSource>().getLikedStations();
});
