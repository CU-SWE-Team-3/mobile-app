import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

// ── Helpers ──────────────────────────────────────────────────────────────────

Response<dynamic> successResponse(dynamic data, {String path = ''}) => Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data,
    );

Map<String, dynamic> fakeCommentJson({
  String id = 'c1',
  String content = 'Hello',
  int timestamp = 15,
  String userId = 'u1',
  String displayName = 'Alice',
}) =>
    {
      '_id': id,
      'content': content,
      'timestamp': timestamp,
      'user': {
        '_id': userId,
        'displayName': displayName,
        'permalink': displayName.toLowerCase(),
      },
      'replies': [],
      'createdAt': '2024-01-01T00:00:00.000Z',
    };

Map<String, dynamic> fakeUserJson({
  String id = 'u1',
  String displayName = 'Alice',
  String permalink = 'alice',
  bool isFollowing = false,
}) =>
    {
      '_id': id,
      'displayName': displayName,
      'permalink': permalink,
      'isFollowing': isFollowing,
    };

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockDio mockDio;
  late EngagementRemoteDataSource dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = EngagementRemoteDataSource(mockDio);
    // Register fallback values so mocktail can handle any() matchers on these
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: ''));
  });

  // ── likeTrack / unlikeTrack ──────────────────────────────────────────────

  group('likeTrack', () {
    test('issues POST /tracks/{id}/like', () async {
      when(() => mockDio.post('/tracks/abc/like'))
          .thenAnswer((_) async => successResponse({}));

      await dataSource.likeTrack('abc');

      verify(() => mockDio.post('/tracks/abc/like')).called(1);
    });

    test('propagates DioException on failure', () async {
      when(() => mockDio.post(any())).thenThrow(
        DioException(requestOptions: RequestOptions(path: '')),
      );

      expect(
        () => dataSource.likeTrack('abc'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('unlikeTrack', () {
    test('issues DELETE /tracks/{id}/like', () async {
      when(() => mockDio.delete('/tracks/abc/like'))
          .thenAnswer((_) async => successResponse({}));

      await dataSource.unlikeTrack('abc');

      verify(() => mockDio.delete('/tracks/abc/like')).called(1);
    });
  });

  // ── repostTrack / unRepostTrack ─────────────────────────────────────────

  group('repostTrack', () {
    test('issues POST /tracks/{id}/repost', () async {
      when(() => mockDio.post('/tracks/xyz/repost'))
          .thenAnswer((_) async => successResponse({}));

      await dataSource.repostTrack('xyz');

      verify(() => mockDio.post('/tracks/xyz/repost')).called(1);
    });
  });

  group('unRepostTrack', () {
    test('issues DELETE /tracks/{id}/repost', () async {
      when(() => mockDio.delete('/tracks/xyz/repost'))
          .thenAnswer((_) async => successResponse({}));

      await dataSource.unRepostTrack('xyz');

      verify(() => mockDio.delete('/tracks/xyz/repost')).called(1);
    });
  });

  // ── getComments ──────────────────────────────────────────────────────────

  group('getComments', () {
    test('calls GET /tracks/{id}/comments with page + limit params', () async {
      when(() => mockDio.get(
            '/tracks/t1/comments',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => successResponse({
            'data': {
              'comments': [],
              'total': 0,
              'page': 1,
              'totalPages': 1,
            }
          }));

      await dataSource.getComments('t1', page: 2, limit: 25);

      final call = verify(() => mockDio.get(
            '/tracks/t1/comments',
            queryParameters: captureAny(named: 'queryParameters'),
          ));
      call.called(1);
      final params = call.captured.first as Map<String, dynamic>;
      expect(params['page'], 2);
      expect(params['limit'], 25);
    });

    test('parses comment list and metadata from response', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => successResponse({
            'data': {
              'comments': [
                fakeCommentJson(id: 'c1', content: 'Hello', timestamp: 15),
                fakeCommentJson(id: 'c2', content: 'World', timestamp: 60),
              ],
              'total': 2,
              'page': 1,
              'totalPages': 3,
            }
          }));

      final result = await dataSource.getComments('t1');

      expect(result.comments.length, 2);
      expect(result.comments[0].id, 'c1');
      expect(result.comments[0].content, 'Hello');
      expect(result.comments[0].timestamp, 15);
      expect(result.comments[1].id, 'c2');
      expect(result.total, 2);
      expect(result.page, 1);
      expect(result.totalPages, 3);
    });

    test('handles empty comments array', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => successResponse({
            'data': {
              'comments': [],
              'total': 0,
              'page': 1,
              'totalPages': 1,
            }
          }));

      final result = await dataSource.getComments('t1');

      expect(result.comments, isEmpty);
      expect(result.total, 0);
    });

    test('parses user fields inside each comment', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => successResponse({
            'data': {
              'comments': [
                fakeCommentJson(userId: 'u99', displayName: 'Ziad'),
              ],
              'total': 1,
              'page': 1,
              'totalPages': 1,
            }
          }));

      final result = await dataSource.getComments('t1');

      expect(result.comments.first.user.id, 'u99');
      expect(result.comments.first.user.displayName, 'Ziad');
    });
  });

  // ── postComment ──────────────────────────────────────────────────────────

  group('postComment', () {
    test('issues POST /tracks/{id}/comments with content and timestamp',
        () async {
      when(() => mockDio.post(
            '/tracks/t1/comments',
            data: any(named: 'data'),
          )).thenAnswer((_) async => successResponse({
            'data': {
              'comment': fakeCommentJson(id: 'new-c', content: 'My comment'),
            }
          }));

      await dataSource.postComment(
        trackId: 't1',
        content: 'My comment',
        timestamp: 42,
      );

      final call = verify(() => mockDio.post(
            '/tracks/t1/comments',
            data: captureAny(named: 'data'),
          ));
      call.called(1);
      final body = call.captured.first as Map<String, dynamic>;
      expect(body['content'], 'My comment');
      expect(body['timestamp'], 42);
    });

    test('includes parentCommentId in body when provided', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => successResponse({
            'data': {
              'comment': fakeCommentJson(id: 'reply-1'),
            }
          }));

      await dataSource.postComment(
        trackId: 't1',
        content: 'A reply',
        timestamp: 10,
        parentCommentId: 'parent-c1',
      );

      final body = verify(() => mockDio.post(
            any(),
            data: captureAny(named: 'data'),
          )).captured.first as Map<String, dynamic>;
      expect(body['parentCommentId'], 'parent-c1');
    });

    test('omits parentCommentId from body when null', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => successResponse({
            'data': {
              'comment': fakeCommentJson(),
            }
          }));

      await dataSource.postComment(
        trackId: 't1',
        content: 'Top-level',
        timestamp: 0,
      );

      final body = verify(() => mockDio.post(
            any(),
            data: captureAny(named: 'data'),
          )).captured.first as Map<String, dynamic>;
      expect(body.containsKey('parentCommentId'), isFalse);
    });

    test('returns a CommentModel with correct fields', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => successResponse({
            'data': {
              'comment': fakeCommentJson(
                id: 'parsed-c',
                content: 'Parsed',
                timestamp: 77,
              ),
            }
          }));

      final comment = await dataSource.postComment(
        trackId: 't1',
        content: 'Parsed',
        timestamp: 77,
      );

      expect(comment.id, 'parsed-c');
      expect(comment.content, 'Parsed');
      expect(comment.timestamp, 77);
    });
  });

  // ── deleteComment ────────────────────────────────────────────────────────

  group('deleteComment', () {
    test('issues DELETE /comments/{id}', () async {
      when(() => mockDio.delete('/comments/c99'))
          .thenAnswer((_) async => successResponse({}));

      await dataSource.deleteComment('c99');

      verify(() => mockDio.delete('/comments/c99')).called(1);
    });
  });

  // ── getLikers ────────────────────────────────────────────────────────────

  group('getLikers', () {
    test('issues GET /tracks/{id}/likers', () async {
      when(() => mockDio.get('/tracks/t1/likers'))
          .thenAnswer((_) async => successResponse({
                'data': {'users': []}
              }));

      await dataSource.getLikers('t1');

      verify(() => mockDio.get('/tracks/t1/likers')).called(1);
    });

    test('parses users list from response', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => successResponse({
            'data': {
              'users': [
                fakeUserJson(id: 'u1', displayName: 'Alice'),
                fakeUserJson(id: 'u2', displayName: 'Bob', isFollowing: true),
              ]
            }
          }));

      final likers = await dataSource.getLikers('t1');

      expect(likers.length, 2);
      expect(likers[0].id, 'u1');
      expect(likers[0].displayName, 'Alice');
      expect(likers[0].isFollowing, isFalse);
      expect(likers[1].id, 'u2');
      expect(likers[1].isFollowing, isTrue);
    });

    test('returns empty list when users key is absent', () async {
      // Use explicitly typed map so the as Map<String, dynamic>? cast in
      // production code does not fail on _Map<dynamic, dynamic>
      when(() => mockDio.get(any())).thenAnswer((_) async =>
          successResponse(<String, dynamic>{'data': <String, dynamic>{}}));

      final likers = await dataSource.getLikers('t1');

      expect(likers, isEmpty);
    });
  });

  // ── getReposters ─────────────────────────────────────────────────────────

  group('getReposters', () {
    test('issues GET /tracks/{id}/reposters', () async {
      when(() => mockDio.get('/tracks/t1/reposters'))
          .thenAnswer((_) async => successResponse({
                'data': {'users': []}
              }));

      await dataSource.getReposters('t1');

      verify(() => mockDio.get('/tracks/t1/reposters')).called(1);
    });

    test('parses users list from response', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => successResponse({
            'data': {
              'users': [
                fakeUserJson(
                    id: 'u3', displayName: 'Carol', permalink: 'carol'),
              ]
            }
          }));

      final reposters = await dataSource.getReposters('t1');

      expect(reposters.length, 1);
      expect(reposters.first.id, 'u3');
      expect(reposters.first.displayName, 'Carol');
      expect(reposters.first.permalink, 'carol');
    });

    test('returns empty list when users key is absent', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async =>
          successResponse(<String, dynamic>{'data': <String, dynamic>{}}));

      final reposters = await dataSource.getReposters('t1');

      expect(reposters, isEmpty);
    });
  });
}
