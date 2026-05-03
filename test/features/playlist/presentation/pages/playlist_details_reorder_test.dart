// Widget tests for PlaylistDetailsPage — reorder and remove track features.
//
// Strategy for HTTP: the page calls dioClient.dio.get('/playlists/{id}')
// directly (no repository). We swap dioClient.dio.httpClientAdapter in setUp
// so the page receives a controlled list of tracks without hitting the network.
//
// Repository calls for reorder/remove are intercepted via
// playlistRepositoryProvider override (mocktail).
//
// Drag note: ReorderableDragStartListener uses ImmediateMultiDragGestureRecognizer;
// a kPressTimeout pump is required after startGesture for the recognizer to
// win the gesture arena and begin the drag proxy.
//
// Run with:
//   flutter test test/features/playlist/presentation/pages/playlist_details_reorder_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/services/audio_handler_service.dart';
import 'package:soundcloud_clone/core/providers/session_provider.dart';
import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';
import 'package:soundcloud_clone/features/playlist/data/repositories/playlist_repository.dart';
import 'package:soundcloud_clone/features/playlist/domain/entities/playlist.dart';
import 'package:soundcloud_clone/features/playlist/presentation/pages/playlist_details_page.dart';
import 'package:soundcloud_clone/features/playlist/presentation/providers/playlists_provider.dart';
import 'package:soundcloud_clone/features/station/data/datasources/station_remote_data_source.dart';
import 'package:soundcloud_clone/injection_container.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockPlaylistRepository extends Mock implements PlaylistRepository {}

class MockEngagementRemoteDataSource extends Mock
    implements EngagementRemoteDataSource {}

class MockStationRemoteDataSource extends Mock
    implements StationRemoteDataSource {}

// ── Mock HTTP adapter ─────────────────────────────────────────────────────────

/// Replaces dioClient.dio.httpClientAdapter in tests so _loadTracks resolves
/// without hitting the real API.
class _MockHttpAdapter implements HttpClientAdapter {
  dynamic responseData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _tracks3 = [
  {
    '_id': 'track-1',
    'title': 'Song A',
    'artist': {'displayName': 'Artist A'},
    'playCount': 100,
    'duration': 180,
  },
  {
    '_id': 'track-2',
    'title': 'Song B',
    'artist': {'displayName': 'Artist B'},
    'playCount': 200,
    'duration': 240,
  },
  {
    '_id': 'track-3',
    'title': 'Song C',
    'artist': {'displayName': 'Artist C'},
    'playCount': 300,
    'duration': 200,
  },
];

final _testPlaylist = Playlist(
  id: 'playlist-1',
  title: 'Test Playlist',
  ownerName: 'DJ Test',
  isPublic: true,
  trackCount: 3,
  firstTrackArtworkUrl: 'https://example.com/first.jpg',
);

// ── Finders ───────────────────────────────────────────────────────────────────

/// Finds more-horiz icons on track tiles only (size == 22).
/// The action row also has a more-horiz icon at size 20.
Finder _trackMoreIcon() => find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.more_horiz_rounded && w.size == 22,
    );

// ── Helper ────────────────────────────────────────────────────────────────────

Future<ProviderContainer> _pumpDetailsPage(
  WidgetTester tester,
  MockPlaylistRepository mockRepo, {
  List<Map<String, dynamic>> tracks = _tracks3,
}) async {
  tester.view.physicalSize = const Size(414, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'playlists_data': jsonEncode([_testPlaylist.toJson()]),
  });
  when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});
  if (!sl.isRegistered<EngagementRemoteDataSource>()) {
    sl.registerLazySingleton<EngagementRemoteDataSource>(
      MockEngagementRemoteDataSource.new,
    );
  }
  if (!sl.isRegistered<StationRemoteDataSource>()) {
    final stationSource = MockStationRemoteDataSource();
    when(() => stationSource.isStationLiked(any()))
        .thenAnswer((_) async => false);
    sl.registerLazySingleton<StationRemoteDataSource>(() => stationSource);
  }

  // Swap the Dio adapter so _loadTracks returns our fixture data.
  final mockAdapter = _MockHttpAdapter()
    ..responseData = {
      'data': {
        'playlist': {
          '_id': 'playlist-1',
          'title': 'Test Playlist',
          'isPublic': true,
          'tracks': tracks,
        },
      },
    };
  final originalAdapter = dioClient.dio.httpClientAdapter;
  dioClient.dio.httpClientAdapter = mockAdapter;
  addTearDown(() => dioClient.dio.httpClientAdapter = originalAdapter);

  appAudioHandler ??= AppAudioHandler();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(mockRepo),
        sessionUserIdProvider.overrideWith((ref) => 'user-1'),
      ],
      child: MaterialApp(
        home: PlaylistDetailsPage(playlist: _testPlaylist),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(PlaylistDetailsPage)),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockPlaylistRepository mockRepo;

  setUp(() {
    mockRepo = MockPlaylistRepository();
  });

  // ── Rendering ─────────────────────────────────────────────────────────────

  group('PlaylistDetailsPage — track list rendering', () {
    testWidgets('renders all three tracks after load', (tester) async {
      await _pumpDetailsPage(tester, mockRepo);

      expect(find.text('Song A'), findsOneWidget);
      expect(find.text('Song B'), findsOneWidget);
      expect(find.text('Song C'), findsOneWidget);
    });

    testWidgets('shows drag handles when list has more than one track',
        (tester) async {
      await _pumpDetailsPage(tester, mockRepo);

      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    });

    testWidgets('hides drag handles when list has exactly one track',
        (tester) async {
      await _pumpDetailsPage(tester, mockRepo, tracks: [_tracks3.first]);

      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('shows more-horiz icon on each track tile (3 tiles = 3 icons)',
        (tester) async {
      await _pumpDetailsPage(tester, mockRepo);

      // Action row also has one more_horiz icon (size 20); track tiles use size 22.
      expect(_trackMoreIcon(), findsNWidgets(3));
    });
  });

  // ── Remove — action sheet ──────────────────────────────────────────────────

  group('PlaylistDetailsPage — track action sheet', () {
    testWidgets('tapping track more icon opens sheet with Remove option',
        (tester) async {
      await _pumpDetailsPage(tester, mockRepo);

      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();

      expect(find.text('Remove from playlist'), findsOneWidget);
    });

    testWidgets('action sheet does not open while operation is in flight',
        (tester) async {
      // Use a Completer so the remove stays in-flight for the duration of the test.
      final completer = Completer<int>();
      when(() => mockRepo.removeTrack(any(), any()))
          .thenAnswer((_) => completer.future);

      await _pumpDetailsPage(tester, mockRepo);

      // Open sheet and tap Remove.
      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      // pumpAndSettle lets the sheet close animation finish while the Completer
      // keeps _isOperationInFlight = true (the future never resolves here).
      await tester.pumpAndSettle();

      // While locked, tapping more icon should be a no-op (onMoreTap is null)
      await tester.tap(_trackMoreIcon().first, warnIfMissed: false);
      await tester.pump();

      expect(find.text('Remove from playlist'), findsNothing);

      // Resolve the pending future so the test leaves no dangling microtasks.
      completer.complete(2);
      await tester.pumpAndSettle();
    });
  });

  // ── Remove — success path ──────────────────────────────────────────────────

  group('PlaylistDetailsPage — remove track success', () {
    testWidgets('removes track from list optimistically', (tester) async {
      when(() => mockRepo.removeTrack(any(), any()))
          .thenAnswer((_) async => 2);

      await _pumpDetailsPage(tester, mockRepo);

      expect(find.text('Song A'), findsOneWidget);

      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Song A'), findsNothing);
    });

    testWidgets('calls repository.removeTrack with correct ids', (tester) async {
      when(() => mockRepo.removeTrack(any(), any()))
          .thenAnswer((_) async => 2);

      await _pumpDetailsPage(tester, mockRepo);

      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.removeTrack('playlist-1', 'track-1')).called(1);
    });

    testWidgets('updates track count in playlistsProvider after removal',
        (tester) async {
      when(() => mockRepo.removeTrack(any(), any()))
          .thenAnswer((_) async => 2);

      final container = await _pumpDetailsPage(tester, mockRepo);

      // Seed the provider with the test playlist so updateTrackCount has a
      // target entry to mutate.
      await container.read(playlistsProvider.notifier).add(_testPlaylist);

      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      final updated = container
          .read(playlistsProvider)
          .firstWhere((p) => p.id == 'playlist-1');
      expect(updated.trackCount, 2);
    });
  });

  // ── Remove — failure path ──────────────────────────────────────────────────

  group('PlaylistDetailsPage — remove track failure', () {
    testWidgets('reverts track when repository throws', (tester) async {
      when(() => mockRepo.removeTrack(any(), any()))
          .thenThrow(Exception('network error'));

      await _pumpDetailsPage(tester, mockRepo);

      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      // Song A should still be in the list after revert
      expect(find.text('Song A'), findsOneWidget);
    });

    testWidgets('shows error snackbar when repository throws', (tester) async {
      when(() => mockRepo.removeTrack(any(), any()))
          .thenThrow(Exception('network error'));

      await _pumpDetailsPage(tester, mockRepo);

      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to remove track. Please try again.'),
          findsOneWidget);
    });

    testWidgets('re-enables more icon after failure', (tester) async {
      when(() => mockRepo.removeTrack(any(), any()))
          .thenThrow(Exception('network error'));

      await _pumpDetailsPage(tester, mockRepo);

      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      // Should be able to open the sheet again after failure clears the lock
      await tester.tap(_trackMoreIcon().first);
      await tester.pumpAndSettle();

      expect(find.text('Remove from playlist'), findsOneWidget);
    });
  });

  // ── Reorder — drag ────────────────────────────────────────────────────────

  group('PlaylistDetailsPage — reorder tracks', () {
    testWidgets('dragging first track past second calls reorderTracks',
        (tester) async {
      when(() => mockRepo.reorderTracks(any(), any())).thenAnswer((_) async {});

      await _pumpDetailsPage(tester, mockRepo);

      final firstHandle = find.byIcon(Icons.drag_handle).first;

      // ImmediateMultiDragGestureRecognizer starts on pointer-down, but a
      // kPressTimeout pump lets it win the gesture arena before we move.
      final gesture = await tester.startGesture(
        tester.getCenter(firstHandle),
      );
      await tester.pump(kPressTimeout);

      // Move to just past Song B's centre so the reorder fires.
      await gesture.moveTo(
        tester.getCenter(find.text('Song B')) + const Offset(0, 1),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      verify(() => mockRepo.reorderTracks('playlist-1', any())).called(1);
    });

    testWidgets(
        'reverts order and shows error snackbar when reorderTracks throws',
        (tester) async {
      when(() => mockRepo.reorderTracks(any(), any()))
          .thenThrow(Exception('network error'));

      await _pumpDetailsPage(tester, mockRepo);

      final firstHandle = find.byIcon(Icons.drag_handle).first;

      final gesture = await tester.startGesture(
        tester.getCenter(firstHandle),
      );
      await tester.pump(kPressTimeout);
      await gesture.moveTo(
        tester.getCenter(find.text('Song B')) + const Offset(0, 1),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Failed to reorder tracks. Please try again.'),
          findsOneWidget);
    });
  });
}
