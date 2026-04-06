import 'package:dio/dio.dart';

import '../models/comment_model.dart';
import '../models/liker_user_model.dart';

// ── Shared track summary model (liked tracks + reposts lists) ─────────────────

class TrackSummary {
  final String id;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final String? audioUrl;
  final int playCount;
  final int likeCount;
  final int repostCount;

  const TrackSummary({
    required this.id,
    required this.title,
    required this.artistName,
    this.artworkUrl,
    this.audioUrl,
    this.playCount = 0,
    this.likeCount = 0,
    this.repostCount = 0,
  });

  factory TrackSummary.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final id = json['_id'] as String? ?? '';
    return TrackSummary(
      id: id,
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      audioUrl: json['audioUrl'] as String? ??
          json['streamUrl'] as String? ??
          (id.isNotEmpty
              ? 'https://biobeatsstorage2026.blob.core.windows.net/biobeats-audio/hls/$id/playlist.m3u8'
              : null),
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
    );
  }
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
    await _dio.post('/tracks/$trackId/like');
  }

  Future<void> unlikeTrack(String trackId) async {
    await _dio.delete('/tracks/$trackId/like');
  }

  // ── Repost ────────────────────────────────────────────────────────────────

  Future<void> repostTrack(String trackId) async {
    await _dio.post('/tracks/$trackId/repost');
  }

  Future<void> unRepostTrack(String trackId) async {
    await _dio.delete('/tracks/$trackId/repost');
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

  // ── Current user's liked tracks ───────────────────────────────────────────

  Future<List<TrackSummary>> getLikedTracks() async {
    final response = await _dio.get('/me/likes');
    final body = response.data['data'];
    final List<dynamic> raw = body is List
        ? body
        : (body as Map<String, dynamic>?)?['tracks'] as List<dynamic>? ?? [];
    return raw
        .map((t) => TrackSummary.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  // ── Current user's reposted tracks ───────────────────────────────────────

  Future<List<TrackSummary>> getUserReposts() async {
    final response = await _dio.get('/me/reposts');
    final body = response.data['data'];
    final List<dynamic> raw = body is List
        ? body
        : (body as Map<String, dynamic>?)?['tracks'] as List<dynamic>? ?? [];
    return raw
        .map((t) => TrackSummary.fromJson(t as Map<String, dynamic>))
        .toList();
  }
}