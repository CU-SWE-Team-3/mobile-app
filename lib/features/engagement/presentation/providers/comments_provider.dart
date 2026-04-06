import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/models/comment_model.dart';
import '../../data/sources/engagement_remote_data_source.dart';
import '../../../../core/network/dio_client.dart';

// ── State ─────────────────────────────────────────────────────────────────

class CommentsState {
  final List<CommentModel> comments;
  final bool isLoading;
  final bool isPosting;
  final String? error;
  final int currentPage;
  final int totalPages;

  const CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.isPosting = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  bool get hasMore => currentPage <= totalPages;

  CommentsState copyWith({
    List<CommentModel>? comments,
    bool? isLoading,
    bool? isPosting,
    String? error,
    int? currentPage,
    int? totalPages,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isPosting: isPosting ?? this.isPosting,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────

class CommentsNotifier extends StateNotifier<CommentsState> {
  final EngagementRemoteDataSource _dataSource;
  final String _trackId;

  CommentsNotifier(this._dataSource, this._trackId)
      : super(const CommentsState()) {
    loadComments(refresh: true);
  }

  void init(String trackId) {
    // No-op — family provider inits via constructor
  }

  Future<void> loadComments({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _dataSource.getComments(_trackId, page: page);
      state = state.copyWith(
        comments: refresh
            ? result.comments
            : [...state.comments, ...result.comments],
        isLoading: false,
        currentPage: result.page + 1,
        totalPages: result.totalPages,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] as String? ??
            'Failed to load comments',
      );
    }
  }

  Future<bool> postComment({
    required String content,
    required int timestamp,
    String? parentCommentId,
  }) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isPosting: true, error: null);

    try {
      final newComment = await _dataSource.postComment(
        trackId: _trackId,
        content: content.trim(),
        timestamp: timestamp,
        parentCommentId: parentCommentId,
      );

      final updated = [...state.comments];

      if (parentCommentId != null) {
        final idx = updated.indexWhere((c) => c.id == parentCommentId);
        if (idx != -1) {
          final parent = updated[idx];
          final updatedReplies = [
            ...parent.replies,
            CommentReplyModel.fromJson({
              '_id': newComment.id,
              'content': newComment.content,
              'timestamp': newComment.timestamp,
              'user': {
                '_id': newComment.user.id,
                'displayName': newComment.user.displayName,
                'permalink': newComment.user.permalink,
                'avatarUrl': newComment.user.avatarUrl,
              },
              'createdAt': newComment.createdAt.toIso8601String(),
            }),
          ];
          updated[idx] = CommentModel(
            id: parent.id,
            content: parent.content,
            timestamp: parent.timestamp,
            user: parent.user,
            parentCommentId: parent.parentCommentId,
            replies: updatedReplies,
            createdAt: parent.createdAt,
          );
        }
      } else {
        int insertIdx = updated
            .indexWhere((c) => c.timestamp > newComment.timestamp);
        if (insertIdx == -1) {
          updated.add(newComment);
        } else {
          updated.insert(insertIdx, newComment);
        }
      }

      state = state.copyWith(comments: updated, isPosting: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isPosting: false,
        error: e.response?.data?['message'] as String? ??
            'Failed to post comment',
      );
      return false;
    }
  }

  Future<void> deleteComment(String commentId, {String? parentId}) async {
    try {
      await _dataSource.deleteComment(commentId);

      final updated = [...state.comments];
      if (parentId != null) {
        final idx = updated.indexWhere((c) => c.id == parentId);
        if (idx != -1) {
          final parent = updated[idx];
          updated[idx] = CommentModel(
            id: parent.id,
            content: parent.content,
            timestamp: parent.timestamp,
            user: parent.user,
            parentCommentId: parent.parentCommentId,
            replies: parent.replies
                .where((r) => r.id != commentId)
                .toList(),
            createdAt: parent.createdAt,
          );
        }
      } else {
        updated.removeWhere((c) => c.id == commentId);
      }

      state = state.copyWith(comments: updated);
    } on DioException {
      // Silently fail
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final _engagementDataSourceProvider =
    Provider<EngagementRemoteDataSource>((ref) {
  return EngagementRemoteDataSource(dioClient.dio);
});

// Family keyed by trackId — player and comments sheet share same instance
final commentsProvider = StateNotifierProvider.autoDispose
    .family<CommentsNotifier, CommentsState, String>(
  (ref, trackId) => CommentsNotifier(
    ref.read(_engagementDataSourceProvider),
    trackId,
  ),
);