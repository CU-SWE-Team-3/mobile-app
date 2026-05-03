// Widget tests for EditPlaylistPage.
//
// Covers: prefill, Save button enable/disable, repository call args, error
// banner on failure, pop on success, and provider state update after save.
//
// Run with:
//   flutter test test/features/playlist/presentation/pages/edit_playlist_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/features/playlist/data/repositories/playlist_repository.dart';
import 'package:soundcloud_clone/features/playlist/domain/entities/playlist.dart';
import 'package:soundcloud_clone/features/playlist/presentation/pages/edit_playlist_page.dart';
import 'package:soundcloud_clone/features/playlist/presentation/providers/playlists_provider.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockPlaylistRepository extends Mock implements PlaylistRepository {}

// ── Fixtures ─────────────────────────────────────────────────────────────────

final _publicPlaylist = Playlist(
  id: 'p1',
  title: 'My Playlist',
  ownerName: 'Alice',
  isPublic: true,
);

final _privatePlaylist = Playlist(
  id: 'p2',
  title: 'Secret Set',
  ownerName: 'Alice',
  isPublic: false,
);

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Pumps EditPlaylistPage inside a ProviderScope backed by [mockRepo].
/// Returns the WidgetRef so callers can inspect provider state after save.
Future<WidgetRef> _pumpEditPage(
  WidgetTester tester,
  MockPlaylistRepository mockRepo, {
  Playlist? playlist,
  bool withParentRoute = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});

  late WidgetRef capturedRef;
  final p = playlist ?? _publicPlaylist;

  Widget pageWidget = Consumer(
    builder: (_, ref, __) {
      capturedRef = ref;
      return EditPlaylistPage(playlist: p);
    },
  );

  Widget root;
  if (withParentRoute) {
    // Wrap in a parent page so we can verify that a successful save pops back.
    root = MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => pageWidget),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  } else {
    root = MaterialApp(home: pageWidget);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [playlistRepositoryProvider.overrideWithValue(mockRepo)],
      child: root,
    ),
  );

  if (withParentRoute) {
    await tester.tap(find.text('open'));
  }
  await tester.pumpAndSettle();
  return capturedRef;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockPlaylistRepository mockRepo;

  setUp(() {
    mockRepo = MockPlaylistRepository();
  });

  // ── Rendering / prefill ───────────────────────────────────────────────────

  group('EditPlaylistPage — prefill', () {
    testWidgets('title field is prefilled with playlist title', (tester) async {
      await _pumpEditPage(tester, mockRepo);

      final titleField = tester.widget<TextField>(find.byKey(const Key('titleField')));
      expect(titleField.controller!.text, 'My Playlist');
    });

    testWidgets('privacy shows Public for a public playlist', (tester) async {
      await _pumpEditPage(tester, mockRepo);

      expect(find.text('Public'), findsOneWidget);
    });

    testWidgets('privacy shows Private for a private playlist', (tester) async {
      await _pumpEditPage(tester, mockRepo, playlist: _privatePlaylist);

      expect(find.text('Private'), findsOneWidget);
    });

    testWidgets('description field is empty (no description on entity)',
        (tester) async {
      await _pumpEditPage(tester, mockRepo);

      final descField =
          tester.widget<TextField>(find.byKey(const Key('descField')));
      expect(descField.controller!.text, '');
    });

    testWidgets('shows Playlist not found when playlist is null', (tester) async {
      SharedPreferences.setMockInitialValues({});
      when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playlistRepositoryProvider.overrideWithValue(mockRepo)],
          child: const MaterialApp(home: EditPlaylistPage(playlist: null)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playlist not found'), findsOneWidget);
    });
  });

  // ── Save button enable/disable ────────────────────────────────────────────

  group('EditPlaylistPage — Save button state', () {
    testWidgets('Save is enabled when title is non-empty', (tester) async {
      await _pumpEditPage(tester, mockRepo);

      final btn = tester.widget<TextButton>(find.byKey(const Key('saveButton')));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Save is disabled when title is cleared', (tester) async {
      await _pumpEditPage(tester, mockRepo);

      await tester.enterText(find.byKey(const Key('titleField')), '');
      await tester.pump();

      final btn = tester.widget<TextButton>(find.byKey(const Key('saveButton')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('Save is disabled when title exceeds 100 characters', (tester) async {
      await _pumpEditPage(tester, mockRepo);

      await tester.enterText(find.byKey(const Key('titleField')), 'a' * 101);
      await tester.pump();

      final btn = tester.widget<TextButton>(find.byKey(const Key('saveButton')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('Save is disabled when description exceeds 1000 characters',
        (tester) async {
      await _pumpEditPage(tester, mockRepo);

      await tester.enterText(find.byKey(const Key('descField')), 'x' * 1001);
      await tester.pump();

      final btn = tester.widget<TextButton>(find.byKey(const Key('saveButton')));
      expect(btn.onPressed, isNull);
    });
  });

  // ── Save — repository calls ───────────────────────────────────────────────

  group('EditPlaylistPage — Save repository calls', () {
    testWidgets('calls updateMetadata with the updated title on save',
        (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenAnswer((_) async {});
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {
        return null;
      });

      await _pumpEditPage(tester, mockRepo);

      await tester.enterText(
          find.byKey(const Key('titleField')), 'Renamed Playlist');
      await tester.pump();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updateMetadata('p1', title: 'Renamed Playlist'))
          .called(1);
    });

    testWidgets('calls updatePrivacy with false when playlist is made private',
        (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenAnswer((_) async {});
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {
        return null;
      });

      await _pumpEditPage(tester, mockRepo); // isPublic: true

      // Toggle privacy switch to private
      await tester.tap(find.byType(Switch));
      await tester.pump();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updatePrivacy('p1', false)).called(1);
    });

    testWidgets('calls updatePrivacy with true when playlist is made public',
        (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenAnswer((_) async {});
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {
        return null;
      });

      await _pumpEditPage(tester, mockRepo, playlist: _privatePlaylist);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updatePrivacy('p2', true)).called(1);
    });
  });

  // ── Save — success path ───────────────────────────────────────────────────

  group('EditPlaylistPage — Save success', () {
    testWidgets('pops back to the parent route after successful save',
        (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenAnswer((_) async {});
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {
        return null;
      });

      await _pumpEditPage(tester, mockRepo, withParentRoute: true);

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      // Back on the parent route — Edit Playlist AppBar is gone
      expect(find.text('Edit Playlist'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('updates provider title in local state after successful save',
        (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenAnswer((_) async {});
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {
        return null;
      });
      SharedPreferences.setMockInitialValues({});
      when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});

      // Use a ProviderContainer that outlives the page so we can read state
      // after Navigator.pop disposes the Consumer widget.
      final container = ProviderContainer(
        overrides: [playlistRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      // Seed the provider before pumping the widget tree.
      await container.read(playlistsProvider.notifier).add(_publicPlaylist);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditPlaylistPage(playlist: _publicPlaylist),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('titleField')), 'Saved Title');
      await tester.pump();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      // Container is still alive — read provider state after the page popped.
      final updated =
          container.read(playlistsProvider).firstWhere((p) => p.id == 'p1');
      expect(updated.title, 'Saved Title');
    });
  });

  // ── Save — failure path ───────────────────────────────────────────────────

  group('EditPlaylistPage — Save failure', () {
    testWidgets('shows error banner when repository throws', (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenThrow(Exception('network error'));

      await _pumpEditPage(tester, mockRepo, withParentRoute: true);

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      expect(find.text('Failed to save changes. Please try again.'),
          findsOneWidget);
    });

    testWidgets('does not pop when repository throws', (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenThrow(Exception('network error'));

      await _pumpEditPage(tester, mockRepo, withParentRoute: true);

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      // Still on the edit page
      expect(find.text('Edit Playlist'), findsOneWidget);
    });

    testWidgets('re-enables Save button after failure so user can retry',
        (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenThrow(Exception('network error'));

      await _pumpEditPage(tester, mockRepo);

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      final btn =
          tester.widget<TextButton>(find.byKey(const Key('saveButton')));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('error banner can be dismissed', (tester) async {
      when(() => mockRepo.updateMetadata(any(), title: any(named: 'title')))
          .thenThrow(Exception('network error'));

      await _pumpEditPage(tester, mockRepo);

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dismiss'));
      await tester.pump();

      expect(find.text('Failed to save changes. Please try again.'),
          findsNothing);
    });
  });
}
