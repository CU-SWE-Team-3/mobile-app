
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/features/engagement/data/models/comment_model.dart';
import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/comments_provider.dart';

class MockEngagementRemoteDataSource extends Mock
    implements EngagementRemoteDataSource {}

// ── Helpers ──────────────────────────────────────────────────────────────────

CommentModel makeComment({
  String id = 'c1',
  String content = 'Test comment',
  int timestamp = 30,
  String userId = 'u1',
  String displayName = 'Alice',
  List<CommentReplyModel> replies = const [],
}) {
  return CommentModel(
    id: id,
    content: content,
    timestamp: timestamp,
    user: CommentUserModel(
      id: userId,
      displayName: displayName,
      permalink: displayName.toLowerCase(),
    ),
    replies: replies,
    createdAt: DateTime(2024, 1, 1),
  );
}

CommentsResponse emptyResponse() => const CommentsResponse(
      comments: [],
      total: 0,
      page: 1,
      totalPages: 1,
    );

CommentsResponse responseWith(List<CommentModel> comments, {int totalPages = 1}) =>
    CommentsResponse(
      comments: comments,
      total: comments.length,
      page: 1,
      totalPages: totalPages,
    );

DioException dioError({int statusCode = 500, String message = 'Error'}) =>
    DioException(
      requestOptions: RequestOptions(path: '/tracks/track-1/comments'),
      response: Response(
        requestOptions: RequestOptions(path: '/tracks/track-1/comments'),
        statusCode: statusCode,
        data: {'message': message},
      ),
    );

// ── Test setup helpers ───────────────────────────────────────────────────────

/// Builds a [CommentsNotifier] and waits for the auto-load to complete.
Future<CommentsNotifier> buildAndLoad(
  MockEngagementRemoteDataSource mockDataSource, {
  CommentsResponse? initialResponse,
}) async {
  final response = initialResponse ?? emptyResponse();
  when(() => mockDataSource.getComments(
        any(),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => response);

  final notifier = CommentsNotifier(mockDataSource, 'track-1');
  // Drain the microtask queue so the constructor-triggered loadComments finishes
  await pumpEventQueue();
  return notifier;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockEngagementRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockEngagementRemoteDataSource();
  });

  // ── loadComments ───────────────────────────────────────────────────────

  group('loadComments — initial load', () {
    test('populates comments on success', () async {
      final comments = [makeComment(id: 'c1'), makeComment(id: 'c2')];
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith(comments),
      );

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.comments.length, 2);
      expect(notifier.state.comments.map((c) => c.id), ['c1', 'c2']);
      expect(notifier.state.error, isNull);
    });

    test('sets error message on DioException', () async {
      when(() => mockDataSource.getComments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenThrow(dioError(statusCode: 500, message: 'Server error'));

      final notifier = CommentsNotifier(mockDataSource, 'track-1');
      await pumpEventQueue();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, 'Server error');
      expect(notifier.state.comments, isEmpty);
    });

    test('sets generic error when response has no message field', () async {
      when(() => mockDataSource.getComments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/tracks/track-1/comments'),
          response: null,
        ),
      );

      final notifier = CommentsNotifier(mockDataSource, 'track-1');
      await pumpEventQueue();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, 'Failed to load comments');
    });
  });

  group('loadComments — refresh', () {
    test('replaces existing comments when refresh = true', () async {
      final first = [makeComment(id: 'c1')];
      final second = [makeComment(id: 'c2'), makeComment(id: 'c3')];

      // First auto-load returns first set
      when(() => mockDataSource.getComments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => responseWith(first));

      final notifier = CommentsNotifier(mockDataSource, 'track-1');
      await pumpEventQueue();
      expect(notifier.state.comments.map((c) => c.id), ['c1']);

      // Stub second call
      when(() => mockDataSource.getComments(
            any(),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => responseWith(second));

      await notifier.loadComments(refresh: true);

      expect(notifier.state.comments.map((c) => c.id), ['c2', 'c3']);
    });
  });

  // ── postComment — top-level ────────────────────────────────────────────

  group('postComment — top-level', () {
    test('inserts new comment sorted by timestamp (ascending)', () async {
      final existing = [
        makeComment(id: 'c1', timestamp: 10),
        makeComment(id: 'c2', timestamp: 50),
      ];
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith(existing),
      );

      final newComment = makeComment(id: 'c3', timestamp: 30);
      when(() => mockDataSource.postComment(
            trackId: any(named: 'trackId'),
            content: any(named: 'content'),
            timestamp: any(named: 'timestamp'),
            parentCommentId: any(named: 'parentCommentId'),
          )).thenAnswer((_) async => newComment);

      final result = await notifier.postComment(
        content: 'New comment',
        timestamp: 30,
      );

      expect(result, isTrue);
      expect(notifier.state.isPosting, isFalse);

      final ids = notifier.state.comments.map((c) => c.id).toList();
      // c3 (ts=30) must fall between c1 (ts=10) and c2 (ts=50)
      expect(ids.indexOf('c3'), greaterThan(ids.indexOf('c1')));
      expect(ids.indexOf('c3'), lessThan(ids.indexOf('c2')));
    });

    test('appends at end when timestamp exceeds all existing', () async {
      final existing = [makeComment(id: 'c1', timestamp: 10)];
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith(existing),
      );

      final newComment = makeComment(id: 'c2', timestamp: 99);
      when(() => mockDataSource.postComment(
            trackId: any(named: 'trackId'),
            content: any(named: 'content'),
            timestamp: any(named: 'timestamp'),
            parentCommentId: any(named: 'parentCommentId'),
          )).thenAnswer((_) async => newComment);

      await notifier.postComment(content: 'Last', timestamp: 99);

      expect(notifier.state.comments.last.id, 'c2');
    });

    test('returns false and sets error on DioException', () async {
      final notifier = await buildAndLoad(mockDataSource);

      when(() => mockDataSource.postComment(
            trackId: any(named: 'trackId'),
            content: any(named: 'content'),
            timestamp: any(named: 'timestamp'),
            parentCommentId: any(named: 'parentCommentId'),
          )).thenThrow(dioError(statusCode: 400, message: 'Bad request'));

      final result = await notifier.postComment(
        content: 'A comment',
        timestamp: 0,
      );

      expect(result, isFalse);
      expect(notifier.state.error, 'Bad request');
      expect(notifier.state.isPosting, isFalse);
    });
  });

  group('postComment — empty content guard', () {
    test('returns false immediately for blank content', () async {
      final notifier = await buildAndLoad(mockDataSource);

      final result = await notifier.postComment(
        content: '   ',
        timestamp: 0,
      );

      expect(result, isFalse);
      verifyNever(() => mockDataSource.postComment(
            trackId: any(named: 'trackId'),
            content: any(named: 'content'),
            timestamp: any(named: 'timestamp'),
          ));
    });

    test('returns false immediately for empty string', () async {
      final notifier = await buildAndLoad(mockDataSource);

      final result = await notifier.postComment(content: '', timestamp: 0);

      expect(result, isFalse);
      verifyNever(() => mockDataSource.postComment(
            trackId: any(named: 'trackId'),
            content: any(named: 'content'),
            timestamp: any(named: 'timestamp'),
          ));
    });
  });

  // ── postComment — reply ────────────────────────────────────────────────

  group('postComment — reply to parent', () {
    test('appends reply to the matching parent comment', () async {
      final parent = makeComment(id: 'parent-1', replies: []);
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith([parent]),
      );

      final replyComment = makeComment(id: 'reply-1', content: 'Nice track!');
      when(() => mockDataSource.postComment(
            trackId: any(named: 'trackId'),
            content: any(named: 'content'),
            timestamp: any(named: 'timestamp'),
            parentCommentId: any(named: 'parentCommentId'),
          )).thenAnswer((_) async => replyComment);

      final result = await notifier.postComment(
        content: 'Nice track!',
        timestamp: 30,
        parentCommentId: 'parent-1',
      );

      expect(result, isTrue);
      final updatedParent =
          notifier.state.comments.firstWhere((c) => c.id == 'parent-1');
      expect(updatedParent.replies.length, 1);
      expect(updatedParent.replies.first.id, 'reply-1');
      expect(updatedParent.replies.first.content, 'Nice track!');
    });

    test('does not add a new top-level comment when parentCommentId is provided',
        () async {
      final parent = makeComment(id: 'parent-1', replies: []);
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith([parent]),
      );

      final replyComment = makeComment(id: 'reply-1');
      when(() => mockDataSource.postComment(
            trackId: any(named: 'trackId'),
            content: any(named: 'content'),
            timestamp: any(named: 'timestamp'),
            parentCommentId: any(named: 'parentCommentId'),
          )).thenAnswer((_) async => replyComment);

      await notifier.postComment(
        content: 'A reply',
        timestamp: 5,
        parentCommentId: 'parent-1',
      );

      // Still only 1 top-level comment (parent-1)
      expect(notifier.state.comments.length, 1);
    });

    test('silently ignores reply to unknown parentCommentId', () async {
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: emptyResponse(),
      );

      final replyComment = makeComment(id: 'reply-1');
      when(() => mockDataSource.postComment(
            trackId: any(named: 'trackId'),
            content: any(named: 'content'),
            timestamp: any(named: 'timestamp'),
            parentCommentId: any(named: 'parentCommentId'),
          )).thenAnswer((_) async => replyComment);

      await notifier.postComment(
        content: 'Orphaned reply',
        timestamp: 0,
        parentCommentId: 'ghost-parent',
      );

      expect(notifier.state.comments, isEmpty);
    });
  });

  // ── deleteComment ──────────────────────────────────────────────────────

  group('deleteComment — top-level', () {
    test('removes the correct top-level comment by id', () async {
      final comments = [
        makeComment(id: 'c1'),
        makeComment(id: 'c2'),
        makeComment(id: 'c3'),
      ];
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith(comments),
      );

      when(() => mockDataSource.deleteComment(any()))
          .thenAnswer((_) async {});

      await notifier.deleteComment('c2');

      expect(
        notifier.state.comments.map((c) => c.id).toList(),
        ['c1', 'c3'],
      );
    });

    test('calls deleteComment on the data source with correct id', () async {
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith([makeComment(id: 'del-me')]),
      );

      when(() => mockDataSource.deleteComment(any()))
          .thenAnswer((_) async {});

      await notifier.deleteComment('del-me');

      verify(() => mockDataSource.deleteComment('del-me')).called(1);
    });
  });

  group('deleteComment — reply', () {
    test('removes the reply from the parent and keeps other replies', () async {
      final reply1 = CommentReplyModel(
        id: 'r1',
        content: 'First reply',
        timestamp: 10,
        user: const CommentUserModel(
          id: 'u2',
          displayName: 'Bob',
          permalink: 'bob',
        ),
        createdAt: DateTime(2024, 1, 1),
      );
      final reply2 = CommentReplyModel(
        id: 'r2',
        content: 'Second reply',
        timestamp: 20,
        user: const CommentUserModel(
          id: 'u3',
          displayName: 'Carol',
          permalink: 'carol',
        ),
        createdAt: DateTime(2024, 1, 2),
      );
      final parent = makeComment(id: 'parent-1', replies: [reply1, reply2]);
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith([parent]),
      );

      when(() => mockDataSource.deleteComment(any()))
          .thenAnswer((_) async {});

      await notifier.deleteComment('r1', parentId: 'parent-1');

      final updated =
          notifier.state.comments.firstWhere((c) => c.id == 'parent-1');
      expect(updated.replies.length, 1);
      expect(updated.replies.first.id, 'r2');
    });

    test('parent comment remains in list after reply deletion', () async {
      final reply = CommentReplyModel(
        id: 'r1',
        content: 'Reply',
        timestamp: 5,
        user: const CommentUserModel(
          id: 'u2',
          displayName: 'Bob',
          permalink: 'bob',
        ),
        createdAt: DateTime(2024, 1, 1),
      );
      final parent = makeComment(id: 'p1', replies: [reply]);
      final notifier = await buildAndLoad(
        mockDataSource,
        initialResponse: responseWith([parent]),
      );

      when(() => mockDataSource.deleteComment(any()))
          .thenAnswer((_) async {});

      await notifier.deleteComment('r1', parentId: 'p1');

      expect(notifier.state.comments.length, 1);
      expect(notifier.state.comments.first.id, 'p1');
    });
  });

  // ── CommentsState helpers ──────────────────────────────────────────────

  group('CommentsState.hasMore', () {
    test('true when currentPage <= totalPages', () {
      const state = CommentsState(currentPage: 1, totalPages: 3);
      expect(state.hasMore, isTrue);
    });

    test('false when currentPage > totalPages', () {
      const state = CommentsState(currentPage: 4, totalPages: 3);
      expect(state.hasMore, isFalse);
    });
  });
}
