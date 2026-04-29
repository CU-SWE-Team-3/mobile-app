// Widget tests for PlaylistPrivacyPage.
//
// Verifies that:
//   1. The Switch is pre-filled from the passed Playlist.isPublic value.
//   2. Toggling the Switch calls repository.updatePrivacy with correct args.
//   3. The private-link section is visible iff the playlist is private.
//   4. The "Copy private link" button writes the URL to the clipboard.
//
// Run with:
//   flutter test test/features/playlist/presentation/pages/playlist_privacy_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/features/playlist/data/repositories/playlist_repository.dart';
import 'package:soundcloud_clone/features/playlist/domain/entities/playlist.dart';
import 'package:soundcloud_clone/features/playlist/presentation/pages/playlist_privacy_page.dart';
import 'package:soundcloud_clone/features/playlist/presentation/providers/playlists_provider.dart';

class _MockPlaylistRepository extends Mock implements PlaylistRepository {}

Playlist _publicPlaylist() => Playlist(
      id: 'p1',
      title: 'Morning Beats',
      ownerName: 'Kareem',
      isPublic: true,
    );

Playlist _privatePlaylist() => Playlist(
      id: 'p2',
      title: 'Secret Set',
      ownerName: 'Kareem',
      isPublic: false,
      secretToken: 'tok-abc123',
      ownerPermalink: 'kareem',
      permalink: 'secret-set',
    );

Widget _buildPage(_MockPlaylistRepository mockRepo, Playlist playlist) {
  return ProviderScope(
    overrides: [
      playlistRepositoryProvider.overrideWithValue(mockRepo),
      playlistsProvider.overrideWith((ref) => PlaylistNotifier(mockRepo)),
    ],
    child: MaterialApp(home: PlaylistPrivacyPage(playlist: playlist)),
  );
}

void main() {
  late _MockPlaylistRepository mockRepo;

  setUp(() {
    mockRepo = _MockPlaylistRepository();
    SharedPreferences.setMockInitialValues({});
    when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});
  });

  // ── Pre-filled state ─────────────────────────────────────────────────────────

  testWidgets('Switch is ON when playlist is public', (tester) async {
    await tester.pumpWidget(_buildPage(mockRepo, _publicPlaylist()));
    await tester.pumpAndSettle();

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isTrue);
  });

  testWidgets('Switch is OFF when playlist is private', (tester) async {
    when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(_buildPage(mockRepo, _privatePlaylist()));
    await tester.pumpAndSettle();

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isFalse);
  });

  // ── Toggle calls repository ──────────────────────────────────────────────────

  testWidgets('toggling Switch calls repository.updatePrivacy with correct args',
      (tester) async {
    when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(_buildPage(mockRepo, _publicPlaylist()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Toggled public → private (isPublic = false).
    verify(() => mockRepo.updatePrivacy('p1', false)).called(1);
  });

  // ── Private-link section visibility ─────────────────────────────────────────

  testWidgets('private-link section hidden when playlist is public',
      (tester) async {
    await tester.pumpWidget(_buildPage(mockRepo, _publicPlaylist()));
    await tester.pumpAndSettle();

    expect(find.text('PRIVATE LINK'), findsNothing);
    expect(find.text('Copy private link'), findsNothing);
  });

  testWidgets('private-link section visible when playlist is private',
      (tester) async {
    when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(_buildPage(mockRepo, _privatePlaylist()));
    await tester.pumpAndSettle();

    expect(find.text('PRIVATE LINK'), findsOneWidget);
    expect(find.text('Copy private link'), findsOneWidget);
  });

  testWidgets('private-link section appears after toggling public → private',
      (tester) async {
    when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(_buildPage(mockRepo, _publicPlaylist()));
    await tester.pumpAndSettle();

    expect(find.text('PRIVATE LINK'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('PRIVATE LINK'), findsOneWidget);
  });

  testWidgets('private-link section hidden after toggling private → public',
      (tester) async {
    when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(_buildPage(mockRepo, _privatePlaylist()));
    await tester.pumpAndSettle();

    expect(find.text('PRIVATE LINK'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('PRIVATE LINK'), findsNothing);
  });

  // ── Copy button ──────────────────────────────────────────────────────────────

  testWidgets('Copy private link button writes the secret-token URL to the clipboard',
      (tester) async {
    when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {});

    // Intercept Clipboard.setData at the platform channel level.
    // This avoids calling Clipboard.getData (which hangs due to the SnackBar
    // animation keeping pumpAndSettle from ever settling).
    String? capturedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        capturedText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(_buildPage(mockRepo, _privatePlaylist()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy private link'));
    await tester.pump(); // allow the platform-channel call to complete

    expect(capturedText, isNotNull);
    expect(capturedText, contains('secret-set'));
    expect(capturedText, contains('tok-abc123'));

    // Restore the default handler.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // ── Error state ──────────────────────────────────────────────────────────────

  testWidgets('error message shown when updatePrivacy throws', (tester) async {
    when(() => mockRepo.updatePrivacy(any(), any()))
        .thenThrow(Exception('network error'));

    await tester.pumpWidget(_buildPage(mockRepo, _publicPlaylist()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to update privacy. Please try again.'),
      findsOneWidget,
    );
    // Toggle was not committed — Switch should still reflect original value.
    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isTrue);
  });
}
