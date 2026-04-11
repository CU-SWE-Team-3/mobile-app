import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/main.dart' as app;
import 'package:soundcloud_clone/core/router/app_router.dart';

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';

// ─────────────────────────────────────────────────────────────────
// Module 4: Audio Upload & Track Management
// Owner: Abdelrahman Osama
// Phase 3 — Real server, no mock.
//
// API Upload Flow (6 steps):
//   1. POST  /tracks/upload            → {trackId, uploadUrl (SAS, 15-min)}
//   2. PUT   <Azure SAS URL>           → binary upload (client-side, with progress)
//   3. PATCH /tracks/{id}/confirm      → triggers FFmpeg (HLS + waveform)
//   4. PATCH /tracks/{id}/metadata     → title, genre, description, tags, releaseDate
//   5. PATCH /tracks/{id}/artwork      → cover image (optional multipart)
//   6. GET   /tracks/{permalink} poll  → wait for processingState == "Finished"
//
// Supported audio formats: audio/mpeg, audio/mp3, audio/wav, audio/x-wav, audio/wave
// Track visibility: isPublic=true (searchable) | isPublic=false (link-only)
// Waveform: generated server-side (150 normalised peak values 0–100)
//
// IMPORTANT — FilePicker & ImagePicker:
//   Both open native OS dialogs that cannot be driven by the Flutter
//   test framework. Tests requiring actual file selection are marked
//   skip:true and documented for Phase 4 mock injection.
//
// Active Routes (confirmed from app_router.dart):
//   /upload                   → UploadEditPage   (metadata form, new upload)
//   /upload/progress          → UploadProgressPage
//   /library/uploads          → LibraryUploadsPage (GET /tracks/my-tracks)
//   /library/uploads/edit     → UploadEditPage   (same widget, edit-metadata mode)
//   /library/uploads/progress → UploadProgressPage
//
// NOTE: UploadPage (upload_page.dart) and EditTrackPage (edit_track_page.dart)
//   are not registered in the router and are therefore NOT tested here.
// ─────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GetIt.instance.allowReassignment = true;

  // ── setUp: full state reset before each test ─────────────────
  setUp(() async {
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  // ── tearDown: return to /start so no page leaks into next test ─
  tearDown(() async {
    try {
      appRouter.go('/start');
    } catch (_) {}
  });

  // ─────────────────────────────────────────────────────────────
  // bootAndLogin — launches app, logs in with real server, writes
  // role=artist so upload guards don't block.
  // ─────────────────────────────────────────────────────────────
  Future<void> bootAndLogin(WidgetTester tester) async {
    app.main();
    await Future.delayed(const Duration(seconds: 2));

    for (var i = 0; i < 40; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final onStart = find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty;
      if (onStart) break;
      appRouter.go('/start');
      await tester.pumpAndSettle();
    }

    await loginAs(tester, validEmail, validPassword);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', 'test_user_id');
    await prefs.setString('displayName', validName);
    await prefs.setString('role', 'artist');
  }

  Future<void> goTo(WidgetTester tester, String route) async {
    appRouter.push(route);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 1: UploadEditPage — /upload
  // Entry point for new track uploads. Collects metadata sent to:
  //   POST /tracks/upload → format, size, duration (required)
  //   PATCH /tracks/{id}/metadata → title, genre, description, tags, releaseDate
  //   PATCH /tracks/{id}/artwork  → cover image (optional)
  // On submit → navigates to /upload/progress
  // ═══════════════════════════════════════════════════════════════
  group('Upload edit page — /upload', () {

    testWidgets('should show title field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — title is required by POST /tracks/upload
      expect(
        find.byKey(const ValueKey('upload_track_title_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show Upload Track submit button', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — triggers the 6-step upload flow
      expect(
        find.byKey(const ValueKey('upload_track_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show description field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — maps to PATCH /tracks/{id}/metadata description field
      expect(
        find.byKey(const ValueKey('upload_description_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show tags field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — maps to PATCH /tracks/{id}/metadata tags array
      expect(
        find.byKey(const ValueKey('upload_tags_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show cover image button', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — triggers PATCH /tracks/{id}/artwork (optional)
      expect(
        find.byKey(const ValueKey('upload_cover_image_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show Replace file button', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — allows re-selecting a different audio file before upload
      expect(
        find.byKey(const ValueKey('upload_replace_file_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show release date field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — maps to releaseDate in PATCH /tracks/{id}/metadata
      expect(
        find.byKey(const ValueKey('upload_track_release_date_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show genre picker', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — maps to genre in PATCH /tracks/{id}/metadata
      expect(
        find.byKey(const ValueKey('upload_genre_picker')),
        findsOneWidget,
      );
    });

    testWidgets('should show Public privacy option', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — isPublic=true: track is searchable (PATCH /tracks/{id}/visibility)
      expect(find.text('Public'), findsOneWidget);
    });

    testWidgets('should show Unlisted (Private) privacy option', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — isPublic=false: track accessible via link only
      expect(find.text('Unlisted (Private)'), findsOneWidget);
    });

    testWidgets('should default privacy to Public (isPublic = true)',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Assert — API default: isPublic=true; check icon appears next to Public row
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Unlisted (Private)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Public'),
            matching: find.byType(GestureDetector),
          ),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('should add a tag when text is entered and add button tapped',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act — type a tag and tap add
      await tester.enterText(
        find.byKey(const ValueKey('upload_tags_field')),
        'indie',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('upload_add_tag_button')));
      await tester.pumpAndSettle();

      // Assert — tag chip appears; sent as tags[] array in PATCH /tracks/{id}/metadata
      expect(find.text('indie'), findsOneWidget);
    });

    testWidgets('should remove tag when close button tapped', (tester) async {
      // Arrange — add a tag first
      await bootAndLogin(tester);
      await goTo(tester, '/upload');
      await tester.enterText(
        find.byKey(const ValueKey('upload_tags_field')),
        'pop',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('upload_add_tag_button')));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const ValueKey('upload_tag_remove_button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('pop'), findsNothing);
    });

    testWidgets('should open genre picker sheet when genre chip tapped',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act
      await tester.tap(find.byKey(const ValueKey('upload_genre_picker')));
      await tester.pumpAndSettle();

      // Assert — searchable genre list sheet shown
      expect(find.text('Select Genre'), findsOneWidget);
    });

    testWidgets('should navigate back when Replace file button tapped',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act — Replace file pops the current page to re-select audio
      await tester.tap(
        find.byKey(const ValueKey('upload_replace_file_button')),
      );
      await tester.pumpAndSettle();

      // Assert — upload edit page gone
      expect(
        find.byKey(const ValueKey('upload_track_submit_button')),
        findsNothing,
      );
    });

    testWidgets('should navigate back when back button tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act
      await tester.tap(find.byKey(const ValueKey('upload_back_button')));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.byKey(const ValueKey('upload_track_submit_button')),
        findsNothing,
      );
    });

    testWidgets(
      'cover image button is tappable (ImagePicker native — skip)',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await goTo(tester, '/upload');

        // Act — opens native image picker; cannot be driven in test framework
        await tester.tap(
          find.byKey(const ValueKey('upload_cover_image_button')),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert — button was tappable (no crash)
        expect(
          find.byKey(const ValueKey('upload_track_submit_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock ImagePicker — native dialog blocks test
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 2: LibraryUploadsPage — /library/uploads
  // Calls GET /tracks/my-tracks → all Finished tracks for the user.
  // Track tiles show processingState != "Finished" with a spinner.
  // Options sheet: play, edit (→ /library/uploads/edit), change
  // visibility (PATCH /tracks/{id}/visibility), delete (DELETE /tracks/{id}).
  // ═══════════════════════════════════════════════════════════════
  group('Library uploads page — /library/uploads', () {

    testWidgets('should show Your Uploads app bar title', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Assert
      expect(find.text('Your Uploads'), findsOneWidget);
    });

    testWidgets('should show search field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Assert — filters GET /tracks/my-tracks results client-side
      expect(
        find.byKey(const ValueKey('uploads_search_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show No Amplify credits pill', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Assert
      expect(find.text('No Amplify credits'), findsOneWidget);
    });

    testWidgets('should show storage usage pill', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Assert
      expect(find.text('24/120 mins used'), findsOneWidget);
    });

    testWidgets('should show upload FAB', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Assert — FAB opens file picker then navigates to /upload
      expect(find.byKey(const ValueKey('uploads_add_fab')), findsOneWidget);
    });

    testWidgets(
      'should show Artist Role Required dialog when role is not artist',
      (tester) async {
        // Arrange — override prefs to non-artist role
        await bootAndLogin(tester);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role', 'user');
        await goTo(tester, '/library/uploads');

        // Act — FAB checks role before opening FilePicker
        await tester.tap(find.byKey(const ValueKey('uploads_add_fab')));
        await tester.pumpAndSettle();

        // Assert — role gate shown; use PATCH /profile/tier to upgrade
        expect(find.text('Artist Role Required'), findsOneWidget);
      },
    );

    testWidgets(
      'should show Upgrade to Artist button inside role dialog',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role', 'user');
        await goTo(tester, '/library/uploads');

        // Act
        await tester.tap(find.byKey(const ValueKey('uploads_add_fab')));
        await tester.pumpAndSettle();

        // Assert — calls PATCH /profile/tier {role: "artist"}
        expect(
          find.byKey(const ValueKey('uploads_role_upgrade_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'should dismiss role dialog when Cancel tapped',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role', 'user');
        await goTo(tester, '/library/uploads');

        // Act
        await tester.tap(find.byKey(const ValueKey('uploads_add_fab')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('uploads_role_cancel_button')),
        );
        await tester.pumpAndSettle();

        // Assert — dialog dismissed, library page remains
        expect(find.text('Artist Role Required'), findsNothing);
        expect(find.text('Your Uploads'), findsOneWidget);
      },
    );

    testWidgets(
      'should show clear button when search text is entered',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await goTo(tester, '/library/uploads');

        // Act
        await tester.enterText(
          find.byKey(const ValueKey('uploads_search_field')),
          'test',
        );
        await tester.pumpAndSettle();

        // Assert
        expect(
          find.byKey(const ValueKey('uploads_search_clear_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'should clear search field when clear button tapped',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await goTo(tester, '/library/uploads');
        await tester.enterText(
          find.byKey(const ValueKey('uploads_search_field')),
          'test',
        );
        await tester.pumpAndSettle();

        // Act
        await tester.tap(
          find.byKey(const ValueKey('uploads_search_clear_button')),
        );
        await tester.pumpAndSettle();

        // Assert — clear button gone (field is empty)
        expect(
          find.byKey(const ValueKey('uploads_search_clear_button')),
          findsNothing,
        );
      },
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 3: UploadProgressPage — /upload/progress
  // Monitors the 6-step upload + transcoding pipeline:
  //   Uploading (10–75%) → Confirm (80%) → Metadata (85%) →
  //   Artwork (90%) → Processing server (polled) → Finished (100%)
  //
  // When navigated to directly (no file in provider state), the
  // upload attempt fails immediately → error state is shown.
  // ═══════════════════════════════════════════════════════════════
  group('Upload progress page — /upload/progress', () {

    testWidgets('should show circular progress indicator', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/progress');

      // Assert — 150×150 circular progress shown while uploading or processing
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('should show fallback track title when no track is loaded',
        (tester) async {
      // Arrange — provider has empty state (no file selected)
      await bootAndLogin(tester);
      await goTo(tester, '/upload/progress');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert — "Untitled Track" shown when UploadTrack.title is empty
      expect(find.text('Untitled Track'), findsOneWidget);
    });

    testWidgets('should show fallback artist when no track is loaded',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/progress');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert — "Unknown Artist" shown when UploadTrack.artist is empty
      expect(find.text('Unknown Artist'), findsOneWidget);
    });

    testWidgets('should show Try Again button on upload error', (tester) async {
      // Arrange — no file in state → POST /tracks/upload fails → error state
      await bootAndLogin(tester);
      await goTo(tester, '/upload/progress');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert
      expect(
        find.byKey(const ValueKey('upload_progress_retry_button')),
        findsOneWidget,
      );
    });

    testWidgets(
        'should show back button after upload error (not during active upload)',
        (tester) async {
      // Arrange — PopScope blocks back nav only while isUploading==true
      await bootAndLogin(tester);
      await goTo(tester, '/upload/progress');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert — back button visible once error state is reached
      expect(
        find.byKey(const ValueKey('upload_progress_back_button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'should show View in My Uploads button after successful upload',
      (tester) async {
        // Cannot reach success state without a real file upload + server processing
        await bootAndLogin(tester);
        await goTo(tester, '/upload/progress');
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          find.byKey(const ValueKey('upload_progress_view_uploads_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock upload provider to simulate Finished state
    );

    testWidgets(
      'should show Upload Another Track button after successful upload',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/upload/progress');
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          find.byKey(const ValueKey('upload_progress_upload_another_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock upload provider to simulate Finished state
    );

    testWidgets(
      'should show Artist Role Required upgrade button when role upgrade needed',
      (tester) async {
        // needsRoleUpgrade flag is set by PATCH /profile/tier failure path
        await bootAndLogin(tester);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role', 'user');
        await goTo(tester, '/upload/progress');
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          find.byKey(const ValueKey('upload_progress_upgrade_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock provider to force needsRoleUpgrade=true
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 4: UploadEditPage (edit-metadata mode) — /library/uploads/edit
  // Same widget as /upload. Reached via the track options sheet
  // ("Edit" tile → /library/uploads/edit). On submit, patches:
  //   PATCH /tracks/{id}/metadata → title, genre, description, tags, releaseDate
  //   PATCH /tracks/{id}/artwork  → cover image (optional)
  // ═══════════════════════════════════════════════════════════════
  group('Upload edit page (edit mode) — /library/uploads/edit', () {

    testWidgets('should show title field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Assert
      expect(
        find.byKey(const ValueKey('upload_track_title_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show Submit/Save button', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Assert — triggers PATCH /tracks/{id}/metadata + optional artwork patch
      expect(
        find.byKey(const ValueKey('upload_track_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show description field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Assert
      expect(
        find.byKey(const ValueKey('upload_description_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show tags field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Assert
      expect(
        find.byKey(const ValueKey('upload_tags_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show release date field', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Assert — releaseDate sent as ISO8601 in PATCH /tracks/{id}/metadata
      expect(
        find.byKey(const ValueKey('upload_track_release_date_field')),
        findsOneWidget,
      );
    });

    testWidgets('should update title field when text is entered', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act — enter a new title
      await tester.enterText(
        find.byKey(const ValueKey('upload_track_title_field')),
        'Updated Track Name',
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Updated Track Name'), findsOneWidget);
    });

    testWidgets('should add a tag in edit mode', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act
      await tester.enterText(
        find.byKey(const ValueKey('upload_tags_field')),
        'electronic',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('upload_add_tag_button')));
      await tester.pumpAndSettle();

      // Assert — tag chip appears; will be included in tags[] array on submit
      expect(find.text('electronic'), findsOneWidget);
    });

    testWidgets('should navigate back when back button tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act
      await tester.tap(find.byKey(const ValueKey('upload_back_button')));
      await tester.pumpAndSettle();

      // Assert — edit page gone (returns to /library/uploads)
      expect(
        find.byKey(const ValueKey('upload_track_submit_button')),
        findsNothing,
      );
    });

  });

}
