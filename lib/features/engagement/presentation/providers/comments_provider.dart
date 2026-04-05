import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/models/comment_model.dart';
import '../../data/sources/engagement_remote_data_source.dart';
import '../../../../core/network/dio_client.dart';

// ── State ──────────────────────────────────────────────────────────────────

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

  bool get hasMore => currentPage < totalPages;

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

// ── Notifier ───────────────────────────────────────────────────────────────

class CommentsNotifier extends StateNotifier<CommentsState> {
  final EngagementRemoteDataSource _dataSource;
  String? _trackId;

  CommentsNotifier(this._dataSource) : super(const CommentsState());

  void init(String trackId) {
    if (_trackId == trackId) return;
    _trackId = trackId;
    loadComments(refresh: true);
  }

  Future<void> loadComments({bool refresh = false}) async {
    if (_trackId == null) return;
    if (state.isLoading) return;

    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final comments = await _dataSource.getComments(_trackId!, page: page);
      state = state.copyWith(
        comments: refresh ? comments : [...state.comments, ...comments],
        isLoading: false,
        currentPage: page + 1,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['message'] as String? ?? 'Failed to load comments',
      );
    }
  }

  Future<bool> postComment({
    required String content,
    required int timestamp,
    String? parentCommentId,
  }) async {
    if (_trackId == null || content.trim().isEmpty) return false;

    state = state.copyWith(isPosting: true, error: null);

    try {
      final newComment = await _dataSource.postComment(
        trackId: _trackId!,
        content: content.trim(),
        timestamp: timestamp,
        parentCommentId: parentCommentId,
      );

      // Insert the new comment at its correct timestamp position
      final updated = [...state.comments];
      if (parentCommentId != null) {
        // It's a reply — append to the parent's replies list
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
        // Top-level: insert sorted by timestamp
        int insertIdx = updated.indexWhere((c) => c.timestamp > newComment.timestamp);
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
        error: e.response?.data['message'] as String? ?? 'Failed to post comment',
      );
      return false;
    }
  }

  Future<void> deleteComment(String commentId, {String? parentId}) async {
    try {
      await _dataSource.deleteComment(commentId);

      final updated = [...state.comments];
      if (parentId != null) {
        // It's a reply
        final idx = updated.indexWhere((c) => c.id == parentId);
        if (idx != -1) {
          final parent = updated[idx];
          updated[idx] = CommentModel(
            id: parent.id,
            content: parent.content,
            timestamp: parent.timestamp,
            user: parent.user,
            parentCommentId: parent.parentCommentId,
            replies: parent.replies.where((r) => r.id != commentId).toList(),
            createdAt: parent.createdAt,
          );
        }
      } else {
        updated.removeWhere((c) => c.id == commentId);
      }

      state = state.copyWith(comments: updated);
    } on DioException {
      // Silently fail — don't disrupt UX for delete errors
    }
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final _engagementDataSourceProvider = Provider<EngagementRemoteDataSource>((ref) {
  return EngagementRemoteDataSource(dioClient.dio);
});

// Family keyed by trackId — player and comments sheet share the same instance
final commentsProvider = StateNotifierProvider.autoDispose
    .family<CommentsNotifier, CommentsState, String>(
  (ref, trackId) {
    final notifier = CommentsNotifier(ref.read(_engagementDataSourceProvider));
    notifier.init(trackId);
    return notifier;
  },
);