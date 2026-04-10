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
// IMPORTANT — FilePicker & ImagePicker:
//   Both open native OS dialogs that cannot be driven by the Flutter
//   test framework. Any test that requires actual file selection is
//   marked skip: true and documented for Phase 4 mock injection.
//
// All tests use find.byKey(ValueKey('...')) where Keys exist in the
//   source, and find.text() / find.byType() as fallback.
//
// Routes (confirmed from app_router.dart):
//   /upload              → UploadPage        (Choose Audio File screen)
//   /upload/edit         → UploadEditPage    (metadata form — needs file first)
//   /upload/progress     → UploadProgressPage
//   /library/uploads     → LibraryUploadsPage
//   /library/uploads/edit → EditTrackPage
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
  // bootAndLogin — launches app with real server, logs in, writes
  // userId + role=artist to prefs so upload pages don't gate-keep.
  // ─────────────────────────────────────────────────────────────
  Future<void> bootAndLogin(WidgetTester tester) async {
    app.main();
    await Future.delayed(const Duration(seconds: 2));

    // Wait for start screen — recover from any leftover screen
    for (var i = 0; i < 40; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final onStart = find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty;
      if (onStart) break;
      appRouter.go('/start');
      await tester.pumpAndSettle();
    }

    await loginAs(tester, validEmail, validPassword);

    // Write userId and role=artist so upload pages don't block
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', 'test_user_id');
    await prefs.setString('displayName', validName);
    await prefs.setString('role', 'artist'); // required by _pickAndUpload guard
  }

  // ─────────────────────────────────────────────────────────────
  // Navigation helpers
  // ─────────────────────────────────────────────────────────────
  Future<void> goTo(WidgetTester tester, String route) async {
    appRouter.push(route);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP: UploadPage — /upload  (Choose Audio File screen)
  // ═══════════════════════════════════════════════════════════════
  group('Upload page — /upload', () {

    testWidgets('should show Upload Your Track title', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act — no action needed

      // Assert
      expect(find.text('Upload Your Track'), findsOneWidget);
    });

    testWidgets('should show Choose Audio File button with correct key',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act — no action needed

      // Assert — uses ValueKey confirmed in upload_page.dart
      expect(
        find.byKey(const ValueKey('upload_track_pick_file_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show Cancel button with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_track_cancel_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show upload_file icon', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act — no action needed

      // Assert
      expect(find.byIcon(Icons.upload_file), findsOneWidget);
    });

    testWidgets('should navigate back when Cancel tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload');

      // Act
      await tester.tap(
        find.byKey(const ValueKey('upload_track_cancel_button')),
      );
      await tester.pumpAndSettle();

      // Assert — page is gone
      expect(find.text('Upload Your Track'), findsNothing);
    });

    testWidgets(
      'Choose Audio File button is tappable (FilePicker native — skip)',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await goTo(tester, '/upload');

        // Act — tap the button (FilePicker opens native OS dialog)
        await tester.tap(
          find.byKey(const ValueKey('upload_track_pick_file_button')),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert — button was tappable (no crash)
        expect(find.text('Upload Your Track'), findsOneWidget);
      },
      skip: true, // Phase 4: inject mock FilePicker — native dialog blocks test
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: LibraryUploadsPage — /library/uploads
  // ═══════════════════════════════════════════════════════════════
  group('Library uploads page — /library/uploads', () {

    testWidgets('should show Your Uploads app bar title', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Act — no action needed

      // Assert
      expect(find.text('Your Uploads'), findsOneWidget);
    });

    testWidgets('should show search field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('uploads_search_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show No Amplify credits pill', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Act — no action needed

      // Assert
      expect(find.text('No Amplify credits'), findsOneWidget);
    });

    testWidgets('should show storage usage pill', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Act — no action needed

      // Assert
      expect(find.text('24/120 mins used'), findsOneWidget);
    });

    testWidgets('should show upload FAB with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads');

      // Act — no action needed

      // Assert
      expect(find.byKey(const ValueKey('uploads_add_fab')), findsOneWidget);
    });

    testWidgets(
      'should show Artist Role Required dialog when role is not artist',
      (tester) async {
        // Arrange — override prefs to non-artist role
        await bootAndLogin(tester);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role', 'user'); // not artist
        await goTo(tester, '/library/uploads');

        // Act — tap FAB which checks role before opening FilePicker
        await tester.tap(find.byKey(const ValueKey('uploads_add_fab')));
        await tester.pumpAndSettle();

        // Assert — dialog shown instead of FilePicker
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

        // Assert
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

        // Assert — dialog dismissed
        expect(find.text('Artist Role Required'), findsNothing);
        expect(find.text('Your Uploads'), findsOneWidget);
      },
    );

    testWidgets(
      'should type in search field and show clear button',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await goTo(tester, '/library/uploads');

        // Act — enter search text
        await tester.enterText(
          find.byKey(const ValueKey('uploads_search_field')),
          'test',
        );
        await tester.pumpAndSettle();

        // Assert — clear button appears
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
  // GROUP: UploadEditPage — /upload/edit (metadata form)
  // Reached after file selection — FilePicker-dependent tests skipped
  // Static UI tests run directly by navigating to the route
  // ═══════════════════════════════════════════════════════════════
  group('Upload edit page — /upload/edit', () {

    testWidgets('should show title field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_track_title_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show Upload Track submit button with correct key',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_track_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show description field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_description_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show tags field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_tags_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show cover image button with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_cover_image_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show Replace file button with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_replace_file_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show release date field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_track_release_date_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show genre picker chip', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('upload_genre_picker')),
        findsOneWidget,
      );
    });

    testWidgets('should show Public privacy option', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(find.text('Public'), findsOneWidget);
    });

    testWidgets('should show Unlisted (Private) privacy option', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert
      expect(find.text('Unlisted (Private)'), findsOneWidget);
    });

    testWidgets('should default privacy to Public', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — no action needed

      // Assert — Public option shows check icon (isSelected=true)
      // The check icon only renders when the option is selected
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('should add a tag when text is entered and add button tapped',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — type a tag and tap add
      await tester.enterText(
        find.byKey(const ValueKey('upload_tags_field')),
        'indie',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('upload_add_tag_button')));
      await tester.pumpAndSettle();

      // Assert — tag chip appears with the entered text
      expect(find.text('indie'), findsOneWidget);
    });

    testWidgets('should remove tag when close button tapped', (tester) async {
      // Arrange — add a tag first
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');
      await tester.enterText(
        find.byKey(const ValueKey('upload_tags_field')),
        'pop',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('upload_add_tag_button')));
      await tester.pumpAndSettle();

      // Act — tap the remove button on the tag chip
      await tester.tap(find.byKey(const ValueKey('upload_tag_remove_button')));
      await tester.pumpAndSettle();

      // Assert — tag is gone
      expect(find.text('pop'), findsNothing);
    });

    testWidgets('should open genre picker sheet when genre chip tapped',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act
      await tester.tap(find.byKey(const ValueKey('upload_genre_picker')));
      await tester.pumpAndSettle();

      // Assert — genre picker sheet is shown
      expect(find.text('Select Genre'), findsOneWidget);
    });

    testWidgets('should navigate back when Replace file button tapped',
        (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/upload/edit');

      // Act — Replace file taps context.pop()
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
      await goTo(tester, '/upload/edit');

      // Act
      await tester.tap(find.byKey(const ValueKey('upload_back_button')));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.byKey(const ValueKey('upload_track_submit_button')),
        findsNothing,
      );
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: EditTrackPage — /library/uploads/edit
  // ═══════════════════════════════════════════════════════════════
  group('Edit track page — /library/uploads/edit', () {

    testWidgets('should show title field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('track_metadata_title_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show Save button with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('track_metadata_save_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show description field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('edit_track_description_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show tags field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('edit_track_tags_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show release date field with correct key', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act — no action needed

      // Assert
      expect(
        find.byKey(const ValueKey('track_metadata_release_date_field')),
        findsOneWidget,
      );
    });

    testWidgets('should update title field when text entered', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act — enter a new title
      await tester.enterText(
        find.byKey(const ValueKey('track_metadata_title_field')),
        'Updated Track Name',
      );
      await tester.pumpAndSettle();

      // Assert — new title text is present
      expect(find.text('Updated Track Name'), findsOneWidget);
    });

    testWidgets('should add tag in edit track page', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act
      await tester.enterText(
        find.byKey(const ValueKey('edit_track_tags_field')),
        'electronic',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit_track_add_tag_button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('electronic'), findsOneWidget);
    });

    testWidgets('should navigate back when Save tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goTo(tester, '/library/uploads/edit');

      // Act — Save calls context.pop()
      await tester.tap(
        find.byKey(const ValueKey('track_metadata_save_button')),
      );
      await tester.pumpAndSettle();

      // Assert — edit page gone
      expect(
        find.byKey(const ValueKey('track_metadata_save_button')),
        findsNothing,
      );
    });

  });

}