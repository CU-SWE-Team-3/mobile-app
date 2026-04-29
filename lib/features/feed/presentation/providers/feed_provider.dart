import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/session_provider.dart';
import '../../data/models/feed_track.dart';

export '../../data/models/feed_track.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class FeedState {
  final List<FeedTrack> tracks;
  final bool isLoading;
  final String? error;

  const FeedState({
    this.tracks = const [],
    this.isLoading = false,
    this.error,
  });

  FeedState copyWith({
    List<FeedTrack>? tracks,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      FeedState(
        tracks: tracks ?? this.tracks,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class FeedNotifier extends StateNotifier<FeedState> {
  final String _endpoint;
  final List<dynamic> Function(dynamic) _extractList;

  FeedNotifier(this._endpoint, this._extractList) : super(const FeedState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await dioClient.dio.get(_endpoint);
      final raw = _extractList(response.data);
      final tracks = raw
          .cast<Map<String, dynamic>>()
          .map(FeedTrack.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList();
      state = state.copyWith(tracks: tracks, isLoading: false);
    } on DioException {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load tracks. Check your connection and try again.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final discoverFeedProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(
    '/discovery/trending?limit=20',
    (data) {
      // Response shape: { "data": { "trending": [...] } }
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return (inner['trending'] as List?) ?? [];
      }
      return [];
    },
  );
});

// ---------------------------------------------------------------------------
// Following feed — merges /feed (followed users) + current user's own reposts
// ---------------------------------------------------------------------------

class FollowingFeedNotifier extends StateNotifier<FeedState> {
  FollowingFeedNotifier() : super(const FeedState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final myDisplayName = prefs.getString('displayName') ?? '';
      final myAvatarUrl = prefs.getString('avatarUrl') ?? '';

      // Fetch followed-users feed.
      final feedResponse = await dioClient.dio.get('/feed');
      final feedItems = _extractFeedItems(feedResponse.data);

      // Fetch current user's own reposts; prepend them silently on failure.
      var myRepostItems = <Map<String, dynamic>>[];
      if (userId.isNotEmpty) {
        try {
          final repostsResponse =
              await dioClient.dio.get('/profile/$userId/reposts');
          myRepostItems = _extractMyReposts(
            repostsResponse.data,
            myDisplayName: myDisplayName,
            myAvatarUrl: myAvatarUrl,
          );
        } catch (_) {}
      }

      final combined = [...myRepostItems, ...feedItems];
      final tracks = combined
          .map(FeedTrack.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList();
      state = state.copyWith(tracks: tracks, isLoading: false);
    } on DioException {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load tracks. Check your connection and try again.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }

  // Extracts track-backed activity from /feed response. LIKE is included
  // because it represents a followed user recommending a real track; PROMOTED
  // remains excluded because ads are not playable feed tracks.
  List<Map<String, dynamic>> _extractFeedItems(dynamic data) {
    final dataMap = data['data'];
    if (dataMap is! Map<String, dynamic>) return [];
    final items = (dataMap['feed'] as List?) ?? [];
    final result = <Map<String, dynamic>>[];
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final activityType = raw['activityType'] as String? ?? '';
      if (activityType != 'TRACK_UPLOAD' &&
          activityType != 'REPOST' &&
          activityType != 'LIKE') {
        continue;
      }
      final trackData = _asStringMap(raw['target']);
      if (trackData == null) continue;
      final actorsList = raw['actors'] as List?;
      final actor = actorsList != null && actorsList.isNotEmpty
          ? _asStringMap(actorsList.first)
          : null;
      final timestamp = raw['activityDate'] as String?;
      final normalisedType = activityType == 'REPOST'
          ? 'repost'
          : activityType == 'LIKE'
              ? 'like'
              : 'post';
      result.add(<String, dynamic>{
        ...trackData,
        '_activityType': normalisedType,
        if (actor != null) '_actor': actor,
        if (timestamp != null) '_activityTimestamp': timestamp,
      });
    }
    return result;
  }

  // Converts /profile/{userId}/reposts items into feed-compatible maps.
  List<Map<String, dynamic>> _extractMyReposts(
    dynamic data, {
    required String myDisplayName,
    required String myAvatarUrl,
  }) {
    final dataMap = data['data'];
    if (dataMap is! Map<String, dynamic>) return [];
    final raw = (dataMap['repostedTracks'] as List?) ?? [];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final trackData =
          _asStringMap(item['target']) ?? _asStringMap(item['track']);
      if (trackData == null) continue;
      final repostDate = item['repostDate'] as String?;
      result.add(<String, dynamic>{
        ...trackData,
        '_activityType': 'repost',
        '_actor': {
          'displayName': myDisplayName,
          'avatarUrl': myAvatarUrl,
        },
        if (repostDate != null) '_activityTimestamp': repostDate,
      });
    }
    return result;
  }

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

final followingFeedProvider =
    StateNotifierProvider<FollowingFeedNotifier, FeedState>((ref) {
  ref.watch(sessionUserIdProvider);
  return FollowingFeedNotifier();
});
