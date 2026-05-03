import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/comments_provider.dart';
import 'package:soundcloud_clone/features/engagement/data/models/comment_model.dart';

void main() {
  // ── EngagementParams ──────────────────────────────────────────────────────

  group('EngagementParams', () {
    test('defaults', () {
      const p = EngagementParams(trackId: 'track-1');
      expect(p.targetModel, 'Track');
      expect(p.isLiked, isFalse);
      expect(p.isReposted, isFalse);
      expect(p.likeCount, 0);
      expect(p.repostCount, 0);
    });

    test('equality uses trackId and targetModel only', () {
      const a = EngagementParams(trackId: 't1', isLiked: true, likeCount: 99);
      const b = EngagementParams(trackId: 't1', isLiked: false, likeCount: 0);
      expect(a == b, isTrue);
    });

    test('different targetModel → not equal', () {
      const a = EngagementParams(trackId: 't1', targetModel: 'Track');
      const b = EngagementParams(trackId: 't1', targetModel: 'Playlist');
      expect(a == b, isFalse);
    });

    test('equal objects have same hashCode', () {
      const a = EngagementParams(trackId: 't1');
      const b = EngagementParams(trackId: 't1');
      expect(a.hashCode, b.hashCode);
    });

    test('different trackIds → not equal', () {
      const a = EngagementParams(trackId: 'a');
      const b = EngagementParams(trackId: 'b');
      expect(a == b, isFalse);
    });

    test('non-EngagementParams object is not equal', () {
      const a = EngagementParams(trackId: 'a');
      expect(a == 'string', isFalse);
    });

    test('all fields can be set', () {
      const p = EngagementParams(
        trackId: 't1',
        targetModel: 'Playlist',
        isLiked: true,
        isReposted: true,
        likeCount: 10,
        repostCount: 5,
      );
      expect(p.trackId, 't1');
      expect(p.targetModel, 'Playlist');
      expect(p.isLiked, isTrue);
      expect(p.isReposted, isTrue);
      expect(p.likeCount, 10);
      expect(p.repostCount, 5);
    });
  });

  // ── EngagementState ───────────────────────────────────────────────────────

  group('EngagementState defaults', () {
    const s = EngagementState();
    test('isLiked', () => expect(s.isLiked, isFalse));
    test('isReposted', () => expect(s.isReposted, isFalse));
    test('likeCount', () => expect(s.likeCount, 0));
    test('repostCount', () => expect(s.repostCount, 0));
    test('isLoadingLike', () => expect(s.isLoadingLike, isFalse));
    test('isLoadingRepost', () => expect(s.isLoadingRepost, isFalse));
  });

  group('EngagementState.copyWith', () {
    const base = EngagementState();

    test('isLiked', () => expect(base.copyWith(isLiked: true).isLiked, isTrue));
    test('isReposted',
        () => expect(base.copyWith(isReposted: true).isReposted, isTrue));
    test('likeCount', () => expect(base.copyWith(likeCount: 10).likeCount, 10));
    test('repostCount',
        () => expect(base.copyWith(repostCount: 7).repostCount, 7));
    test('isLoadingLike',
        () => expect(base.copyWith(isLoadingLike: true).isLoadingLike, isTrue));
    test(
        'isLoadingRepost',
        () => expect(
            base.copyWith(isLoadingRepost: true).isLoadingRepost, isTrue));

    test('preserves original when no args', () {
      const s = EngagementState(isLiked: true, likeCount: 5, repostCount: 3);
      final c = s.copyWith();
      expect(c.isLiked, isTrue);
      expect(c.likeCount, 5);
      expect(c.repostCount, 3);
    });

    test('flip all fields at once', () {
      const s = EngagementState();
      final flipped = s.copyWith(
        isLiked: true,
        isReposted: true,
        likeCount: 100,
        repostCount: 50,
        isLoadingLike: true,
        isLoadingRepost: true,
      );
      expect(flipped.isLiked, isTrue);
      expect(flipped.isReposted, isTrue);
      expect(flipped.likeCount, 100);
      expect(flipped.repostCount, 50);
      expect(flipped.isLoadingLike, isTrue);
      expect(flipped.isLoadingRepost, isTrue);
    });

    test('optimistic like state', () {
      const s = EngagementState(isLiked: false, likeCount: 5);
      final liked =
          s.copyWith(isLiked: true, likeCount: 6, isLoadingLike: true);
      expect(liked.isLiked, isTrue);
      expect(liked.likeCount, 6);
      expect(liked.isLoadingLike, isTrue);
    });

    test('revert like state', () {
      const s =
          EngagementState(isLiked: true, likeCount: 6, isLoadingLike: true);
      final reverted =
          s.copyWith(isLiked: false, likeCount: 5, isLoadingLike: false);
      expect(reverted.isLiked, isFalse);
      expect(reverted.likeCount, 5);
      expect(reverted.isLoadingLike, isFalse);
    });
  });

  // ── CommentsState ─────────────────────────────────────────────────────────

  group('CommentsState defaults', () {
    const s = CommentsState();
    test('comments empty', () => expect(s.comments, isEmpty));
    test('isLoading false', () => expect(s.isLoading, isFalse));
    test('isPosting false', () => expect(s.isPosting, isFalse));
    test('error null', () => expect(s.error, isNull));
    test('currentPage 1', () => expect(s.currentPage, 1));
    test('totalPages 1', () => expect(s.totalPages, 1));
    test('total 0', () => expect(s.total, 0));
  });

  group('CommentsState.hasMore', () {
    test('true when currentPage <= totalPages', () {
      const s = CommentsState(currentPage: 1, totalPages: 3);
      expect(s.hasMore, isTrue);
    });

    test('false when currentPage > totalPages', () {
      const s = CommentsState(currentPage: 4, totalPages: 3);
      expect(s.hasMore, isFalse);
    });

    test('true when currentPage == totalPages', () {
      const s = CommentsState(currentPage: 3, totalPages: 3);
      expect(s.hasMore, isTrue);
    });
  });

  group('CommentsState.copyWith', () {
    test(
        'isLoading',
        () => expect(
            const CommentsState().copyWith(isLoading: true).isLoading, isTrue));
    test(
        'isPosting',
        () => expect(
            const CommentsState().copyWith(isPosting: true).isPosting, isTrue));
    test(
        'error sets',
        () =>
            expect(const CommentsState().copyWith(error: 'err').error, 'err'));
    test('error clears to null when not provided', () {
      final s = const CommentsState(error: 'old').copyWith(isLoading: false);
      expect(s.error, isNull);
    });
    test(
        'currentPage',
        () => expect(
            const CommentsState().copyWith(currentPage: 2).currentPage, 2));
    test(
        'totalPages',
        () => expect(
            const CommentsState().copyWith(totalPages: 5).totalPages, 5));
    test('total',
        () => expect(const CommentsState().copyWith(total: 42).total, 42));

    test('preserves fields when no args', () {
      final user =
          CommentUserModel(id: 'u1', displayName: 'User', permalink: 'u');
      final comment = CommentModel(
        id: 'c1',
        content: 'test',
        timestamp: 10,
        user: user,
        createdAt: DateTime(2024, 1, 1),
      );
      final s = CommentsState(
        comments: [comment],
        currentPage: 2,
        totalPages: 3,
        total: 10,
        isLoading: true,
      );
      final copy = s.copyWith();
      expect(copy.comments.length, 1);
      expect(copy.currentPage, 2);
      expect(copy.totalPages, 3);
      expect(copy.total, 10);
      expect(copy.isLoading, isTrue);
    });

    test('loading state pattern', () {
      const s = CommentsState();
      final loading = s.copyWith(isLoading: true, error: null);
      expect(loading.isLoading, isTrue);
      expect(loading.error, isNull);
    });

    test('posting state pattern', () {
      const s = CommentsState();
      final posting = s.copyWith(isPosting: true);
      expect(posting.isPosting, isTrue);
    });

    test('pagination update pattern', () {
      const s = CommentsState(currentPage: 1, totalPages: 1);
      final updated = s.copyWith(currentPage: 2, totalPages: 5, total: 100);
      expect(updated.currentPage, 2);
      expect(updated.totalPages, 5);
      expect(updated.total, 100);
      expect(updated.hasMore, isTrue);
    });
  });
}
