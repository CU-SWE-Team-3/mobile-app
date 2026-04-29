// Widget tests for CreatePlaylistPage.
//
// Verifies that:
//   1. Tapping Save calls repository.create with the typed title and isPublic flag.
//   2. A loading indicator is shown while the network call is in flight.
//   3. An error message appears (without popping) when the repository throws.
//
// Run with:
//   flutter test test/features/playlist/presentation/pages/create_playlist_page_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/features/playlist/data/repositories/playlist_repository.dart';
import 'package:soundcloud_clone/features/playlist/presentation/pages/create_playlist_page.dart';
import 'package:soundcloud_clone/features/playlist/presentation/providers/playlists_provider.dart';

class _MockPlaylistRepository extends Mock implements PlaylistRepository {}

// Builds the widget under test with provider overrides.
Widget _buildPage(_MockPlaylistRepository mockRepo) {
  return ProviderScope(
    overrides: [
      playlistRepositoryProvider.overrideWithValue(mockRepo),
      playlistsProvider.overrideWith(
        (ref) => PlaylistNotifier(mockRepo),
      ),
    ],
    child: const MaterialApp(home: CreatePlaylistPage()),
  );
}

void main() {
  late _MockPlaylistRepository mockRepo;

  setUp(() {
    mockRepo = _MockPlaylistRepository();
    SharedPreferences.setMockInitialValues({'displayName': 'Test User'});
    // fetchById is called by _backfillArtwork; stub so it never throws.
    when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});
  });

  testWidgets('tapping Save calls repository.create with the correct args',
      (tester) async {
    when(() => mockRepo.create(any(), any()))
        .thenAnswer((_) async => 'server-id-123');

    await tester.pumpWidget(_buildPage(mockRepo));
    await tester.pumpAndSettle();

    // Replace default text with a custom title.
    await tester.enterText(find.byType(TextField), 'Chill Vibes');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.create('Chill Vibes', true)).called(1);
  });

  testWidgets('falls back to Untitled Playlist when title is blank',
      (tester) async {
    when(() => mockRepo.create(any(), any()))
        .thenAnswer((_) async => 'server-id-123');

    await tester.pumpWidget(_buildPage(mockRepo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.create('Untitled Playlist', true)).called(1);
  });

  testWidgets('loading indicator is shown while repository.create is in flight',
      (tester) async {
    final completer = Completer<String>();
    when(() => mockRepo.create(any(), any()))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_buildPage(mockRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump(); // one frame — _saving = true, CircularProgressIndicator renders

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Save button text gone while loading.
    expect(find.text('Save'), findsNothing);

    // Complete the future so the widget can finish.
    completer.complete('server-id-123');
    await tester.pumpAndSettle();
  });

  testWidgets('error message shown without popping when repository throws',
      (tester) async {
    when(() => mockRepo.create(any(), any()))
        .thenThrow(Exception('network error'));

    await tester.pumpWidget(_buildPage(mockRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Error text appears.
    expect(
      find.text('Could not create playlist. Please try again.'),
      findsOneWidget,
    );
    // Page is still present — was not popped.
    expect(find.byType(CreatePlaylistPage), findsOneWidget);
    // Save button is back (loading stopped).
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('respects isPublic switch value when calling create',
      (tester) async {
    when(() => mockRepo.create(any(), any()))
        .thenAnswer((_) async => 'server-id-123');

    await tester.pumpWidget(_buildPage(mockRepo));
    await tester.pumpAndSettle();

    // Toggle the switch to private (isPublic = false).
    await tester.tap(find.byType(Switch));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.create(any(), false)).called(1);
  });
}
