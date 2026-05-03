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
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  const FeedState({
    this.tracks = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
  });

  FeedState copyWith({
    List<FeedTrack>? tracks,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    bool clearNextCursor = false,
    String? error,
    bool clearError = false,
  }) =>
      FeedState(
        tracks: tracks ?? this.tracks,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
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
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      hasMore: false,
      clearNextCursor: true,
      clearError: true,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final myDisplayName = prefs.getString('displayName') ?? '';
      final myAvatarUrl = prefs.getString('avatarUrl') ?? '';

      // Fetch followed-users feed. Only their uploads are shown; their
      // likes/reposts/promoted cards are filtered out in _extractFeedItems.
      final feedResponse = await dioClient.dio.get(
        '/feed',
        queryParameters: {'limit': 40},
      );
      final feedItems = _extractFeedItems(feedResponse.data);
      final pagination = _extractPagination(feedResponse.data);
      final fallbackItems =
          feedItems.isEmpty ? await _fetchFollowedUserUploads(userId) : [];

      // Fetch current user's own reposts; keep them before followed users'
      // uploaded tracks.
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

      final combined = <Map<String, dynamic>>[
        ...myRepostItems,
        ...feedItems,
        ...fallbackItems,
      ];
      final tracks = combined
          .map(FeedTrack.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList();
      state = state.copyWith(
        tracks: tracks,
        isLoading: false,
        hasMore: pagination.hasMore,
        nextCursor: pagination.nextCursor,
      );
    } on DioException {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Failed to load tracks. Check your connection and try again.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFollowedUserUploads(
      String userId) async {
    if (userId.isEmpty) return [];
    final response = await dioClient.dio.get(
      '/network/$userId/following',
      queryParameters: {'page': 1, 'limit': 50},
    );
    final followedUsers = (response.data['data'] as List?) ?? [];
    final uploads = <Map<String, dynamic>>[];

    for (final rawUser in followedUsers) {
      final user = _asStringMap(rawUser);
      final followedUserId = user?['_id']?.toString();
      if (user == null || followedUserId == null || followedUserId.isEmpty) {
        continue;
      }
      final tracks = await _fetchUserTracks(followedUserId);
      for (final track in tracks) {
        uploads.add(<String, dynamic>{
          ...track,
          if (_asStringMap(track['artist']) == null &&
              _asStringMap(track['user']) == null)
            'artist': user,
          '_activityType': 'post',
          '_actor': user,
          if (_trackTimestamp(track) != null)
            '_activityTimestamp': _trackTimestamp(track),
        });
      }
    }

    uploads.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['_activityTimestamp']?.toString() ?? '');
      final bTime =
          DateTime.tryParse(b['_activityTimestamp']?.toString() ?? '');
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return uploads;
  }

  Future<List<Map<String, dynamic>>> _fetchUserTracks(String userId) async {
    const listKeys = ['uploadedTracks', 'tracks', 'topTracks'];
    for (final endpoint in [
      '/profile/$userId/tracks',
      '/users/$userId/tracks',
    ]) {
      try {
        final response = await dioClient.dio.get(
          endpoint,
          queryParameters: const {'page': 1, 'limit': 20},
        );
        final tracks = _extractTrackList(response.data, listKeys);
        if (tracks.isNotEmpty) return tracks;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
          continue;
        }
        rethrow;
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _extractTrackList(
    dynamic data,
    List<String> listKeys,
  ) {
    if (data is List) return data.map(_asStringMap).nonNulls.toList();
    final root = _asStringMap(data);
    if (root == null) return [];
    for (final key in listKeys) {
      final list = root[key];
      if (list is List) return list.map(_asStringMap).nonNulls.toList();
    }
    final inner = _asStringMap(root['data']);
    if (inner != null) {
      for (final key in listKeys) {
        final list = inner[key];
        if (list is List) return list.map(_asStringMap).nonNulls.toList();
      }
      final user = _asStringMap(inner['user']);
      if (user != null) {
        for (final key in listKeys) {
          final list = user[key];
          if (list is List) return list.map(_asStringMap).nonNulls.toList();
        }
      }
    }
    return [];
  }

  String? _trackTimestamp(Map<String, dynamic> track) {
    for (final key in const [
      'createdAt',
      'updatedAt',
      'releaseDate',
      'uploadedAt',
      'publishedAt',
    ]) {
      final value = track[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final response = await dioClient.dio.get(
        '/feed',
        queryParameters: {
          'cursor': cursor,
          'limit': 40,
        },
      );
      final nextItems = _extractFeedItems(response.data);
      final pagination = _extractPagination(response.data);
      final nextTracks = nextItems
          .map(FeedTrack.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList();

      state = state.copyWith(
        tracks: _appendUniqueTracks(state.tracks, nextTracks),
        isLoadingMore: false,
        hasMore: pagination.hasMore,
        nextCursor: pagination.nextCursor,
      );
    } on DioException {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load more activities. Please try again.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }

  // Extracts only uploaded tracks from /feed response.
  List<Map<String, dynamic>> _extractFeedItems(dynamic data) {
    final dataMap = data['data'];
    if (dataMap is! Map<String, dynamic>) return [];
    final items = (dataMap['feed'] as List?) ?? [];
    final result = <Map<String, dynamic>>[];
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final activityType = raw['activityType'] as String? ?? '';
      final targetModel = raw['targetModel']?.toString().toLowerCase();
      if (activityType != 'TRACK_UPLOAD') continue;
      if (targetModel != null && targetModel != 'track') continue;
      final trackData = _asStringMap(raw['target']);
      if (trackData == null) continue;
      final actorsList = raw['actors'] as List?;
      final actor = actorsList != null && actorsList.isNotEmpty
          ? _asStringMap(actorsList.first)
          : null;
      final timestamp = raw['activityDate'] as String?;
      result.add(<String, dynamic>{
        ...trackData,
        '_activityType': 'post',
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

  _FeedPagination _extractPagination(dynamic data) {
    final dataMap = data['data'];
    if (dataMap is! Map<String, dynamic>) {
      return const _FeedPagination();
    }

    final pagination = dataMap['pagination'];
    if (pagination is! Map<String, dynamic>) {
      return const _FeedPagination();
    }

    final nextCursor = pagination['nextCursor']?.toString();
    final hasMore = pagination['hasMore'] == true;
    return _FeedPagination(
      nextCursor:
          nextCursor != null && nextCursor.isNotEmpty ? nextCursor : null,
      hasMore: hasMore,
    );
  }

  List<FeedTrack> _appendUniqueTracks(
    List<FeedTrack> existing,
    List<FeedTrack> incoming,
  ) {
    final seen = existing.map(_trackKey).toSet();
    final merged = [...existing];
    for (final track in incoming) {
      final key = _trackKey(track);
      if (seen.add(key)) {
        merged.add(track);
      }
    }
    return merged;
  }

  String _trackKey(FeedTrack track) {
    return [
      track.id,
      track.activityType ?? '',
      track.activityTimestamp?.toIso8601String() ?? '',
    ].join('|');
  }

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

class _FeedPagination {
  const _FeedPagination({
    this.nextCursor,
    this.hasMore = false,
  });

  final String? nextCursor;
  final bool hasMore;
}

final followingFeedProvider =
    StateNotifierProvider<FollowingFeedNotifier, FeedState>((ref) {
  ref.watch(sessionUserIdProvider);
  return FollowingFeedNotifier();
});
