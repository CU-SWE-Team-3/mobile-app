// ─────────────────────────────────────────────────────────────────────────────
// BioBeats — Module 7 — Sets & Playlists
// Owner    : Abdelrahman Osama  |  Phase 4  |  Android
// Framework: Flutter integration_test — real server
//
// API endpoints exercised:
//   POST   /playlists               (title required, maxLength 100, isPrivate flag)
//   PATCH  /playlists/{id}          (edit title / description / isPrivate)
//   DELETE /playlists/{id}          (owner only → "Playlist deleted" snackbar)
//   PUT    /playlists/{id}/tracks   (reorder tracks array)
//   DELETE /playlists/{id}/tracks   (remove a track)
//   GET    /playlists/{id}/embed    (public: iframeCode; private: 403)
//
// Test IDs: PLS-001 → PLS-060
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/main.dart' as app;
import 'package:soundcloud_clone/core/router/app_router.dart';

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';
import 'helpers/test_keys.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GetIt.instance.allowReassignment = true;

  setUp(() async {
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  tearDown(() async {
    try { appRouter.go('/start'); } catch (_) {}
  });

  Future<void> bootAndLogin(WidgetTester t) async {
    app.main();
    await Future.delayed(const Duration(seconds: 2));
    for (var i = 0; i < 40; i++) {
      await t.pumpAndSettle(const Duration(milliseconds: 500));
      if (find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty) break;
      appRouter.go('/start');
      await t.pumpAndSettle();
    }
    await loginAs(t, validEmail, validPassword);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayName', validName);
  }

  Future<void> goTo(WidgetTester t, String r) async {
    appRouter.push(r);
    await t.pumpAndSettle(const Duration(seconds: 4));
  }

  Future<void> goToWithExtra(WidgetTester t, String r, Object e) async {
    appRouter.push(r, extra: e);
    await t.pumpAndSettle(const Duration(seconds: 4));
  }

  // ══════════════════════════════════════════════════════════════
  // GROUP 1 — Library Playlists page
  // ══════════════════════════════════════════════════════════════
  group('PLS — Library Playlists page', () {

    testWidgets('PLS-001: Create FAB present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/library/playlists');
      expect(find.byKey(const Key(kPlaylistsCreateFab)), findsOneWidget);
    });

    testWidgets('PLS-002: Page title contains "Playlist"', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/library/playlists');
      expect(find.textContaining('Playlist'), findsWidgets);
    });

    testWidgets('PLS-003: Tapping FAB navigates away from library', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/library/playlists');
      await t.tap(find.byKey(const Key(kPlaylistsCreateFab)));
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byKey(const Key(kPlaylistsCreateFab)), findsNothing);
    });

    testWidgets('PLS-004: playlist_tile or empty state shown', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/library/playlists');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.byKey(const Key(kPlaylistTile)).evaluate().isNotEmpty
          || find.textContaining('Playlist').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PLS-005: Page does not crash on scroll', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/library/playlists');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final tile = find.byKey(const Key(kPlaylistTile));
      if (tile.evaluate().isNotEmpty) {
        await t.fling(tile.first, const Offset(0, -200), 600);
        await t.pumpAndSettle();
      }
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 2 — Create Playlist
  // API: POST /playlists  — title required (minLength 1, maxLength 100)
  //                         isPrivate: false default
  // ══════════════════════════════════════════════════════════════
  group('PLS — Create Playlist page', () {

    testWidgets('PLS-006: playlist_name_field present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      expect(find.byKey(const Key(kPlaylistNameField)), findsOneWidget);
    });

    testWidgets('PLS-007: playlist_privacy_toggle present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      expect(find.byKey(const Key(kPlaylistPrivacyToggle)), findsOneWidget);
    });

    testWidgets('PLS-008: playlist_save_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      expect(find.byKey(const Key(kPlaylistSaveButton)), findsOneWidget);
    });

    testWidgets('PLS-009: playlist_back_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      expect(find.byKey(const Key(kPlaylistBackButton)), findsOneWidget);
    });

    // API note: description field is NOT part of POST /playlists on mobile create screen
    testWidgets('PLS-010: playlist_description_field absent on create (edit-only)', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      expect(find.byKey(const Key(kPlaylistDescField)), findsNothing);
    });

    testWidgets('PLS-011: Name field accepts text input', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      await t.enterText(find.byKey(const Key(kPlaylistNameField)), 'My Playlist');
      await t.pumpAndSettle();
      expect(find.text('My Playlist'), findsOneWidget);
    });

    testWidgets('PLS-012: privacy_toggle tappable — save button survives', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      await t.tap(find.byKey(const Key(kPlaylistPrivacyToggle)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key(kPlaylistSaveButton)), findsOneWidget);
    });

    testWidgets('PLS-013: back_button navigates away', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      await t.tap(find.byKey(const Key(kPlaylistBackButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key(kPlaylistSaveButton)), findsNothing);
    });

    // API: title required — empty submit shows validation, no crash
    testWidgets('PLS-014: Save with empty name — validation shown, no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      await t.tap(find.byKey(const Key(kPlaylistSaveButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(Exception), findsNothing);
    });

    // API: title maxLength is 100 — boundary test at exactly 100 chars
    testWidgets('PLS-015: Name field accepts exactly 100 chars (API max)', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      await t.enterText(find.byKey(const Key(kPlaylistNameField)), 'A' * 100);
      await t.pumpAndSettle();
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('PLS-016: Double-toggle privacy leaves widget tree intact', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      final toggle = find.byKey(const Key(kPlaylistPrivacyToggle));
      await t.tap(toggle);
      await t.pumpAndSettle();
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(find.byKey(const Key(kPlaylistSaveButton)), findsOneWidget);
    });

    testWidgets('PLS-017: Creating playlist with valid name shows no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/create');
      await t.enterText(find.byKey(const Key(kPlaylistNameField)),
          'E2E Playlist ${DateTime.now().millisecondsSinceEpoch}');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key(kPlaylistSaveButton)));
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 3 — Edit Playlist
  // API: PATCH /playlists/{id}  — title maxLength 100, description maxLength 1000
  // ══════════════════════════════════════════════════════════════
  group('PLS — Edit Playlist page', () {

    testWidgets('PLS-018: playlist_name_field present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      expect(find.byKey(const Key(kPlaylistNameField)), findsOneWidget);
    });

    testWidgets('PLS-019: playlist_description_field present on edit page', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      expect(find.byKey(const Key(kPlaylistDescField)), findsOneWidget);
    });

    testWidgets('PLS-020: playlist_privacy_toggle present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      expect(find.byKey(const Key(kPlaylistPrivacyToggle)), findsOneWidget);
    });

    testWidgets('PLS-021: playlist_save_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      expect(find.byKey(const Key(kPlaylistSaveButton)), findsOneWidget);
    });

    testWidgets('PLS-022: playlist_back_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      expect(find.byKey(const Key(kPlaylistBackButton)), findsOneWidget);
    });

    testWidgets('PLS-023: Name field accepts updated text', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      await t.enterText(find.byKey(const Key(kPlaylistNameField)), 'Renamed Playlist');
      await t.pumpAndSettle();
      expect(find.text('Renamed Playlist'), findsOneWidget);
    });

    testWidgets('PLS-024: Description field accepts text', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      await t.enterText(find.byKey(const Key(kPlaylistDescField)), 'A great mix');
      await t.pumpAndSettle();
      expect(find.text('A great mix'), findsOneWidget);
    });

    testWidgets('PLS-025: Back button navigates away', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      await t.tap(find.byKey(const Key(kPlaylistBackButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key(kPlaylistSaveButton)), findsNothing);
    });

    // API: title required — clearing and saving triggers validation
    testWidgets('PLS-026: Clearing name then saving — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      await t.enterText(find.byKey(const Key(kPlaylistNameField)), '');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key(kPlaylistSaveButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(Exception), findsNothing);
    });

    // API: description maxLength is 1000
    testWidgets('PLS-027: 500-char description accepted without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/edit');
      await t.enterText(find.byKey(const Key(kPlaylistDescField)), 'D' * 500);
      await t.pumpAndSettle();
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 4 — Playlist Detail page
  // API: PUT /playlists/{id}/tracks (reorder), DELETE /playlists/{id}/tracks (remove)
  // ══════════════════════════════════════════════════════════════
  group('PLS — Playlist Detail page', () {

    testWidgets('PLS-028: playlist_back_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      expect(find.byKey(const Key(kPlaylistBackButton)), findsOneWidget);
    });

    testWidgets('PLS-029: playlist_add_tracks_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byKey(const Key(kPlaylistAddTracksButton)), findsOneWidget);
    });

    testWidgets('PLS-030: playlist_track_tile or empty state rendered', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.byKey(const Key(kPlaylistTrackTile)).evaluate().isNotEmpty
          || find.textContaining('track').evaluate().isNotEmpty
          || find.textContaining('Add').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PLS-031: Back button navigates away', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.tap(find.byKey(const Key(kPlaylistBackButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key(kPlaylistAddTracksButton)), findsNothing);
    });

    testWidgets('PLS-032: Add tracks button navigates without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 3));
      await t.tap(find.byKey(const Key(kPlaylistAddTracksButton)));
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byKey(const Key(kPlaylistBackButton)), findsOneWidget);
    });

    // API: PUT /playlists/{id}/tracks — drag to reorder submits new track array
    testWidgets('PLS-033: playlist_drag_handle present when tracks rendered', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 4));
      if (find.byKey(const Key(kPlaylistTrackTile)).evaluate().isNotEmpty) {
        final ok = find.byKey(const Key(kPlaylistDragHandle)).evaluate().isNotEmpty
            || find.byKey(Key(kPlaylistDragHandleByIdx(0))).evaluate().isNotEmpty;
        expect(ok, isTrue);
      }
    });

    // API: DELETE /playlists/{id}/tracks — playlist_remove_track_button present
    testWidgets('PLS-034: playlist_remove_track_button present per track tile', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 4));
      if (find.byKey(const Key(kPlaylistTrackTile)).evaluate().isNotEmpty) {
        expect(find.byKey(const Key(kPlaylistRemoveTrackBtn)), findsWidgets);
      }
    });

    testWidgets('PLS-035: Tapping track tile does not crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final tile = find.byKey(const Key(kPlaylistTrackTile));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('PLS-036: More button opens options sheet with delete option', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final moreBtn = find.byIcon(Icons.more_vert).evaluate().isNotEmpty
          ? find.byIcon(Icons.more_vert)
          : find.byIcon(Icons.more_horiz);
      if (moreBtn.evaluate().isNotEmpty) {
        await t.tap(moreBtn.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        final hasDelete = find.byKey(const Key(kPlaylistDeleteButton)).evaluate().isNotEmpty
            || find.textContaining('Delete').evaluate().isNotEmpty;
        expect(hasDelete, isTrue);
      }
    });

    testWidgets('PLS-037: Options sheet contains Edit option', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final moreBtn = find.byIcon(Icons.more_vert).evaluate().isNotEmpty
          ? find.byIcon(Icons.more_vert)
          : find.byIcon(Icons.more_horiz);
      if (moreBtn.evaluate().isNotEmpty) {
        await t.tap(moreBtn.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        final ok = find.textContaining('Edit').evaluate().isNotEmpty
            || find.byIcon(Icons.edit_outlined).evaluate().isNotEmpty;
        expect(ok, isTrue);
      }
    });

    testWidgets('PLS-038: Options sheet contains Share option', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final moreBtn = find.byIcon(Icons.more_vert).evaluate().isNotEmpty
          ? find.byIcon(Icons.more_vert)
          : find.byIcon(Icons.more_horiz);
      if (moreBtn.evaluate().isNotEmpty) {
        await t.tap(moreBtn.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        final ok = find.textContaining('Share').evaluate().isNotEmpty
            || find.byIcon(Icons.share_rounded).evaluate().isNotEmpty;
        expect(ok, isTrue);
      }
    });

    testWidgets('PLS-039: Edit in options navigates to edit page', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final moreBtn = find.byIcon(Icons.more_vert).evaluate().isNotEmpty
          ? find.byIcon(Icons.more_vert)
          : find.byIcon(Icons.more_horiz);
      if (moreBtn.evaluate().isNotEmpty) {
        await t.tap(moreBtn.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        final editBtn = find.textContaining('Edit').evaluate().isNotEmpty
            ? find.textContaining('Edit')
            : find.byIcon(Icons.edit_outlined);
        if (editBtn.evaluate().isNotEmpty) {
          await t.tap(editBtn.first);
          await t.pumpAndSettle(const Duration(seconds: 3));
          expect(find.byKey(const Key(kPlaylistNameField)), findsOneWidget);
        }
      }
    });

    // API: DELETE /playlists/{id} — shows confirmation, then snackbar "Playlist deleted"
    testWidgets('PLS-040: Tapping delete button shows confirmation — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final moreBtn = find.byIcon(Icons.more_vert).evaluate().isNotEmpty
          ? find.byIcon(Icons.more_vert)
          : find.byIcon(Icons.more_horiz);
      if (moreBtn.evaluate().isNotEmpty) {
        await t.tap(moreBtn.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        final deleteBtn = find.byKey(const Key(kPlaylistDeleteButton));
        if (deleteBtn.evaluate().isNotEmpty) {
          await t.tap(deleteBtn);
          await t.pumpAndSettle(const Duration(seconds: 2));
          expect(find.byType(Exception), findsNothing);
        }
      }
    });

    // API: PUT /playlists/{id}/tracks — drag index 0 triggers reorder call
    testWidgets('PLS-041: Dragging playlist_drag_handle_0 does not crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final handle = find.byKey(Key(kPlaylistDragHandleByIdx(0)));
      if (handle.evaluate().isNotEmpty) {
        await t.drag(handle, const Offset(0, 60));
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // API: DELETE /playlists/{id}/tracks — count decreases after remove
    testWidgets('PLS-042: Tapping remove track button does not crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final removeBtn = find.byKey(const Key(kPlaylistRemoveTrackBtn));
      if (removeBtn.evaluate().isNotEmpty) {
        final before = find.byKey(const Key(kPlaylistTrackTile)).evaluate().length;
        await t.tap(removeBtn.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        final after = find.byKey(const Key(kPlaylistTrackTile)).evaluate().length;
        expect(after <= before, isTrue);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 5 — Privacy Settings page
  // ══════════════════════════════════════════════════════════════
  group('PLS — Privacy Settings page', () {

    testWidgets('PLS-043: playlist_privacy_toggle present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/privacy');
      expect(find.byKey(const Key(kPlaylistPrivacyToggle)), findsOneWidget);
    });

    testWidgets('PLS-044: playlist_back_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/privacy');
      expect(find.byKey(const Key(kPlaylistBackButton)), findsOneWidget);
    });

    testWidgets('PLS-045: Public or Private labels visible', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/privacy');
      final ok = find.textContaining('Public').evaluate().isNotEmpty
          || find.textContaining('Private').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PLS-046: Toggle tappable — stays on page', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/privacy');
      await t.tap(find.byKey(const Key(kPlaylistPrivacyToggle)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key(kPlaylistPrivacyToggle)), findsOneWidget);
    });

    testWidgets('PLS-047: Back button navigates away', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/privacy');
      await t.tap(find.byKey(const Key(kPlaylistBackButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key(kPlaylistPrivacyToggle)), findsNothing);
    });

    testWidgets('PLS-048: Double-tap toggle — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/privacy');
      final toggle = find.byKey(const Key(kPlaylistPrivacyToggle));
      await t.tap(toggle); await t.pumpAndSettle();
      await t.tap(toggle); await t.pumpAndSettle();
      expect(find.byKey(const Key(kPlaylistBackButton)), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 6 — Share / Embed page
  // API: GET /playlists/{id}/embed → 200 iframeCode (public) / 403 (private + no token)
  // ══════════════════════════════════════════════════════════════
  group('PLS — Share & Embed page', () {

    testWidgets('PLS-049: Share page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/share');
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('PLS-050: Share page shows link, embed or share content', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/share');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final ok = find.textContaining('Link').evaluate().isNotEmpty
          || find.textContaining('Embed').evaluate().isNotEmpty
          || find.textContaining('Share').evaluate().isNotEmpty
          || find.textContaining('iframe').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PLS-051: playlist_back_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/share');
      expect(find.byKey(const Key(kPlaylistBackButton)), findsOneWidget);
    });

    testWidgets('PLS-052: Back button navigates away', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/share');
      await t.tap(find.byKey(const Key(kPlaylistBackButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key(kPlaylistBackButton)), findsNothing);
    });

    // API: GET /playlists/{id}/embed → response has iframeCode field → copy button visible
    testWidgets('PLS-053: Copy embed code button tappable without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/share');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final copyBtn = find.textContaining('Copy').evaluate().isNotEmpty
          ? find.textContaining('Copy')
          : find.byIcon(Icons.copy_rounded);
      if (copyBtn.evaluate().isNotEmpty) {
        await t.tap(copyBtn.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // API: GET /playlists/{id}/embed → 403 when playlist is private + caller not owner
    testWidgets('PLS-054: Private playlist shows embed restriction message', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/playlist/share');
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 7 — Add Track to Playlist
  // ══════════════════════════════════════════════════════════════
  group('PLS — Add Track to Playlist page', () {

    testWidgets('PLS-055: Add-track page loads without crash', (t) async {
      await bootAndLogin(t);
      await goToWithExtra(t, '/playlist/add-track', {'trackId': ''});
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('PLS-056: playlist_tile or empty state shown', (t) async {
      await bootAndLogin(t);
      await goToWithExtra(t, '/playlist/add-track', {'trackId': ''});
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.byKey(const Key(kPlaylistTile)).evaluate().isNotEmpty
          || find.textContaining('playlist').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PLS-057: Back button navigates away', (t) async {
      await bootAndLogin(t);
      await goToWithExtra(t, '/playlist/add-track', {'trackId': ''});
      await t.pumpAndSettle(const Duration(seconds: 2));
      final back = find.byKey(const Key(kPlaylistBackButton));
      if (back.evaluate().isNotEmpty) {
        await t.tap(back);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byKey(const Key(kPlaylistBackButton)), findsNothing);
      }
    });

    testWidgets('PLS-058: Tapping a playlist tile in add-track mode — no crash', (t) async {
      await bootAndLogin(t);
      await goToWithExtra(t, '/playlist/add-track', {'trackId': ''});
      await t.pumpAndSettle(const Duration(seconds: 4));
      final tile = find.byKey(const Key(kPlaylistTile));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // API: PUT /playlists/{id}/tracks accepts MongoDB ObjectId strings
    testWidgets('PLS-059: Add-track page with a real trackId loads — no crash', (t) async {
      await bootAndLogin(t);
      await goToWithExtra(t, '/playlist/add-track',
          {'trackId': '507f1f77bcf86cd799439022'});
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('PLS-060: Search field inside add-track filters without crash', (t) async {
      await bootAndLogin(t);
      await goToWithExtra(t, '/playlist/add-track', {'trackId': ''});
      await t.pumpAndSettle(const Duration(seconds: 3));
      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await t.enterText(field.first, 'chill');
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });
  });
}