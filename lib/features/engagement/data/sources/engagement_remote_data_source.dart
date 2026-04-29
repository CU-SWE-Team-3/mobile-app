import 'package:dio/dio.dart';

import '../models/comment_model.dart';
import '../models/liker_user_model.dart';
import 'package:flutter/foundation.dart';

// ── Shared track summary model (liked tracks + reposts lists) ─────────────────

class TrackSummary {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
  final String? artworkUrl;
  final String? audioUrl;
  final int playCount;
  final int likeCount;
  final int repostCount;
  final List<int>? waveform;

  const TrackSummary({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.artistPermalink,
    this.artworkUrl,
    this.audioUrl,
    this.playCount = 0,
    this.likeCount = 0,
    this.repostCount = 0,
    this.waveform,
  });

  factory TrackSummary.fromJson(Map<String, dynamic> json) {
    final artist = _asStringMap(
      json['artist'] ?? json['creator'] ?? json['user'],
    );
    final audio = _asStringMap(json['audio']);
    final id = json['_id'] as String? ?? json['id'] as String? ?? '';
    return TrackSummary(
      id: id,
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ??
          artist['username'] as String? ??
          artist['name'] as String? ??
          '',
      artistId: artist['_id'] as String? ?? artist['id'] as String?,
      artistPermalink: artist['permalink'] as String?,
      artworkUrl: json['artworkUrl'] as String? ??
          json['coverUrl'] as String? ??
          json['imageUrl'] as String?,
      audioUrl: json['audioUrl'] as String? ??
          json['streamUrl'] as String? ??
          json['hlsUrl'] as String? ??
          audio['hlsUrl'] as String? ??
          audio['url'] as String? ??
          (id.isNotEmpty
              ? 'https://biobeatsstorage2026.blob.core.windows.net/biobeats-audio/hls/$id/playlist.m3u8'
              : null),
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.whereType<num>()
          .map((e) => e.toInt())
          .toList(),
    );
  }
}

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

// ─────────────────────────────────────────────────────────────────────────────

class CommentsResponse {
  final List<CommentModel> comments;
  final int total;
  final int page;
  final int totalPages;

  const CommentsResponse({
    required this.comments,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

class EngagementRemoteDataSource {
  final Dio _dio;

  EngagementRemoteDataSource(this._dio);

  // ── Comments ─────────────────────────────────────────────────────────────

  Future<CommentsResponse> getComments(
    String trackId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/tracks/$trackId/comments',
      queryParameters: {'page': page, 'limit': limit},
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final raw = data['comments'] as List<dynamic>? ?? [];
    final comments = raw
        .map((c) => CommentModel.fromJson(c as Map<String, dynamic>))
        .toList();

    return CommentsResponse(
      comments: comments,
      total: (data['total'] as num?)?.toInt() ?? comments.length,
      page: (data['page'] as num?)?.toInt() ?? page,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<CommentModel> postComment({
    required String trackId,
    required String content,
    required int timestamp,
    String? parentCommentId,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'timestamp': timestamp,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
    };
    final response = await _dio.post('/tracks/$trackId/comments', data: body);
    final data = response.data['data'] as Map<String, dynamic>;
    return CommentModel.fromJson(data['comment'] as Map<String, dynamic>);
  }

  Future<void> deleteComment(String commentId) async {
    await _dio.delete('/comments/$commentId');
  }

  // ── Like ──────────────────────────────────────────────────────────────────

  Future<void> likeTrack(String trackId) async {
    await _dio.post('/tracks/$trackId/like', data: {'targetModel': 'Track'});
  }

  Future<void> unlikeTrack(String trackId) async {
    await _dio.delete('/tracks/$trackId/like', data: {'targetModel': 'Track'});
  }

  // ── Repost ────────────────────────────────────────────────────────────────

  Future<void> repostTrack(String trackId) async {
    await _dio.post('/tracks/$trackId/repost', data: {'targetModel': 'Track'});
  }

  Future<void> unRepostTrack(String trackId) async {
    await _dio.delete('/tracks/$trackId/repost', data: {'targetModel': 'Track'});
  }

  // ── Likers list ───────────────────────────────────────────────────────────

  Future<List<LikerUser>> getLikers(String trackId) async {
    final response = await _dio.get('/tracks/$trackId/likers');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = (data['users'] as List<dynamic>?) ?? [];
    return raw
        .map((u) => LikerUser.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  // ── Reposters list ────────────────────────────────────────────────────────

  Future<List<LikerUser>> getReposters(String trackId) async {
    final response = await _dio.get('/tracks/$trackId/reposters');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = (data['users'] as List<dynamic>?) ?? [];
    return raw
        .map((u) => LikerUser.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  // ── Current user's liked tracks ──────────────────────────────────────────
  // GET /profile/{userId}/likes
  // Response: { data: { likedTracks: [{ likeDate, target: {...} }], pagination } }
  // ('target' is the current key; falls back to 'track' for backward compat)
  Future<List<TrackSummary>> getUserLikes(String userId) async {
    final response = await _dio.get('/profile/$userId/likes');
    final root = _asStringMap(response.data);
    final data = _asStringMap(root['data']);

    final rawItems = data['likedTracks'] ??
        data['tracks'] ??
        root['likedTracks'] ??
        root['tracks'] ??
        (root['data'] is List ? root['data'] : null);

    if (rawItems is! List) {
      debugPrint('[Likes] Unexpected response shape: ${response.data}');
      return const [];
    }

    final tracks = <TrackSummary>[];
    for (final item in rawItems) {
      final itemMap = _asStringMap(item);
      if (itemMap.isEmpty) continue;

      final targetModel = itemMap['targetModel'] as String?;
      if (targetModel != null && targetModel.toLowerCase() != 'track') {
        continue;
      }

      // Resolve the nested track object. Three possible shapes from the API:
      //   A) target/track/item is a populated Map  → use it directly
      //   B) target/track/item is a bare ObjectId string (un-populated ref)
      //      → use itemMap for display fields but override _id with that string
      //   C) none of those keys exist → itemMap IS the track record
      Map<String, dynamic> track;
      final targetVal = itemMap['target'];
      final trackVal  = itemMap['track'];
      final itemVal   = itemMap['item'];

      if (targetVal is Map) {
        track = _asStringMap(targetVal);
      } else if (trackVal is Map) {
        track = _asStringMap(trackVal);
      } else if (itemVal is Map) {
        track = _asStringMap(itemVal);
      } else if (targetVal is String && targetVal.isNotEmpty) {
        // Shape B: target is an un-populated ObjectId — authoritative ID is
        // the string itself; remaining display fields live in itemMap.
        track = Map<String, dynamic>.from(itemMap)..['_id'] = targetVal;
      } else if (trackVal is String && trackVal.isNotEmpty) {
        track = Map<String, dynamic>.from(itemMap)..['_id'] = trackVal;
      } else {
        // Shape C: treat the item itself as the track record.
        track = itemMap;
      }

      if (track.isEmpty) continue;

      final summary = TrackSummary.fromJson(track);
      if (summary.id.isNotEmpty) tracks.add(summary);
    }

    return tracks;
  }

  // ── Current user's reposted tracks ───────────────────────────────────────
  // GET /profile/{userId}/reposts
  // Response: { data: { repostedTracks: [{ repostDate, track: {...} }], pagination } }

  Future<List<TrackSummary>> getUserReposts(String userId) async {
    final response = await _dio.get('/profile/$userId/reposts');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = (data['repostedTracks'] as List<dynamic>?) ?? [];
    return raw.map((item) {
      final map = item as Map<String, dynamic>;
      // The backend uses 'target' as the track key (same as the likes endpoint).
      // Fall back to 'track' for backward compatibility with older API versions.
      final track = (map['target'] ?? map['track']) as Map<String, dynamic>? ?? map;
      return TrackSummary.fromJson(track);
    }).toList();
  }
}
