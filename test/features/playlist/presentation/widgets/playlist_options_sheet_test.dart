// Widget tests for PlaylistOptionsSheet.
//
// Pumps the sheet inside a ProviderScope with a mocked PlaylistRepository so
// all network calls are intercepted. Uses showModalBottomSheet so that
// Navigator.pop() inside action handlers closes the sheet correctly (as it
// would in production) rather than trying to pop the root route.
//
// Run with:
//   flutter test test/features/playlist/presentation/widgets/playlist_options_sheet_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/features/playlist/data/repositories/playlist_repository.dart';
import 'package:soundcloud_clone/features/playlist/domain/entities/playlist.dart';
import 'package:soundcloud_clone/features/playlist/presentation/providers/playlists_provider.dart';
import 'package:soundcloud_clone/features/playlist/presentation/widgets/playlist_options_sheet.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockPlaylistRepository extends Mock implements PlaylistRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

final _testPlaylist = Playlist(
  id: 'test-id',
  title: 'My Playlist',
  ownerName: 'Test User',
  isPublic: true,
);

/// Pumps the app with a button that opens [PlaylistOptionsSheet] as a modal
/// bottom sheet. The ProviderScope overrides [playlistRepositoryProvider] so
/// [PlaylistNotifier] uses [mockRepo] for all network calls.
Future<void> _pumpSheet(
  WidgetTester tester,
  MockPlaylistRepository mockRepo, {
  Playlist? playlist,
  bool showCopyOption = false,
  bool popPageOnDelete = false,
}) async {
  // Use a tall viewport so the sheet's Column fits without overflow.
  tester.view.physicalSize = const Size(414, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});

  final p = playlist ?? _testPlaylist;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet(
                context: ctx,
                builder: (_) => PlaylistOptionsSheet(
                  playlist: p,
                  showCopyOption: showCopyOption,
                  popPageOnDelete: popPageOnDelete,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockPlaylistRepository mockRepo;

  setUp(() {
    mockRepo = MockPlaylistRepository();
  });

  // ── Rendering ─────────────────────────────────────────────────────────────

  group('PlaylistOptionsSheet — rendering', () {
    testWidgets('shows title and owner in the header', (tester) async {
      await _pumpSheet(tester, mockRepo);

      expect(find.text('My Playlist'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('renders Edit, Make private, Delete, Share rows', (tester) async {
      await _pumpSheet(tester, mockRepo);

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Make private'), findsOneWidget); // isPublic: true
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('does not show Copy playlist by default', (tester) async {
      await _pumpSheet(tester, mockRepo);

      expect(find.text('Copy playlist'), findsNothing);
    });

    testWidgets('shows Copy playlist when showCopyOption is true', (tester) async {
      await _pumpSheet(tester, mockRepo, showCopyOption: true);

      expect(find.text('Copy playlist'), findsOneWidget);
    });

    testWidgets('shows Make public when playlist is private', (tester) async {
      final privatePlaylist = Playlist(
        id: 'p2',
        title: 'Private',
        ownerName: 'User',
        isPublic: false,
      );
      await _pumpSheet(tester, mockRepo, playlist: privatePlaylist);

      expect(find.text('Make public'), findsOneWidget);
      expect(find.text('Make private'), findsNothing);
    });
  });

  // ── Edit action ───────────────────────────────────────────────────────────

  group('PlaylistOptionsSheet — Edit', () {
    testWidgets('shows Coming soon snackbar and closes the sheet', (tester) async {
      await _pumpSheet(tester, mockRepo);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Coming soon'), findsOneWidget);
      // Sheet is dismissed
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('does not call any repository method', (tester) async {
      await _pumpSheet(tester, mockRepo);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepo.updatePrivacy(any(), any()));
      verifyNever(() => mockRepo.deletePlaylist(any()));
    });
  });

  // ── Make private / Make public ────────────────────────────────────────────

  group('PlaylistOptionsSheet — Make private/public', () {
    testWidgets('tapping Make private calls repository.updatePrivacy with false',
        (tester) async {
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});

      await _pumpSheet(tester, mockRepo); // playlist.isPublic = true

      await tester.tap(find.text('Make private'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updatePrivacy('test-id', false)).called(1);
    });

    testWidgets('tapping Make public calls repository.updatePrivacy with true',
        (tester) async {
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});
      final privatePlaylist = Playlist(
        id: 'test-id',
        title: 'Test',
        ownerName: 'User',
        isPublic: false,
      );

      await _pumpSheet(tester, mockRepo, playlist: privatePlaylist);

      await tester.tap(find.text('Make public'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updatePrivacy('test-id', true)).called(1);
    });

    testWidgets('shows success snackbar after toggling privacy', (tester) async {
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});

      await _pumpSheet(tester, mockRepo);

      await tester.tap(find.text('Make private'));
      await tester.pumpAndSettle();

      expect(find.text('Playlist is now private'), findsOneWidget);
    });

    testWidgets('shows error snackbar when repository throws', (tester) async {
      when(() => mockRepo.updatePrivacy(any(), any()))
          .thenThrow(Exception('network error'));

      await _pumpSheet(tester, mockRepo);

      await tester.tap(find.text('Make private'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to update playlist privacy'), findsOneWidget);
    });
  });

  // ── Delete action ─────────────────────────────────────────────────────────

  group('PlaylistOptionsSheet — Delete', () {
    testWidgets('calls repository.deletePlaylist with the playlist id',
        (tester) async {
      when(() => mockRepo.deletePlaylist(any())).thenAnswer((_) async {});

      await _pumpSheet(tester, mockRepo);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.deletePlaylist('test-id')).called(1);
    });

    testWidgets('shows Playlist deleted snackbar when popPageOnDelete is false',
        (tester) async {
      when(() => mockRepo.deletePlaylist(any())).thenAnswer((_) async {});

      await _pumpSheet(tester, mockRepo, popPageOnDelete: false);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Playlist deleted'), findsOneWidget);
    });

    testWidgets('shows error snackbar when delete fails', (tester) async {
      when(() => mockRepo.deletePlaylist(any()))
          .thenThrow(Exception('network error'));

      await _pumpSheet(tester, mockRepo);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete playlist. Please try again.'),
        findsOneWidget,
      );
    });
  });

  // ── Copy playlist action ──────────────────────────────────────────────────

  group('PlaylistOptionsSheet — Copy playlist', () {
    testWidgets('shows Coming soon snackbar and closes the sheet', (tester) async {
      await _pumpSheet(tester, mockRepo, showCopyOption: true);

      await tester.tap(find.text('Copy playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Copy playlist'), findsNothing);
    });

    testWidgets('does not call any repository method', (tester) async {
      await _pumpSheet(tester, mockRepo, showCopyOption: true);

      await tester.tap(find.text('Copy playlist'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepo.updatePrivacy(any(), any()));
      verifyNever(() => mockRepo.deletePlaylist(any()));
    });
  });
}
