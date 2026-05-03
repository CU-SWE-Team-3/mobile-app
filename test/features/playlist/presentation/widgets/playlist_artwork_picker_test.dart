// Widget tests for PlaylistArtworkPicker.
//
// Verifies that:
//   1. The placeholder is shown when no artwork URL is provided.
//   2. A CircularProgressIndicator overlays the artwork while uploading.
//   3. onArtworkChanged is called with the new URL after a successful upload.
//   4. An error SnackBar is shown (and onArtworkChanged is NOT called) when upload fails.
//   5. Cancelling the picker (returning null) does not start an upload.
//
// The image picker is injectable via [PlaylistArtworkPicker.onPickImage] so
// tests never touch platform channels.
//
// XFile.fromData is used instead of real temp files so readAsBytes() returns
// immediately as a microtask — which tester.pump() CAN flush (unlike real I/O
// events which require the Dart event loop independently).
//
// Run with:
//   flutter test test/features/playlist/presentation/widgets/playlist_artwork_picker_test.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/features/playlist/data/repositories/playlist_repository.dart';
import 'package:soundcloud_clone/features/playlist/presentation/widgets/playlist_artwork_picker.dart';

class _MockPlaylistRepository extends Mock implements PlaylistRepository {}

/// An in-memory XFile whose readAsBytes() resolves as a microtask so pump()
/// advances past it — no real disk I/O needed.
XFile _fakeXFile() => XFile.fromData(
      Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), // JPEG magic bytes
      name: 'cover.jpg',
      mimeType: 'image/jpeg',
    );

Widget _buildPicker(
  _MockPlaylistRepository mockRepo, {
  String? currentArtworkUrl,
  required void Function(String) onArtworkChanged,
  Future<XFile?> Function()? pickImageFn,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PlaylistArtworkPicker(
        playlistId: 'p1',
        currentArtworkUrl: currentArtworkUrl,
        repository: mockRepo,
        onArtworkChanged: onArtworkChanged,
        onPickImage: pickImageFn,
      ),
    ),
  );
}

void main() {
  late _MockPlaylistRepository mockRepo;
  late List<String> changedUrls;

  setUp(() {
    mockRepo = _MockPlaylistRepository();
    changedUrls = [];
    SharedPreferences.setMockInitialValues({});
    when(() => mockRepo.fetchById(any())).thenAnswer((_) async => {});
  });

  // ── Display states ────────────────────────────────────────────────────────

  testWidgets('shows placeholder icon when no artwork URL is provided',
      (tester) async {
    await tester.pumpWidget(
      _buildPicker(mockRepo, onArtworkChanged: changedUrls.add),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
  });

  testWidgets('shows camera overlay when artwork URL is provided',
      (tester) async {
    await tester.pumpWidget(
      _buildPicker(
        mockRepo,
        currentArtworkUrl: 'https://example.com/art.jpg',
        onArtworkChanged: changedUrls.add,
      ),
    );
    await tester.pumpAndSettle();

    // Camera overlay is always present as an upload affordance.
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
  });

  // ── Upload flow ───────────────────────────────────────────────────────────

  testWidgets('shows CircularProgressIndicator while upload is in flight',
      (tester) async {
    final completer = Completer<String>();
    when(() => mockRepo.uploadArtwork(any(), any(), any()))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      _buildPicker(
        mockRepo,
        onArtworkChanged: changedUrls.add,
        pickImageFn: () async => _fakeXFile(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('artwork_picker_tap_target')));
    // Three pumps to advance through:
    //   pump 1: await pickFn() + await readAsBytes() (both microtasks) +
    //            setState(_uploading=true) + rebuild schedule
    //   pump 2: Flutter frame — widget rebuilds with CircularProgressIndicator
    //   pump 3: extra for safety
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Camera overlay is replaced by the spinner while uploading.
    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);

    // Complete the future so the widget disposes cleanly (no pending futures).
    // Don't pumpAndSettle — CachedNetworkImage would animate indefinitely.
    completer.complete('https://cdn.example.com/new-art.jpg');
    await tester.pump();
    await tester.pump();
  });

  testWidgets('calls onArtworkChanged with the new URL after successful upload',
      (tester) async {
    when(() => mockRepo.uploadArtwork(any(), any(), any()))
        .thenAnswer((_) async => 'https://cdn.example.com/new-art.jpg');

    await tester.pumpWidget(
      _buildPicker(
        mockRepo,
        onArtworkChanged: changedUrls.add,
        pickImageFn: () async => _fakeXFile(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('artwork_picker_tap_target')));
    // Four pumps to reach: pickFn → readAsBytes → uploadArtwork → setState
    // All futures resolve as microtasks with XFile.fromData + async mock.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(changedUrls, ['https://cdn.example.com/new-art.jpg']);
    verify(() => mockRepo.uploadArtwork('p1', any(), any())).called(1);
  });

  // ── Error handling ────────────────────────────────────────────────────────

  testWidgets('shows error SnackBar and does not call onArtworkChanged on upload failure',
      (tester) async {
    when(() => mockRepo.uploadArtwork(any(), any(), any()))
        .thenThrow(Exception('server error'));

    await tester.pumpWidget(
      _buildPicker(
        mockRepo,
        onArtworkChanged: changedUrls.add,
        pickImageFn: () async => _fakeXFile(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('artwork_picker_tap_target')));
    // Pump through pick → readAsBytes → uploadArtwork throws → setState + SnackBar
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(); // settle SnackBar animation (no indicator active)

    expect(
      find.text('Could not upload artwork. Please try again.'),
      findsOneWidget,
    );
    expect(changedUrls, isEmpty);
  });

  // ── Picker cancelled ──────────────────────────────────────────────────────

  testWidgets('cancelling the picker (null return) does not start an upload',
      (tester) async {
    await tester.pumpWidget(
      _buildPicker(
        mockRepo,
        onArtworkChanged: changedUrls.add,
        pickImageFn: () async => null, // user cancelled
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('artwork_picker_tap_target')));
    await tester.pumpAndSettle();

    verifyNever(() => mockRepo.uploadArtwork(any(), any(), any()));
    expect(changedUrls, isEmpty);
  });
}
