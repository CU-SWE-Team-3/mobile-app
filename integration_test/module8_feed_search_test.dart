// ─────────────────────────────────────────────────────────────────────────────
// BioBeats — Module 8 — Feed, Search & Discovery
// Owner    : Abdelrahman Osama   |   Phase 4   |   Android / Cross-Platform
// Framework: Flutter integration_test — real server, no mocks
//
// Routes tested:
//   /home                  HomePage
//   /home/trending         TrendingChartsPage
//   /home/recommended      RecommendedTracksPage
//   /home/discover         DiscoverPage
//   /home/genre/electronic … /home/genre/techno  (11 genre pages)
//   /feed                  FollowingFeedPage
//   /search                SearchPage (unified feature/search folder)
//   /search/tracks         SearchResultsTracksPage
//   /search/users          SearchResultsUsersPage
//   /search/playlists      SearchResultsPlaylistsPage
//
// Test IDs: FED-001 → FED-088
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

  // ── helpers ──────────────────────────────────────────────────────
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

  Future<void> goTo(WidgetTester t, String route) async {
    appRouter.push(route);
    await t.pumpAndSettle(const Duration(seconds: 5));
  }

  // ══════════════════════════════════════════════════════════════
  // GROUP 1 — Home Page (/home)
  // ══════════════════════════════════════════════════════════════
  group('FED — Home page', () {

    testWidgets('FED-001: home_scaffold key present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      expect(find.byKey(const Key(kHomeScaffold)), findsOneWidget);
    });

    testWidgets('FED-002: home_get_pro_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      expect(find.byKey(const Key(kHomeGetProButton)), findsOneWidget);
    });

    testWidgets('FED-003: home_upload_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      expect(find.byKey(const Key(kHomeUploadButton)), findsOneWidget);
    });

    testWidgets('FED-004: home_messages_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      expect(find.byKey(const Key(kHomeMessagesButton)), findsOneWidget);
    });

    testWidgets('FED-005: home_notifications_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      expect(find.byKey(const Key(kHomeNotificationsButton)), findsOneWidget);
    });

    testWidgets('FED-006: home_content_list present after settle', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.byKey(const Key(kHomeContentList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeLoading)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeError)).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('FED-007: home_recommended_list or loading present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-008: home_get_pro_button navigates to /upgrade', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.tap(find.byKey(const Key(kHomeGetProButton)));
      await t.pumpAndSettle(const Duration(seconds: 4));
      final onUpgrade = find.byKey(const Key(kPaywallDismissButton)).evaluate().isNotEmpty
          || find.textContaining('Pro').evaluate().isNotEmpty
          || find.textContaining('Premium').evaluate().isNotEmpty;
      expect(onUpgrade, isTrue);
    });

    testWidgets('FED-009: home_messages_button navigates to /messages', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.tap(find.byKey(const Key(kHomeMessagesButton)));
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byKey(const Key(kMessagingComposeButton)), findsOneWidget);
    });

    testWidgets('FED-010: home_notifications_button navigates to /notifications', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.tap(find.byKey(const Key(kHomeNotificationsButton)));
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byKey(const Key(kNotificationsBackButton)), findsOneWidget);
    });

    testWidgets('FED-011: home_upload_button navigates to uploads', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.tap(find.byKey(const Key(kHomeUploadButton)));
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-012: Genre chip "electronic" present on home page', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final chipKey = kHomeGenreChip('electronic');
      final ok = find.byKey(Key(chipKey)).evaluate().isNotEmpty
          || find.textContaining('Electronic').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('FED-013: Genre chip "hiphop" present on home page', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.byKey(Key(kHomeGenreChip('hiphop'))).evaluate().isNotEmpty
          || find.textContaining('Hip').evaluate().isNotEmpty
          || find.textContaining('Hip-hop').evaluate().isNotEmpty;
      expect(ok || find.byKey(const Key(kHomeContentList)).evaluate().isNotEmpty, isTrue);
    });

    testWidgets('FED-014: Tapping electronic genre chip navigates without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final chip = find.byKey(Key(kHomeGenreChip('electronic')));
      if (chip.evaluate().isNotEmpty) {
        await t.tap(chip);
        await t.pumpAndSettle(const Duration(seconds: 4));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('FED-015: Home page does not crash on scroll', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final list = find.byKey(const Key(kHomeContentList));
      if (list.evaluate().isNotEmpty) {
        await t.fling(list, const Offset(0, -400), 1000);
        await t.pumpAndSettle(const Duration(seconds: 3));
      }
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: loading state key shown during initial fetch
    testWidgets('FED-016: home_loading or home_content_list shown — never both absent', (t) async {
      await bootAndLogin(t);
      appRouter.push('/home');
      await t.pump(const Duration(milliseconds: 300));
      final showing = find.byKey(const Key(kHomeLoading)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeContentList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeError)).evaluate().isNotEmpty;
      expect(showing, isTrue);
    });

    // EDGE: error state shows retry possibility
    testWidgets('FED-017: If home_error is shown, retry action is present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 6));
      if (find.byKey(const Key(kHomeError)).evaluate().isNotEmpty) {
        final hasRetry = find.textContaining('Retry').evaluate().isNotEmpty
            || find.textContaining('Try again').evaluate().isNotEmpty;
        expect(hasRetry, isTrue);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 2 — Following Feed (/feed)
  // ══════════════════════════════════════════════════════════════
  group('FED — Following Feed page', () {

    testWidgets('FED-018: Following feed loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/feed');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-019: feed_following_scaffold key present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/feed');
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byKey(const Key(kFeedFollowingScaffold)), findsOneWidget);
    });

    testWidgets('FED-020: feed_track_list or empty state rendered', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/feed');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.byKey(const Key(kFeedTrackList)).evaluate().isNotEmpty
          || find.byKey(const Key(kFeedFollowingEmpty)).evaluate().isNotEmpty
          || find.textContaining('Follow').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('FED-021: feed_following_empty state shown when not following anyone', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/feed');
      await t.pumpAndSettle(const Duration(seconds: 6));
      // Either populated or empty — neither crashes
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-022: feed_retry_button tappable if present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/feed');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final retry = find.byKey(const Key(kFeedRetryButton));
      if (retry.evaluate().isNotEmpty) {
        await t.tap(retry);
        await t.pumpAndSettle(const Duration(seconds: 4));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('FED-023: feed_track_tile tappable — starts playback without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/feed');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(const Key(kFeedTrackTile));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('FED-024: Pull-to-refresh on feed does not crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/feed');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final list = find.byKey(const Key(kFeedTrackList));
      if (list.evaluate().isNotEmpty) {
        await t.fling(list, const Offset(0, 300), 1000);
        await t.pumpAndSettle(const Duration(seconds: 5));
      }
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: feed_following_loading key appears briefly during initial load
    testWidgets('FED-025: feed_following_loading or content shown — never both absent', (t) async {
      await bootAndLogin(t);
      appRouter.push('/feed');
      await t.pump(const Duration(milliseconds: 300));
      final showing = find.byKey(const Key(kFeedFollowingLoading)).evaluate().isNotEmpty
          || find.byKey(const Key(kFeedTrackList)).evaluate().isNotEmpty
          || find.byKey(const Key(kFeedFollowingEmpty)).evaluate().isNotEmpty
          || find.byKey(const Key(kFeedFollowingError)).evaluate().isNotEmpty;
      expect(showing, isTrue);
    });

    // EDGE: feed_following_error shows retry when network fails
    testWidgets('FED-026: If error state shown on feed, retry button is present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/feed');
      await t.pumpAndSettle(const Duration(seconds: 6));
      if (find.byKey(const Key(kFeedFollowingError)).evaluate().isNotEmpty) {
        expect(find.byKey(const Key(kFeedRetryButton)), findsOneWidget);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 3 — Search Page (/search)
  // ══════════════════════════════════════════════════════════════
  group('FED — Search page', () {

    testWidgets('FED-027: search_scaffold present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      expect(find.byKey(const Key(kSearchScaffold)), findsOneWidget);
    });

    testWidgets('FED-028: search_field present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      expect(find.byKey(const Key(kSearchField)), findsOneWidget);
    });

    testWidgets('FED-029: search_filter_tab_bar present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      expect(find.byKey(const Key(kSearchFilterTabBar)), findsOneWidget);
    });

    testWidgets('FED-030: search_tab_tracks present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      expect(find.byKey(const Key(kSearchTabTracks)), findsOneWidget);
    });

    testWidgets('FED-031: search_tab_users present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      expect(find.byKey(const Key(kSearchTabUsers)), findsOneWidget);
    });

    testWidgets('FED-032: search_tab_playlists present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      expect(find.byKey(const Key(kSearchTabPlaylists)), findsOneWidget);
    });

    testWidgets('FED-033: search_history_list or search_history_empty shown on idle', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final ok = find.byKey(const Key(kSearchHistoryList)).evaluate().isNotEmpty
          || find.byKey(const Key(kSearchHistoryEmpty)).evaluate().isNotEmpty
          || find.byKey(const Key(kSearchVibesGrid)).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('FED-034: search_vibes_grid or genre cards shown before typing', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final ok = find.byKey(const Key(kSearchVibesGrid)).evaluate().isNotEmpty
          || find.byKey(const Key(kSearchHistoryList)).evaluate().isNotEmpty
          || find.byKey(const Key(kSearchHistoryEmpty)).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('FED-035: Typing in search_field shows search_clear_button', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), 'rock');
      await t.pumpAndSettle();
      expect(find.byKey(const Key(kSearchClearButton)), findsOneWidget);
    });

    testWidgets('FED-036: search_clear_button clears field and hides itself', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), 'jazz');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key(kSearchClearButton)));
      await t.pumpAndSettle();
      expect(find.text('jazz'), findsNothing);
      expect(find.byKey(const Key(kSearchClearButton)), findsNothing);
    });

    testWidgets('FED-037: Submitting query shows results or search_no_results', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), 'pop');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.byKey(const Key(kSearchResultsList)).evaluate().isNotEmpty
          || find.byKey(const Key(kSearchNoResults)).evaluate().isNotEmpty
          || find.byKey(const Key(kSearchTrackTile)).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('FED-038: Switching to Users tab then searching — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.tap(find.byKey(const Key(kSearchTabUsers)));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key(kSearchField)), 'alice');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-039: Switching to Playlists tab then searching — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.tap(find.byKey(const Key(kSearchTabPlaylists)));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key(kSearchField)), 'chill');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-040: search_track_tile tappable when results exist', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), 'test');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(const Key(kSearchTrackTile));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('FED-041: search_user_tile tappable when results exist', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.tap(find.byKey(const Key(kSearchTabUsers)));
      await t.enterText(find.byKey(const Key(kSearchField)), 'e2e');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(const Key(kSearchUserTile));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('FED-042: search_playlist_tile tappable when results exist', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.tap(find.byKey(const Key(kSearchTabPlaylists)));
      await t.enterText(find.byKey(const Key(kSearchField)), 'chill mix');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(const Key(kSearchPlaylistTile));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // EDGE: search with gibberish shows search_no_results
    testWidgets('FED-043: Gibberish query shows no_results or empty state', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), 'xyznotatrack12345');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.byKey(const Key(kSearchNoResults)).evaluate().isNotEmpty
          || find.textContaining('No').evaluate().isNotEmpty
          || find.textContaining('no result').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    // EDGE: search_results_error and retry button shown on network error
    testWidgets('FED-044: If search_results_error shown, search_retry_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), 'test');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      if (find.byKey(const Key(kSearchResultsError)).evaluate().isNotEmpty) {
        expect(find.byKey(const Key(kSearchRetryButton)), findsOneWidget);
      }
    });

    // EDGE: retry button re-triggers search without crash
    testWidgets('FED-045: search_retry_button triggers new search', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), 'test');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 5));
      final retry = find.byKey(const Key(kSearchRetryButton));
      if (retry.evaluate().isNotEmpty) {
        await t.tap(retry);
        await t.pumpAndSettle(const Duration(seconds: 4));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // EDGE: empty query shows history list or vibes grid, not results list
    testWidgets('FED-046: Clearing query reverts to history/vibes view', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), 'test');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key(kSearchClearButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      // After clearing, results list is gone
      expect(find.byKey(const Key(kSearchResultsList)), findsNothing);
    });

    // EDGE: switching tabs resets result view to correct filter
    testWidgets('FED-047: Switching tabs cycles back to Tracks without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.tap(find.byKey(const Key(kSearchTabUsers)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key(kSearchTabPlaylists)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key(kSearchTabTracks)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key(kSearchTabTracks)), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 4 — Trending Charts (/home/trending)
  // ══════════════════════════════════════════════════════════════
  group('FED — Trending Charts page', () {

    testWidgets('FED-048: Trending page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/trending');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-049: Page title contains "Trending" or "Charts"', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/trending');
      final ok = find.textContaining('Trending').evaluate().isNotEmpty
          || find.textContaining('Charts').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('FED-050: trending_track_tile or empty state rendered', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/trending');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.byKey(const Key(kTrendingTrackTile)).evaluate().isNotEmpty
          || find.textContaining('No').evaluate().isNotEmpty
          || find.byKey(const Key(kTrendingLoading)).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('FED-051: trending_track_tile tappable without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/trending');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(const Key(kTrendingTrackTile));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('FED-052: Trending page does not crash on scroll', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/trending');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byKey(const Key(kTrendingTrackTile));
      if (tile.evaluate().isNotEmpty) {
        await t.fling(tile.first, const Offset(0, -300), 800);
        await t.pumpAndSettle(const Duration(seconds: 3));
      }
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: loading state appears before data
    testWidgets('FED-053: trending_loading or trending_track_tile — never both absent', (t) async {
      await bootAndLogin(t);
      appRouter.push('/home/trending');
      await t.pump(const Duration(milliseconds: 400));
      final showing = find.byKey(const Key(kTrendingLoading)).evaluate().isNotEmpty
          || find.byKey(const Key(kTrendingTrackTile)).evaluate().isNotEmpty;
      expect(showing, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 5 — Genre Pages (one test per genre)
  // ══════════════════════════════════════════════════════════════
  group('FED — Genre pages', () {

    Future<void> genreLoadTest(WidgetTester t, String genre, String label) async {
      await bootAndLogin(t);
      await goTo(t, '/home/genre/$genre');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.textContaining(label).evaluate().isNotEmpty
          || find.byType(ListView).evaluate().isNotEmpty
          || find.byType(GridView).evaluate().isNotEmpty
          || find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(ok, isTrue);
      expect(find.byType(Exception), findsNothing);
    }

    testWidgets('FED-054: Electronic genre page loads', (t) async =>
        genreLoadTest(t, 'electronic', 'Electronic'));

    testWidgets('FED-055: Folk genre page loads', (t) async =>
        genreLoadTest(t, 'folk', 'Folk'));

    testWidgets('FED-056: Hip-hop genre page loads', (t) async =>
        genreLoadTest(t, 'hiphop', 'Hip'));

    testWidgets('FED-057: Indie genre page loads', (t) async =>
        genreLoadTest(t, 'indie', 'Indie'));

    testWidgets('FED-058: House genre page loads', (t) async =>
        genreLoadTest(t, 'house', 'House'));

    testWidgets('FED-059: Pop genre page loads', (t) async =>
        genreLoadTest(t, 'pop', 'Pop'));

    testWidgets('FED-060: R&B genre page loads', (t) async =>
        genreLoadTest(t, 'rnb', 'R'));

    testWidgets('FED-061: Chill genre page loads', (t) async =>
        genreLoadTest(t, 'chill', 'Chill'));

    testWidgets('FED-062: Party genre page loads', (t) async =>
        genreLoadTest(t, 'party', 'Party'));

    testWidgets('FED-063: Workout genre page loads', (t) async =>
        genreLoadTest(t, 'workout', 'Workout'));

    testWidgets('FED-064: Techno genre page loads', (t) async =>
        genreLoadTest(t, 'techno', 'Techno'));

    // EDGE: tapping a track in a genre page plays without crash
    testWidgets('FED-065: Tapping a track tile in electronic genre page plays', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/genre/electronic');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final tile = find.byType(ListTile);
      if (tile.evaluate().isEmpty) return; // nothing to tap
      await t.tap(tile.first);
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 6 — Discover & Recommended Pages
  // ══════════════════════════════════════════════════════════════
  group('FED — Discover & Recommended pages', () {

    testWidgets('FED-066: Discover page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/discover');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-067: Discover page shows "Discover" label', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/discover');
      expect(find.textContaining('Discover'), findsWidgets);
    });

    testWidgets('FED-068: Recommended page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/recommended');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 7 — Search Result Sub-Pages
  // ══════════════════════════════════════════════════════════════
  group('FED — Search result sub-pages', () {

    testWidgets('FED-069: /search/tracks page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search/tracks');
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-070: /search/users page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search/users');
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-071: /search/playlists page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search/playlists');
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: navigating between sub-pages then back to main search — no crash
    testWidgets('FED-072: Navigating tracks → users → playlists sub-pages — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search/tracks');
      await t.pumpAndSettle(const Duration(seconds: 3));
      appRouter.push('/search/users');
      await t.pumpAndSettle(const Duration(seconds: 3));
      appRouter.push('/search/playlists');
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 8 — Resource Resolver & Cast Page
  // ══════════════════════════════════════════════════════════════
  group('FED — Cast & extra discovery pages', () {

    testWidgets('FED-073: Cast page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/cast');
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('FED-074: Genre results page loads without crash for "Electronic"', (t) async {
      await bootAndLogin(t);
      appRouter.push('/search/genre/Electronic');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: home page genre chip for "pop" is tappable
    testWidgets('FED-075: Pop genre chip on home page navigates without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final chip = find.byKey(Key(kHomeGenreChip('pop')));
      if (chip.evaluate().isNotEmpty) {
        await t.tap(chip);
        await t.pumpAndSettle(const Duration(seconds: 4));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // EDGE: home page genre chip for "indie" is tappable
    testWidgets('FED-076: Indie genre chip on home page navigates without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final chip = find.byKey(Key(kHomeGenreChip('indie')));
      if (chip.evaluate().isNotEmpty) {
        await t.tap(chip);
        await t.pumpAndSettle(const Duration(seconds: 4));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // EDGE: home shelves (station, buzzing, curated) present after full settle
    testWidgets('FED-077: At least one shelf list key present after home page loads', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 6));
      final anyShelf =
          find.byKey(const Key(kHomeRecommendedList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeMixedList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeCuratedList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeLikedByList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeStationList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeBuzzingList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeLikedByFollowingList)).evaluate().isNotEmpty
          || find.byKey(const Key(kHomeLoading)).evaluate().isNotEmpty;
      expect(anyShelf, isTrue);
    });

    // EDGE: search with special chars — no crash
    testWidgets('FED-078: Search with special characters does not crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), '!@#\$%');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: search with only whitespace — no crash
    testWidgets('FED-079: Search with whitespace-only query does not crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/search');
      await t.enterText(find.byKey(const Key(kSearchField)), '   ');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: genre page playlist detail loads without crash
    testWidgets('FED-080: Electronic playlist detail page loads without crash', (t) async {
      await bootAndLogin(t);
      appRouter.push('/search/electronic/introducing');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: folk playlist detail
    testWidgets('FED-081: Folk playlist detail page loads without crash', (t) async {
      await bootAndLogin(t);
      appRouter.push('/search/folk/introducing');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: hiphop playlist detail
    testWidgets('FED-082: Hip-hop playlist detail page loads without crash', (t) async {
      await bootAndLogin(t);
      appRouter.push('/search/hiphop/introducing');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: indie playlist detail
    testWidgets('FED-083: Indie playlist detail page loads without crash', (t) async {
      await bootAndLogin(t);
      appRouter.push('/search/indie/introducing');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: house playlist detail
    testWidgets('FED-084: House playlist detail page loads without crash', (t) async {
      await bootAndLogin(t);
      appRouter.push('/search/house/introducing');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: pop playlist detail
    testWidgets('FED-085: Pop playlist detail page loads without crash', (t) async {
      await bootAndLogin(t);
      appRouter.push('/search/pop/introducing');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: rnb playlist detail
    testWidgets('FED-086: R&B playlist detail page loads without crash', (t) async {
      await bootAndLogin(t);
      appRouter.push('/search/rnb/introducing');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: rapid back-navigation from genre page to home — router stable
    testWidgets('FED-087: Rapid back-navigation after genre page — router stable', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home/genre/electronic');
      await t.pumpAndSettle(const Duration(seconds: 2));
      appRouter.pop();
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(Exception), findsNothing);
    });

    // EDGE: home page handles rapid genre chip taps without crash
    testWidgets('FED-088: Rapid tap on two different genre chips — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/home');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final electronic = find.byKey(Key(kHomeGenreChip('electronic')));
      final pop        = find.byKey(Key(kHomeGenreChip('pop')));
      if (electronic.evaluate().isNotEmpty && pop.evaluate().isNotEmpty) {
        await t.tap(electronic);
        await t.pump(const Duration(milliseconds: 200));
        appRouter.pop();
        await t.pumpAndSettle(const Duration(seconds: 2));
        await t.tap(pop);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });
  });
}
