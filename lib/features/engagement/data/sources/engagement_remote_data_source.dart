import 'package:dio/dio.dart';

import '../models/comment_model.dart';

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
}