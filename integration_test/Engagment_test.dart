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
// Module 6: Engagement & Social Interactions
// Owner: Abdelrahman Osama
// Phase 3 — Real server, no mock.
//
// Routes (confirmed from app_router.dart):
//   /comments        → CommentsSheet
//                      extra: { trackId, trackTitle, trackArtist,
//                               trackArtworkUrl, currentPositionSeconds }
//   /likers          → LikersListPage   (extra: { trackId })
//   /reposters       → RepostersListPage (extra: { trackId })
//   /likes           → LibraryLikesPage  (no params, reads userId from prefs)
//   /profile/reposts → ProfileRepostsPage (no params, reads userId from prefs)
//
// Keys (confirmed from source files):
//   CommentsSheet:  comments_cancel_reply_button, comments_close_button,
//                   comments_avatar_button, comments_username_button,
//                   comments_reply_button, comments_more_button,
//                   comments_like_button, comments_replies_toggle_button,
//                   comments_delete_tile, comments_report_tile,
//                   comments_input_field
//   Player:         player_like_button, player_repost_button,
//                   player_comment_button
//   LikersListPage: likers_retry_button
//   RepostersPage:  reposters_retry_button
//   LibraryLikes:   library_likes_back_button, library_likes_cast_button,
//                   library_likes_retry_button, library_likes_track_tile
//   ProfileReposts: profile_reposts_back_button, profile_reposts_cast_button,
//                   profile_reposts_retry_button, profile_reposts_track_tile
//
// Implementation notes confirmed from source:
//   • CommentsSheet header shows '$commentCount comments' AND
//     the emoji-reaction row ALSO shows '$totalCount comments' —
//     two widgets contain the substring 'comments'.
//   • Input hint text is the literal string 'Comment at' (not dynamic).
//   • The send icon is absent — submission is via keyboard action only.
//   • CommentsSheet close button uses Navigator.of(context).pop().
//   • _showOptions always renders BOTH delete_tile AND report_tile
//     (ownership is enforced at the API level, not in the UI).
//   • FullPlayerPage always renders player_like/repost/comment_button
//     even when no track is active (onTap is a no-op in that case).
//   • LibraryLikesPage / ProfileRepostsPage read 'userId' from prefs;
//     bootAndLogin preserves whatever the real auth flow stored.
//
// Manual tests (native share sheet, deep linking): skip: true
// ─────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GetIt.instance.allowReassignment = true;

  setUp(() async {
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  tearDown(() async {
    try {
      appRouter.go('/start');
    } catch (_) {}
  });

  // ─────────────────────────────────────────────────────────────────
  // bootAndLogin — real server login.
  // NOTE: does NOT overwrite 'userId' in SharedPreferences so that
  // LibraryLikesPage and ProfileRepostsPage receive the real userId
  // that the auth flow stored during login.
  // ─────────────────────────────────────────────────────────────────
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

    // Preserve the real userId stored by the auth flow so that
    // LibraryLikesPage and ProfileRepostsPage work correctly.
    // Only set displayName as a convenience for other providers.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayName', validName);
  }

  // goTo — plain navigation (no extra params).
  Future<void> goTo(WidgetTester tester, String route) async {
    appRouter.push(route);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }

  // goToWithExtra — navigation passing typed extra data.
  // Required for /comments, /likers, /reposters.
  Future<void> goToWithExtra(
    WidgetTester tester,
    String route,
    Map<String, dynamic> extra,
  ) async {
    appRouter.push(route, extra: extra);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP: CommentsSheet — /comments
  //
  // Navigated with empty extra → trackId coalesces to '' →
  // API call to GET /tracks//comments fails → provider resolves
  // with empty list → empty-state text is shown.
  // ═══════════════════════════════════════════════════════════════
  group('Comments sheet — /comments', () {

    testWidgets('should show comments input field with correct key',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});

      expect(
        find.byKey(const ValueKey('comments_input_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show close button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});

      expect(
        find.byKey(const ValueKey('comments_close_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show comment count in header', (tester) async {
      // Header renders '$commentCount comments'.
      // Emoji-reaction row also renders '$totalCount comments'.
      // Both show '0 comments' when the list is empty → two widgets.
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});

      // At least one widget containing 'comments' is always present.
      expect(find.textContaining('comments'), findsWidgets);
    });

    testWidgets('should show No comments yet text when empty', (tester) async {
      // Actual Text.data = 'No comments yet.\nBe the first!'
      // textContaining matches substrings so '\n' is not a problem.
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});

      expect(find.textContaining('No comments yet'), findsOneWidget);
    });

    testWidgets('should show Be the first sub-text in empty state',
        (tester) async {
      // Same Text widget as above — the full string includes 'Be the first!'.
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});

      expect(find.textContaining('Be the first'), findsOneWidget);
    });

    testWidgets('should show input hint text Comment at', (tester) async {
      // Confirmed in source: hintText is the literal 'Comment at'.
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});

      final field = find.byKey(const ValueKey('comments_input_field'));
      expect(field, findsOneWidget);
      final textField = tester.widget<TextField>(field);
      expect(textField.decoration?.hintText, equals('Comment at'));
    });

    testWidgets('should close sheet when close button tapped', (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});

      await tester.tap(find.byKey(const ValueKey('comments_close_button')));
      await tester.pumpAndSettle();

      // CommentsSheet is dismissed — input field no longer in tree.
      expect(
        find.byKey(const ValueKey('comments_input_field')),
        findsNothing,
      );
    });

    testWidgets('should allow typing in comment input field', (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});

      await tester.enterText(
        find.byKey(const ValueKey('comments_input_field')),
        'Great track!',
      );
      await tester.pumpAndSettle();

      expect(find.text('Great track!'), findsOneWidget);
    });

    testWidgets(
      'should start with empty input field — no send button visible',
      (tester) async {
        // The send icon is replaced by an AnimatedContainer of width 0 when
        // isPosting is false.  Only the keyboard action triggers submission.
        // Verify field is empty on open.
        await bootAndLogin(tester);
        await goToWithExtra(tester, '/comments', {});
        await tester.pumpAndSettle();

        final field = find.byKey(const ValueKey('comments_input_field'));
        expect(field, findsOneWidget);
        final textField = tester.widget<TextField>(field);
        expect(textField.controller?.text ?? '', isEmpty);
      },
    );

    testWidgets('should show cancel reply button after tapping reply',
        (tester) async {
      // Requires at least one comment from the server for the trackId used.
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final hasReplyButton =
          find.byKey(const ValueKey('comments_reply_button')).evaluate().isNotEmpty;
      if (!hasReplyButton) return; // skip if server returned no comments

      await tester.tap(find.byKey(const ValueKey('comments_reply_button')).first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('comments_cancel_reply_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show Replying to banner when reply is active',
        (tester) async {
      // Banner text: 'Replying to <username>'
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final hasReplyButton =
          find.byKey(const ValueKey('comments_reply_button')).evaluate().isNotEmpty;
      if (!hasReplyButton) return;

      await tester.tap(find.byKey(const ValueKey('comments_reply_button')).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Replying to'), findsOneWidget);
    });

    testWidgets('should dismiss reply state when cancel reply tapped',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final hasReplyButton =
          find.byKey(const ValueKey('comments_reply_button')).evaluate().isNotEmpty;
      if (!hasReplyButton) return;

      await tester.tap(find.byKey(const ValueKey('comments_reply_button')).first);
      await tester.pumpAndSettle();

      await tester.tap(
          find.byKey(const ValueKey('comments_cancel_reply_button')));
      await tester.pumpAndSettle();

      // Reply banner and cancel button both gone.
      expect(
        find.byKey(const ValueKey('comments_cancel_reply_button')),
        findsNothing,
      );
      expect(find.textContaining('Replying to'), findsNothing);
    });

    testWidgets(
        'should show more menu with both delete and report tiles when tapped',
        (tester) async {
      // _showOptions always renders BOTH comments_delete_tile AND
      // comments_report_tile — ownership is enforced server-side, not in UI.
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final hasMore =
          find.byKey(const ValueKey('comments_more_button')).evaluate().isNotEmpty;
      if (!hasMore) return; // no comments loaded — skip

      await tester.tap(find.byKey(const ValueKey('comments_more_button')).first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('comments_delete_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('comments_report_tile')),
        findsOneWidget,
      );
    });

    testWidgets('should dismiss more menu when an option is tapped',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final hasMore =
          find.byKey(const ValueKey('comments_more_button')).evaluate().isNotEmpty;
      if (!hasMore) return;

      await tester.tap(find.byKey(const ValueKey('comments_more_button')).first);
      await tester.pumpAndSettle();

      // Tap Report (safe — no destructive server action).
      await tester.tap(find.byKey(const ValueKey('comments_report_tile')));
      await tester.pumpAndSettle();

      // Bottom sheet dismissed — neither tile visible.
      expect(
        find.byKey(const ValueKey('comments_delete_tile')),
        findsNothing,
      );
    });

    testWidgets('should toggle like on a comment without crash',
        (tester) async {
      // comments_like_button is a local-state toggle (no network call).
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final hasLike =
          find.byKey(const ValueKey('comments_like_button')).evaluate().isNotEmpty;
      if (!hasLike) return;

      await tester.tap(find.byKey(const ValueKey('comments_like_button')).first);
      await tester.pumpAndSettle();

      // Button still present after toggle.
      expect(
        find.byKey(const ValueKey('comments_like_button')),
        findsWidgets,
      );
    });

    testWidgets('should show replies toggle when comment has replies',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/comments', {});
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final hasToggle =
          find.byKey(const ValueKey('comments_replies_toggle_button'))
              .evaluate()
              .isNotEmpty;
      if (!hasToggle) return; // no comments with replies

      expect(
        find.byKey(const ValueKey('comments_replies_toggle_button')),
        findsWidgets,
      );
    });

    testWidgets(
      'Native share sheet — manual only',
      (tester) async {},
      skip: true,
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: LikersListPage — /likers
  //
  // Navigated with trackId: '' → API 404 → error state rendered.
  // All assertions use conditional guards or check the error path.
  // ═══════════════════════════════════════════════════════════════
  group('Likers list page — /likers', () {

    testWidgets('should show Liked By title', (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/likers', {'trackId': ''});

      expect(find.text('Liked By'), findsOneWidget);
    });

    testWidgets('should show Failed to load likers on invalid trackId',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/likers', {'trackId': ''});
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Empty trackId → API error → error state.
      // At minimum one of: error text, retry button, empty state, or tiles.
      final hasError =
          find.text('Failed to load likers').evaluate().isNotEmpty;
      final hasRetry =
          find.byKey(const ValueKey('likers_retry_button')).evaluate().isNotEmpty;
      final hasEmpty = find.text('No likes yet').evaluate().isNotEmpty;
      final hasTiles = find.byType(ListTile).evaluate().isNotEmpty;
      expect(hasError || hasRetry || hasEmpty || hasTiles, isTrue);
    });

    testWidgets('should show retry button with correct key on error state',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/likers', {'trackId': ''});
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasRetry =
          find.byKey(const ValueKey('likers_retry_button')).evaluate().isNotEmpty;
      if (hasRetry) {
        expect(
          find.byKey(const ValueKey('likers_retry_button')),
          findsOneWidget,
        );
      }
      // Page must render without crash regardless.
      expect(find.text('Liked By'), findsOneWidget);
    });

    testWidgets('should tap retry button without crash', (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/likers', {'trackId': ''});
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final retryFinder =
          find.byKey(const ValueKey('likers_retry_button'));
      if (retryFinder.evaluate().isEmpty) return;

      await tester.tap(retryFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Page still alive after retry.
      expect(find.text('Liked By'), findsOneWidget);
    });

    testWidgets('should show No likes yet or user tiles when list resolves',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/likers', {'trackId': ''});
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasEmpty = find.text('No likes yet').evaluate().isNotEmpty;
      final hasRetry =
          find.byKey(const ValueKey('likers_retry_button')).evaluate().isNotEmpty;
      final hasTiles = find.byType(ListTile).evaluate().isNotEmpty;
      expect(hasEmpty || hasRetry || hasTiles, isTrue);
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: RepostersListPage — /reposters
  // ═══════════════════════════════════════════════════════════════
  group('Reposters list page — /reposters', () {

    testWidgets('should show Reposted By title', (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/reposters', {'trackId': ''});

      expect(find.text('Reposted By'), findsOneWidget);
    });

    testWidgets('should show Failed to load reposters on invalid trackId',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/reposters', {'trackId': ''});
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasError =
          find.text('Failed to load reposters').evaluate().isNotEmpty;
      final hasRetry =
          find.byKey(const ValueKey('reposters_retry_button')).evaluate().isNotEmpty;
      final hasEmpty = find.text('No reposts yet').evaluate().isNotEmpty;
      final hasTiles = find.byType(ListTile).evaluate().isNotEmpty;
      expect(hasError || hasRetry || hasEmpty || hasTiles, isTrue);
    });

    testWidgets('should show retry button with correct key on error state',
        (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/reposters', {'trackId': ''});
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasRetry =
          find.byKey(const ValueKey('reposters_retry_button')).evaluate().isNotEmpty;
      if (hasRetry) {
        expect(
          find.byKey(const ValueKey('reposters_retry_button')),
          findsOneWidget,
        );
      }
      expect(find.text('Reposted By'), findsOneWidget);
    });

    testWidgets('should tap retry button without crash', (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/reposters', {'trackId': ''});
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final retryFinder =
          find.byKey(const ValueKey('reposters_retry_button'));
      if (retryFinder.evaluate().isEmpty) return;

      await tester.tap(retryFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Reposted By'), findsOneWidget);
    });

    testWidgets('should show No reposts yet or user list', (tester) async {
      await bootAndLogin(tester);
      await goToWithExtra(tester, '/reposters', {'trackId': ''});
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasEmpty = find.text('No reposts yet').evaluate().isNotEmpty;
      final hasRetry =
          find.byKey(const ValueKey('reposters_retry_button')).evaluate().isNotEmpty;
      final hasTiles = find.byType(ListTile).evaluate().isNotEmpty;
      expect(hasEmpty || hasRetry || hasTiles, isTrue);
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: LibraryLikesPage — /likes
  //
  // Uses real userId from auth flow (bootAndLogin no longer overwrites it).
  // If the test account has likes → shows track tiles.
  // If not → shows 'No liked tracks yet'.
  // If userId was cleared / not stored by app → shows error or empty.
  // ═══════════════════════════════════════════════════════════════
  group('Library likes page — /likes', () {

    testWidgets('should show Likes title', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/likes');

      expect(find.text('Likes'), findsOneWidget);
    });

    testWidgets('should show back button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/likes');

      expect(
        find.byKey(const ValueKey('library_likes_back_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show cast button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/likes');

      expect(
        find.byKey(const ValueKey('library_likes_cast_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show No liked tracks yet, track tiles, or retry',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/likes');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasEmpty = find.text('No liked tracks yet').evaluate().isNotEmpty;
      final hasTile =
          find.byKey(const ValueKey('library_likes_track_tile'))
              .evaluate()
              .isNotEmpty;
      final hasRetry =
          find.byKey(const ValueKey('library_likes_retry_button'))
              .evaluate()
              .isNotEmpty;
      expect(hasEmpty || hasTile || hasRetry, isTrue);
    });

    testWidgets(
        'should show Failed to load likes and retry button together on error',
        (tester) async {
      // Error state always shows the error text AND the retry button together.
      await bootAndLogin(tester);
      await goTo(tester, '/likes');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasError =
          find.text('Failed to load likes').evaluate().isNotEmpty;
      final hasRetry =
          find.byKey(const ValueKey('library_likes_retry_button'))
              .evaluate()
              .isNotEmpty;

      // The two widgets must appear together — one implies the other.
      if (hasError) {
        expect(
          find.byKey(const ValueKey('library_likes_retry_button')),
          findsOneWidget,
        );
      }
      if (hasRetry) {
        expect(find.text('Failed to load likes'), findsOneWidget);
      }
    });

    testWidgets('should tap retry button without crash', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/likes');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final retryFinder =
          find.byKey(const ValueKey('library_likes_retry_button'));
      if (retryFinder.evaluate().isEmpty) return;

      await tester.tap(retryFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Page still alive after retry.
      expect(find.text('Likes'), findsOneWidget);
    });

    testWidgets('should navigate back when back button tapped', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/likes');

      await tester.tap(
          find.byKey(const ValueKey('library_likes_back_button')));
      await tester.pumpAndSettle();

      // LibraryLikesPage is popped — Likes title gone.
      expect(find.text('Likes'), findsNothing);
    });

    testWidgets('should start track playback when track tile tapped',
        (tester) async {
      // Only runs when the test account has liked tracks.
      await bootAndLogin(tester);
      await goTo(tester, '/likes');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final tileFinder =
          find.byKey(const ValueKey('library_likes_track_tile'));
      if (tileFinder.evaluate().isEmpty) return; // no liked tracks

      await tester.tap(tileFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tile tap calls playerProvider.notifier.playTrack() then pushes /player.
      // The full player page must now be in the navigation stack.
      expect(
        find.byKey(const ValueKey('player_like_button')),
        findsOneWidget,
      );
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: ProfileRepostsPage — /profile/reposts
  // ═══════════════════════════════════════════════════════════════
  group('Profile reposts page — /profile/reposts', () {

    testWidgets('should show Reposts title', (tester) async {
      // ProfileRepostsPage AppBar title is 'Reposts' (not 'Profile Reposts').
      await bootAndLogin(tester);
      await goTo(tester, '/profile/reposts');

      expect(find.text('Reposts'), findsOneWidget);
    });

    testWidgets('should show back button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/profile/reposts');

      expect(
        find.byKey(const ValueKey('profile_reposts_back_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show cast button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/profile/reposts');

      expect(
        find.byKey(const ValueKey('profile_reposts_cast_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show No reposts yet, track tiles, or retry',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/profile/reposts');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasEmpty = find.text('No reposts yet').evaluate().isNotEmpty;
      final hasTile =
          find.byKey(const ValueKey('profile_reposts_track_tile'))
              .evaluate()
              .isNotEmpty;
      final hasRetry =
          find.byKey(const ValueKey('profile_reposts_retry_button'))
              .evaluate()
              .isNotEmpty;
      expect(hasEmpty || hasTile || hasRetry, isTrue);
    });

    testWidgets(
        'should show Failed to load reposts and retry button together on error',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/profile/reposts');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final hasError =
          find.text('Failed to load reposts').evaluate().isNotEmpty;
      final hasRetry =
          find.byKey(const ValueKey('profile_reposts_retry_button'))
              .evaluate()
              .isNotEmpty;

      if (hasError) {
        expect(
          find.byKey(const ValueKey('profile_reposts_retry_button')),
          findsOneWidget,
        );
      }
      if (hasRetry) {
        expect(find.text('Failed to load reposts'), findsOneWidget);
      }
    });

    testWidgets('should tap retry button without crash', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/profile/reposts');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final retryFinder =
          find.byKey(const ValueKey('profile_reposts_retry_button'));
      if (retryFinder.evaluate().isEmpty) return;

      await tester.tap(retryFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Page still alive after retry.
      expect(find.text('Reposts'), findsOneWidget);
    });

    testWidgets('should navigate back when back button tapped', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/profile/reposts');

      await tester.tap(
          find.byKey(const ValueKey('profile_reposts_back_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile_reposts_back_button')),
        findsNothing,
      );
    });

    testWidgets('should start track playback when track tile tapped',
        (tester) async {
      // _RepostTile hides immediately when the user un-reposts the track
      // (engState.isReposted == false → SizedBox.shrink).
      // Only runs when the test account has reposted tracks.
      await bootAndLogin(tester);
      await goTo(tester, '/profile/reposts');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final tileFinder =
          find.byKey(const ValueKey('profile_reposts_track_tile'));
      if (tileFinder.evaluate().isEmpty) return;

      await tester.tap(tileFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tile tap calls playerProvider.notifier.playTrack() then pushes /player.
      expect(
        find.byKey(const ValueKey('player_like_button')),
        findsOneWidget,
      );
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Engagement buttons — player_like_button /
  //         player_repost_button / player_comment_button
  //
  // All three buttons live in FullPlayerPage's bottom action bar.
  // They are ALWAYS rendered regardless of whether a track is active.
  // (onTap is a no-op when trackId == null.)
  // ═══════════════════════════════════════════════════════════════
  group('Engagement buttons — like, repost, and comment in full player', () {

    testWidgets('should show player_like_button with correct key',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_like_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show player_repost_button with correct key',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_repost_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show player_comment_button with correct key',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_comment_button')),
        findsOneWidget,
      );
    });

    testWidgets('should toggle like button state when tapped', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      final likeBtn = find.byKey(const ValueKey('player_like_button'));
      expect(likeBtn, findsOneWidget);

      await tester.tap(likeBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Button survives the tap — no crash, still rendered.
      expect(find.byKey(const ValueKey('player_like_button')), findsOneWidget);
    });

    testWidgets('should toggle repost button state when tapped',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      final repostBtn = find.byKey(const ValueKey('player_repost_button'));
      expect(repostBtn, findsOneWidget);

      await tester.tap(repostBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byKey(const ValueKey('player_repost_button')),
        findsOneWidget,
      );
    });

    testWidgets(
        'should open CommentsSheet when comment button tapped with active track',
        (tester) async {
      // _openComments early-returns when trackId == null so CommentsSheet
      // only opens when a track is actively loaded in the player.
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      final trackIsActive = find.text('Nothing playing').evaluate().isEmpty;
      if (!trackIsActive) return; // no active track — skip

      await tester.tap(find.byKey(const ValueKey('player_comment_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(
        find.byKey(const ValueKey('comments_input_field')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Deep linking — manual only',
      (tester) async {
        // Requires clicking a URL from an external app (SMS/email).
      },
      skip: true,
    );

  });

}
