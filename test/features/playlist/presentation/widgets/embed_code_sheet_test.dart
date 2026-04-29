// Widget tests for EmbedCodeSheet.
//
// Verifies that:
//   1. A loading indicator is shown while the embed code is being fetched.
//   2. The embed code is displayed after a successful fetch.
//   3. The "Copy embed code" button writes the code to the clipboard.
//   4. An error message and retry button appear when the fetch fails.
//   5. Tapping "Try again" retries the fetch.
//
// Run with:
//   flutter test test/features/playlist/presentation/widgets/embed_code_sheet_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/features/playlist/data/repositories/playlist_repository.dart';
import 'package:soundcloud_clone/features/playlist/presentation/providers/playlists_provider.dart';
import 'package:soundcloud_clone/features/playlist/presentation/widgets/embed_code_sheet.dart';

class _MockPlaylistRepository extends Mock implements PlaylistRepository {}

Widget _buildSheet(_MockPlaylistRepository mockRepo, String playlistId) {
  return ProviderScope(
    overrides: [
      playlistRepositoryProvider.overrideWithValue(mockRepo),
    ],
    child: MaterialApp(
      home: Scaffold(body: EmbedCodeSheet(playlistId: playlistId)),
    ),
  );
}

void main() {
  late _MockPlaylistRepository mockRepo;

  setUp(() {
    mockRepo = _MockPlaylistRepository();
    SharedPreferences.setMockInitialValues({});
    when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});
  });

  // ── Loading state ─────────────────────────────────────────────────────────

  testWidgets('shows loading indicator while fetching embed code', (tester) async {
    final completer = Completer<String>();
    when(() => mockRepo.getEmbedCode(any()))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_buildSheet(mockRepo, 'p1'));
    await tester.pump(); // one frame — still loading

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Copy embed code'), findsNothing);

    completer.complete('<iframe src="..."></iframe>');
    await tester.pumpAndSettle();
  });

  // ── Success state ─────────────────────────────────────────────────────────

  testWidgets('displays embed code after successful fetch', (tester) async {
    when(() => mockRepo.getEmbedCode(any()))
        .thenAnswer((_) async => '<iframe src="test.com"></iframe>');

    await tester.pumpWidget(_buildSheet(mockRepo, 'p1'));
    await tester.pumpAndSettle();

    expect(find.text('<iframe src="test.com"></iframe>'), findsOneWidget);
    expect(find.text('Copy embed code'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('calls getEmbedCode with the correct playlist id', (tester) async {
    when(() => mockRepo.getEmbedCode(any()))
        .thenAnswer((_) async => '<iframe></iframe>');

    await tester.pumpWidget(_buildSheet(mockRepo, 'playlist-xyz'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.getEmbedCode('playlist-xyz')).called(1);
  });

  // ── Copy button ───────────────────────────────────────────────────────────

  testWidgets('Copy embed code button writes the code to the clipboard',
      (tester) async {
    const iframeCode = '<iframe src="https://biobeats.duckdns.org/embed/p1"></iframe>';
    when(() => mockRepo.getEmbedCode(any()))
        .thenAnswer((_) async => iframeCode);

    String? capturedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        capturedText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(_buildSheet(mockRepo, 'p1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy embed code'));
    await tester.pump();

    expect(capturedText, iframeCode);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // ── Error state ───────────────────────────────────────────────────────────

  testWidgets('shows error message and Try again button when fetch fails',
      (tester) async {
    when(() => mockRepo.getEmbedCode(any()))
        .thenThrow(Exception('network error'));

    await tester.pumpWidget(_buildSheet(mockRepo, 'p1'));
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to load embed code. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Copy embed code'), findsNothing);
  });

  testWidgets('Try again button retries the fetch', (tester) async {
    var callCount = 0;
    when(() => mockRepo.getEmbedCode(any())).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) throw Exception('first failure');
      return '<iframe>retry-ok</iframe>';
    });

    await tester.pumpWidget(_buildSheet(mockRepo, 'p1'));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('<iframe>retry-ok</iframe>'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    verify(() => mockRepo.getEmbedCode('p1')).called(2);
  });
}
