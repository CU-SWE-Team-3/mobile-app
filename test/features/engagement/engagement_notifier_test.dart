

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';

class MockEngagementRemoteDataSource extends Mock
    implements EngagementRemoteDataSource {}

void main() {
  late MockEngagementRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockEngagementRemoteDataSource();
  });

  EngagementNotifier buildNotifier({
    String trackId = 'track-1',
    bool isLiked = false,
    bool isReposted = false,
    int likeCount = 0,
    int repostCount = 0,
  }) {
    return EngagementNotifier(
      mockDataSource,
      trackId,
      initialIsLiked: isLiked,
      initialIsReposted: isReposted,
      initialLikeCount: likeCount,
      initialRepostCount: repostCount,
    );
  }

  // ── Initial state ────────────────────────────────────────────────────────

  group('initial state', () {
    test('reflects all constructor params', () {
      final notifier = buildNotifier(
        isLiked: true,
        isReposted: true,
        likeCount: 42,
        repostCount: 7,
      );

      expect(notifier.state.isLiked, isTrue);
      expect(notifier.state.isReposted, isTrue);
      expect(notifier.state.likeCount, 42);
      expect(notifier.state.repostCount, 7);
      expect(notifier.state.isLoadingLike, isFalse);
      expect(notifier.state.isLoadingRepost, isFalse);
    });

    test('defaults to unliked/unreposted with zero counts', () {
      final notifier = buildNotifier();

      expect(notifier.state.isLiked, isFalse);
      expect(notifier.state.isReposted, isFalse);
      expect(notifier.state.likeCount, 0);
      expect(notifier.state.repostCount, 0);
    });
  });

  // ── toggleLike ───────────────────────────────────────────────────────────

  group('toggleLike — success path', () {
    test('like: isLiked flips to true and count increments', () async {
      when(() => mockDataSource.likeTrack(any()))
          .thenAnswer((_) async {});

      final notifier = buildNotifier(isLiked: false, likeCount: 10);
      await notifier.toggleLike();

      expect(notifier.state.isLiked, isTrue);
      expect(notifier.state.likeCount, 11);
      expect(notifier.state.isLoadingLike, isFalse);
    });

    test('unlike: isLiked flips to false and count decrements', () async {
      when(() => mockDataSource.unlikeTrack(any()))
          .thenAnswer((_) async {});

      final notifier = buildNotifier(isLiked: true, likeCount: 10);
      await notifier.toggleLike();

      expect(notifier.state.isLiked, isFalse);
      expect(notifier.state.likeCount, 9);
      expect(notifier.state.isLoadingLike, isFalse);
    });

    test('isLoadingLike is true while request is in-flight', () async {
      final completer = Completer<void>();
      when(() => mockDataSource.likeTrack(any()))
          .thenAnswer((_) => completer.future);

      final notifier = buildNotifier(isLiked: false);
      final future = notifier.toggleLike();

      // Optimistic update applied synchronously before the first await
      expect(notifier.state.isLoadingLike, isTrue);

      completer.complete();
      await future;

      expect(notifier.state.isLoadingLike, isFalse);
    });

    test('calls likeTrack for a new like and unlikeTrack for un-like', () async {
      when(() => mockDataSource.likeTrack(any())).thenAnswer((_) async {});
      when(() => mockDataSource.unlikeTrack(any())).thenAnswer((_) async {});

      final likeNotifier = buildNotifier(trackId: 't1', isLiked: false);
      await likeNotifier.toggleLike();
      verify(() => mockDataSource.likeTrack('t1')).called(1);
      verifyNever(() => mockDataSource.unlikeTrack(any()));

      final unlikeNotifier = buildNotifier(trackId: 't2', isLiked: true);
      await unlikeNotifier.toggleLike();
      verify(() => mockDataSource.unlikeTrack('t2')).called(1);
    });
  });

  group('toggleLike — loading guard', () {
    test('second call while loading is a no-op (count increments only once)',
        () async {
      final completer = Completer<void>();
      when(() => mockDataSource.likeTrack(any()))
          .thenAnswer((_) => completer.future);

      final notifier = buildNotifier(isLiked: false, likeCount: 5);
      final first = notifier.toggleLike(); // starts, does not complete
      await notifier.toggleLike(); // should be ignored

      expect(notifier.state.likeCount, 6); // incremented only once
      expect(notifier.state.isLoadingLike, isTrue);

      completer.complete();
      await first;

      expect(notifier.state.likeCount, 6);
      expect(notifier.state.isLoadingLike, isFalse);
    });
  });

  group('toggleLike — failure rollback', () {
    test('rolls back optimistic state on network failure (no response)', () async {
      when(() => mockDataSource.likeTrack(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/tracks/track-1/like'),
          response: null, // no response = no server contact
        ),
      );

      final notifier = buildNotifier(isLiked: false, likeCount: 10);
      await notifier.toggleLike();

      expect(notifier.state.isLiked, isFalse);
      expect(notifier.state.likeCount, 10);
      expect(notifier.state.isLoadingLike, isFalse);
    });

    test('keeps optimistic state when server responded (e.g. 409 conflict)',
        () async {
      when(() => mockDataSource.likeTrack(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/tracks/track-1/like'),
          response: Response(
            requestOptions: RequestOptions(path: '/tracks/track-1/like'),
            statusCode: 409,
          ),
        ),
      );

      final notifier = buildNotifier(isLiked: false, likeCount: 10);
      await notifier.toggleLike();

      // Optimistic state is preserved — server did receive the request
      expect(notifier.state.isLiked, isTrue);
      expect(notifier.state.likeCount, 11);
      expect(notifier.state.isLoadingLike, isFalse);
    });
  });

  // ── toggleRepost ─────────────────────────────────────────────────────────

  group('toggleRepost — success path', () {
    test('repost: isReposted flips to true and count increments', () async {
      when(() => mockDataSource.repostTrack(any()))
          .thenAnswer((_) async {});

      final notifier = buildNotifier(isReposted: false, repostCount: 3);
      await notifier.toggleRepost();

      expect(notifier.state.isReposted, isTrue);
      expect(notifier.state.repostCount, 4);
      expect(notifier.state.isLoadingRepost, isFalse);
    });

    test('un-repost: isReposted flips to false and count decrements', () async {
      when(() => mockDataSource.unRepostTrack(any()))
          .thenAnswer((_) async {});

      final notifier = buildNotifier(isReposted: true, repostCount: 3);
      await notifier.toggleRepost();

      expect(notifier.state.isReposted, isFalse);
      expect(notifier.state.repostCount, 2);
      expect(notifier.state.isLoadingRepost, isFalse);
    });

    test('isLoadingRepost is true while request is in-flight', () async {
      final completer = Completer<void>();
      when(() => mockDataSource.repostTrack(any()))
          .thenAnswer((_) => completer.future);

      final notifier = buildNotifier(isReposted: false);
      final future = notifier.toggleRepost();

      expect(notifier.state.isLoadingRepost, isTrue);

      completer.complete();
      await future;

      expect(notifier.state.isLoadingRepost, isFalse);
    });

    test('calls repostTrack for new repost and unRepostTrack for un-repost',
        () async {
      when(() => mockDataSource.repostTrack(any())).thenAnswer((_) async {});
      when(() => mockDataSource.unRepostTrack(any())).thenAnswer((_) async {});

      final repostNotifier = buildNotifier(trackId: 't1', isReposted: false);
      await repostNotifier.toggleRepost();
      verify(() => mockDataSource.repostTrack('t1')).called(1);
      verifyNever(() => mockDataSource.unRepostTrack(any()));

      final unRepostNotifier = buildNotifier(trackId: 't2', isReposted: true);
      await unRepostNotifier.toggleRepost();
      verify(() => mockDataSource.unRepostTrack('t2')).called(1);
    });
  });

  group('toggleRepost — loading guard', () {
    test('second call while loading is a no-op (count increments only once)',
        () async {
      final completer = Completer<void>();
      when(() => mockDataSource.repostTrack(any()))
          .thenAnswer((_) => completer.future);

      final notifier = buildNotifier(isReposted: false, repostCount: 3);
      final first = notifier.toggleRepost();
      await notifier.toggleRepost(); // no-op

      expect(notifier.state.repostCount, 4);
      expect(notifier.state.isLoadingRepost, isTrue);

      completer.complete();
      await first;

      expect(notifier.state.repostCount, 4);
      expect(notifier.state.isLoadingRepost, isFalse);
    });
  });

  group('toggleRepost — failure rollback', () {
    test('rolls back on network failure (no response)', () async {
      when(() => mockDataSource.repostTrack(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/tracks/track-1/repost'),
          response: null,
        ),
      );

      final notifier = buildNotifier(isReposted: false, repostCount: 3);
      await notifier.toggleRepost();

      expect(notifier.state.isReposted, isFalse);
      expect(notifier.state.repostCount, 3);
      expect(notifier.state.isLoadingRepost, isFalse);
    });

    test('keeps optimistic state when server responded', () async {
      when(() => mockDataSource.repostTrack(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/tracks/track-1/repost'),
          response: Response(
            requestOptions: RequestOptions(path: '/tracks/track-1/repost'),
            statusCode: 400,
          ),
        ),
      );

      final notifier = buildNotifier(isReposted: false, repostCount: 3);
      await notifier.toggleRepost();

      expect(notifier.state.isReposted, isTrue);
      expect(notifier.state.repostCount, 4);
      expect(notifier.state.isLoadingRepost, isFalse);
    });
  });

  // ── seed() ───────────────────────────────────────────────────────────────

  group('seed()', () {
    test('updates state fields before any user interaction', () {
      final notifier = buildNotifier(isLiked: false, likeCount: 0);

      notifier.seed(isLiked: true, likeCount: 99, repostCount: 5);

      expect(notifier.state.isLiked, isTrue);
      expect(notifier.state.likeCount, 99);
      expect(notifier.state.repostCount, 5);
    });

    test('partial seed only updates supplied fields', () {
      final notifier = buildNotifier(isLiked: false, likeCount: 10, repostCount: 3);

      notifier.seed(likeCount: 20);

      expect(notifier.state.likeCount, 20);
      expect(notifier.state.repostCount, 3); // unchanged
      expect(notifier.state.isLiked, isFalse); // unchanged
    });

    test('is a no-op once the user has toggled (live state is not overwritten)',
        () async {
      when(() => mockDataSource.likeTrack(any())).thenAnswer((_) async {});

      final notifier = buildNotifier(isLiked: false, likeCount: 5);
      await notifier.toggleLike(); // user-toggled

      // Stale data arrives from another API response — must not overwrite
      notifier.seed(isLiked: false, likeCount: 0);

      expect(notifier.state.isLiked, isTrue);
      expect(notifier.state.likeCount, 6);
    });

    test('is a no-op after toggleRepost as well', () async {
      when(() => mockDataSource.repostTrack(any())).thenAnswer((_) async {});

      final notifier = buildNotifier(isReposted: false, repostCount: 2);
      await notifier.toggleRepost();

      notifier.seed(isReposted: false, repostCount: 0);

      expect(notifier.state.isReposted, isTrue);
      expect(notifier.state.repostCount, 3);
    });
  });

  // ── EngagementState.copyWith ─────────────────────────────────────────────

  group('EngagementState.copyWith', () {
    test('unspecified fields are preserved', () {
      const original = EngagementState(
        isLiked: true,
        isReposted: false,
        likeCount: 5,
        repostCount: 2,
      );

      final updated = original.copyWith(likeCount: 10);

      expect(updated.isLiked, isTrue);
      expect(updated.isReposted, isFalse);
      expect(updated.likeCount, 10);
      expect(updated.repostCount, 2);
    });
  });
}
