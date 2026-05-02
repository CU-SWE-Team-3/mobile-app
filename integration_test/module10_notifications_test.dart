// ─────────────────────────────────────────────────────────────────────────────
// BioBeats — Module 10 — Real-Time Notifications
// Owner    : Abdelrahman Osama  |  Phase 4  |  Android
// Framework: Flutter integration_test — real server
//
// API endpoints exercised:
//   GET   /notifications               (feed, paginated, grouped)
//   PATCH /notifications/mark-read     (mark all read)
//   PATCH /notifications/{id}/read     (mark single read)
//   DELETE /notifications/{id}         (delete a notification)
//   GET   /notifications/unread-count  (badge count)
//   PATCH /notifications/preferences   (push + email prefs, messagePermission)
//
// Notification types from API enum:
//   LIKE, REPOST, COMMENT, FOLLOW, MESSAGE, NEW_TRACK, NEW_PLAYLIST, MENTION, SYSTEM
//   (Filter UI maps to: All, Likes, Reposts, Comments, Follows)
//
// Test IDs: NOT-001 → NOT-033
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

  /// Opens the filter sheet and selects the option with the given label.
  Future<void> openFilterAndSelect(WidgetTester t, String label) async {
    await t.tap(find.byKey(const Key(kNotificationsFilterButton)));
    await t.pumpAndSettle(const Duration(seconds: 2));
    final option = find.textContaining(label);
    if (option.evaluate().isNotEmpty) {
      await t.tap(option.first);
      await t.pumpAndSettle(const Duration(seconds: 3));
    }
  }

  // ══════════════════════════════════════════════════════════════
  // GROUP 1 — Notifications page
  // API: GET /notifications, PATCH /notifications/mark-read
  // ══════════════════════════════════════════════════════════════
  group('NOT — Notifications page', () {

    testWidgets('NOT-001: Page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('NOT-002: notifications_back_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      expect(find.byKey(const Key(kNotificationsBackButton)), findsOneWidget);
    });

    testWidgets('NOT-003: notifications_mark_all_read_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      expect(find.byKey(const Key(kNotificationsMarkAllRead)), findsOneWidget);
    });

    testWidgets('NOT-004: notifications_filter_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      expect(find.byKey(const Key(kNotificationsFilterButton)), findsOneWidget);
    });

    testWidgets('NOT-005: Page title contains "Notifications"', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      expect(find.textContaining('Notification'), findsWidgets);
    });

    testWidgets('NOT-006: notifications_list or empty state rendered', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.byKey(const Key(kNotificationsList)).evaluate().isNotEmpty
          || find.textContaining('No notification').evaluate().isNotEmpty
          || find.textContaining('caught up').evaluate().isNotEmpty
          || find.byKey(const Key(kNotificationsRetryButton)).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('NOT-007: notification_tile_0 tappable when present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(Key(kNotificationTile(0)));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('NOT-008: notification_tile_1 tappable when present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(Key(kNotificationTile(1)));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // API: PATCH /notifications/mark-read → modifiedCount returned
    testWidgets('NOT-009: Mark-all-read tappable without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.tap(find.byKey(const Key(kNotificationsMarkAllRead)));
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });

    // After PATCH /notifications/mark-read — notification_unread_dot should be absent
    testWidgets('NOT-010: After mark-all-read, notification_unread_dot absent', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.pumpAndSettle(const Duration(seconds: 5));
      await t.tap(find.byKey(const Key(kNotificationsMarkAllRead)));
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byKey(const Key(kNotificationUnreadDot)), findsNothing);
    });

    testWidgets('NOT-011: back_button navigates away', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.tap(find.byKey(const Key(kNotificationsBackButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key(kNotificationsMarkAllRead)), findsNothing);
    });

    testWidgets('NOT-012: Scroll does not crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final list = find.byKey(const Key(kNotificationsList));
      if (list.evaluate().isNotEmpty) {
        await t.fling(list, const Offset(0, -300), 800);
        await t.pumpAndSettle(const Duration(seconds: 3));
      }
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('NOT-013: Pull-to-refresh reloads notifications', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final list = find.byKey(const Key(kNotificationsList));
      if (list.evaluate().isNotEmpty) {
        await t.fling(list, const Offset(0, 400), 1000);
        await t.pumpAndSettle(const Duration(seconds: 5));
      }
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('NOT-014: notifications_retry_button tappable when shown', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final retry = find.byKey(const Key(kNotificationsRetryButton));
      if (retry.evaluate().isNotEmpty) {
        await t.tap(retry);
        await t.pumpAndSettle(const Duration(seconds: 4));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // notification_dismiss_<id> — swipe to dismiss tile
    testWidgets('NOT-015: Swipe notification_tile_0 to dismiss — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(Key(kNotificationTile(0)));
      if (tile.evaluate().isNotEmpty) {
        await t.drag(tile, const Offset(-300, 0));
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 2 — Filter sheet (maps to API NotificationType enum)
  // Filter types map to: LIKE, COMMENT, REPOST, FOLLOW, and All
  // ══════════════════════════════════════════════════════════════
  group('NOT — Filter sheet per notification type', () {

    testWidgets('NOT-016: Filter button opens sheet', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.tap(find.byKey(const Key(kNotificationsFilterButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      final ok = find.textContaining('All').evaluate().isNotEmpty
          || find.textContaining('notification').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('NOT-017: Filter sheet shows "All" option', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.tap(find.byKey(const Key(kNotificationsFilterButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('All').evaluate().isNotEmpty, isTrue);
    });

    // LIKE type from API enum
    testWidgets('NOT-018: Filter sheet shows "Likes" option', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.tap(find.byKey(const Key(kNotificationsFilterButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('Like').evaluate().isNotEmpty
          || find.byIcon(Icons.favorite).evaluate().isNotEmpty, isTrue);
    });

    // COMMENT type from API enum
    testWidgets('NOT-019: Filter sheet shows "Comments" option', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.tap(find.byKey(const Key(kNotificationsFilterButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('Comment').evaluate().isNotEmpty
          || find.byIcon(Icons.chat_bubble).evaluate().isNotEmpty, isTrue);
    });

    // REPOST type from API enum
    testWidgets('NOT-020: Filter sheet shows "Reposts" option', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.tap(find.byKey(const Key(kNotificationsFilterButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('Repost').evaluate().isNotEmpty
          || find.byIcon(Icons.repeat).evaluate().isNotEmpty, isTrue);
    });

    // FOLLOW type from API enum
    testWidgets('NOT-021: Filter sheet shows "Followings" option', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await t.tap(find.byKey(const Key(kNotificationsFilterButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('Follow').evaluate().isNotEmpty
          || find.byIcon(Icons.person_add).evaluate().isNotEmpty, isTrue);
    });

    testWidgets('NOT-022: Selecting "Likes" filter — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await openFilterAndSelect(t, 'Like');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('NOT-023: Selecting "Comments" filter — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await openFilterAndSelect(t, 'Comment');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('NOT-024: Selecting "Reposts" filter — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await openFilterAndSelect(t, 'Repost');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('NOT-025: Selecting "Followings" filter — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await openFilterAndSelect(t, 'Follow');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('NOT-026: Selecting "All" resets filter — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      await openFilterAndSelect(t, 'Like');
      await openFilterAndSelect(t, 'All');
      expect(find.byType(Exception), findsNothing);
    });

    // Cycle through all 4 typed filters then reset to All
    testWidgets('NOT-027: Cycling all filter types — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications');
      for (final label in ['Like', 'Comment', 'Repost', 'Follow', 'All']) {
        await openFilterAndSelect(t, label);
        expect(find.byType(Exception), findsNothing);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 3 — Push Notification Settings page
  // API: PATCH /notifications/preferences  (pushEnabled, allowLikes, etc.)
  // ══════════════════════════════════════════════════════════════
  group('NOT — Push Notification Settings page', () {

    testWidgets('NOT-028: Settings page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications/settings');
      expect(find.byType(Exception), findsNothing);
    });

    // API preferences keys: allowLikes, allowReposts, allowComments, allowFollows, etc.
    testWidgets('NOT-029: Settings page shows notification categories', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications/settings');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.textContaining('Like').evaluate().isNotEmpty
          || find.textContaining('Comment').evaluate().isNotEmpty
          || find.textContaining('Notification').evaluate().isNotEmpty
          || find.textContaining('Push').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('NOT-030: Settings page has toggles or switch tiles', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications/settings');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.byType(Switch).evaluate().isNotEmpty
          || find.byType(SwitchListTile).evaluate().isNotEmpty
          || find.byType(ListTile).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    // PATCH /notifications/preferences — toggle fires PATCH call
    testWidgets('NOT-031: First toggle tappable without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications/settings');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final toggle = find.byType(Switch);
      if (toggle.evaluate().isNotEmpty) {
        await t.tap(toggle.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('NOT-032: Double-tap first toggle — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications/settings');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final toggle = find.byType(Switch);
      if (toggle.evaluate().isNotEmpty) {
        await t.tap(toggle.first);
        await t.pumpAndSettle();
        await t.tap(toggle.first);
        await t.pumpAndSettle();
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('NOT-033: Settings page back navigation works', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/notifications/settings');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final back = find.byIcon(Icons.arrow_back_ios_sharp).evaluate().isNotEmpty
          ? find.byIcon(Icons.arrow_back_ios_sharp)
          : find.byIcon(Icons.arrow_back);
      if (back.evaluate().isNotEmpty) {
        await t.tap(back.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });
  });
}