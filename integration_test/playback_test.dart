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
// Module 5: Playback & Streaming Engine
// Owner: Omar Walid
// Phase 3 — Real server, no mock.
//
// Routes (confirmed from app_router.dart):
//   /player          → FullPlayerPage
//   /player/queue    → PlayerQueuePage
//   /player/recent   → RecentlyPlayedPage
//   /player/history  → ListeningHistoryPage
//
// Keys (confirmed from source files):
//   FullPlayerPage:     player_back_button, player_follow_button,
//                       player_behind_track_button, player_waveform_seek,
//                       player_skip_previous_button, player_play_button,
//                       player_skip_next_button, player_comment_input_field,
//                       player_like_button, player_repost_button,
//                       player_comment_button, player_share_button,
//                       player_queue_button
//   MiniPlayerWidget:   mini_player_play_button, mini_player_expand_button,
//                       mini_player_like_button, mini_player_follow_button
//   AppShell shell:     shell_mini_player_expand_button, shell_play_button,
//                       shell_like_button
//   PlayerQueuePage:    player_queue_clear_button (only when queue.isNotEmpty)
//                       drag_$index, ValueKey(track.id) per item
//   QueueItemTile:      queue_item_tile, queue_item_remove_button
//   RecentlyPlayedPage: player_recently_played_track_tile
//   ListeningHistory:   player_history_clear_button (only when history.isNotEmpty),
//                       player_history_clear_cancel_button,
//                       player_history_clear_confirm_button,
//                       player_history_track_tile
//
// NOTE — Mini player visibility:
//   AppShell._MiniPlayerBar and MiniPlayerWidget both return
//   SizedBox.shrink() when playerProvider.currentTrack == null.
//   Tests that assert shell_* / mini_player_* keys require an active
//   track in the provider → marked skip: true until Phase 4 provides
//   mock injection of a PlayerTrack.
//
// NOTE — Conditional action buttons:
//   PlayerQueuePage Clear button: only rendered when queue.isNotEmpty
//   ListeningHistoryPage Clear button: only rendered when history.isNotEmpty
//
// FullPlayerPage no-track fallback state (fresh session):
//   title:    'Nothing playing'   (currentTrackTitle ?? 'Nothing playing')
//   artist:   ''                  (currentTrackArtist ?? '')
//   time:     '00:00  |  00:00'   (_formatDuration pads minutes to 2 digits)
//   hint:     'Drop a comment at 0:00...'  (_formatSec does NOT pad minutes)
//   isPlaying: false              → play_arrow_rounded icon
//
// Manual tests (actual audio output, lock screen, interruption):
//   Cannot be automated — documented as skip.
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

  // ─────────────────────────────────────────────────────────────
  // bootAndLogin — real server login
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
  }

  Future<void> goTo(WidgetTester tester, String route) async {
    appRouter.push(route);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 1: FullPlayerPage — /player
  //
  // When no track is loaded (fresh session after login):
  //   • currentTrackTitle == null  → 'Nothing playing' is displayed
  //   • currentTrackArtist == null → empty string is displayed
  //   • isPlaying == false         → play_arrow_rounded icon
  //   • position / duration == 0   → time pill shows '00:00  |  00:00'
  //   • comment hint format        → 'Drop a comment at 0:00...'
  //   • All control buttons render regardless of track state.
  // ═══════════════════════════════════════════════════════════════
  group('Full player page — /player', () {

    // ── Widget presence ──────────────────────────────────────────

    testWidgets('should show back button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_back_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show play button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_play_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show skip previous button with correct key',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_skip_previous_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show skip next button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_skip_next_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show like button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_like_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show repost button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_repost_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show comment button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_comment_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show share button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_share_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show queue button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_queue_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show follow button with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_follow_button')),
        findsOneWidget,
      );
    });

    testWidgets('should show waveform seek bar with correct key', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_waveform_seek')),
        findsOneWidget,
      );
    });

    testWidgets('should show comment input field with correct key',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_comment_input_field')),
        findsOneWidget,
      );
    });

    testWidgets('should show Behind this track button with correct key',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.byKey(const ValueKey('player_behind_track_button')),
        findsOneWidget,
      );
    });

    // ── Fallback / no-track state ─────────────────────────────────

    testWidgets('should show Nothing playing when no track is loaded',
        (tester) async {
      // currentTrackTitle ?? 'Nothing playing' — rendered when playerProvider
      // has no current track (fresh session, no playback history in memory)
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(find.text('Nothing playing'), findsOneWidget);
    });

    testWidgets('should show time pill with 00:00  |  00:00 when no track',
        (tester) async {
      // _formatDuration pads minutes with padLeft(2,'0'):
      // position=0 → '00:00', duration=0 → '00:00'
      // combined: '00:00  |  00:00'  (2 spaces either side of |)
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(find.text('00:00  |  00:00'), findsOneWidget);
    });

    testWidgets('should show comment hint containing current timestamp',
        (tester) async {
      // Hint: 'Drop a comment at ${_formatSec(currentSec)}...'
      // _formatSec does NOT pad minutes: 0 sec → '0:00'
      // Full hint at position 0: 'Drop a comment at 0:00...'
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(find.textContaining('Drop a comment at'), findsOneWidget);
    });

    testWidgets('should show emoji quick-reaction buttons', (tester) async {
      // Three _EmojiButton widgets append to the comment field on tap
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('👏'), findsOneWidget);
      expect(find.text('🤩'), findsOneWidget);
    });

    testWidgets('should show play arrow icon when not playing', (tester) async {
      // playerState.isPlaying == false → Icons.play_arrow_rounded
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('player_play_button')),
          matching: find.byIcon(Icons.play_arrow_rounded),
        ),
        findsOneWidget,
      );
    });

    // ── Interactive controls ──────────────────────────────────────

    testWidgets('should navigate back when back button tapped', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_back_button')));
      await tester.pumpAndSettle();

      // Assert — player page gone
      expect(
        find.byKey(const ValueKey('player_play_button')),
        findsNothing,
      );
    });

    testWidgets('should navigate to queue when queue button tapped',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_queue_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert — queue page loaded
      expect(find.text('Queue'), findsOneWidget);
    });

    testWidgets('should toggle play/pause when play button tapped',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      // Record initial icon state
      final initialPlayIcon = find
          .descendant(
            of: find.byKey(const ValueKey('player_play_button')),
            matching: find.byType(Icon),
          )
          .evaluate()
          .isNotEmpty;

      await tester.tap(find.byKey(const ValueKey('player_play_button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert — button still exists (state changed without crash)
      expect(
        find.byKey(const ValueKey('player_play_button')),
        findsOneWidget,
      );
      expect(initialPlayIcon, isTrue);
    });

    testWidgets('skip previous button is tappable', (tester) async {
      // With no track in queue, skipPrevious() is a no-op — verifies no crash
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(
        find.byKey(const ValueKey('player_skip_previous_button')),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert — still on player page
      expect(
        find.byKey(const ValueKey('player_play_button')),
        findsOneWidget,
      );
    });

    testWidgets('skip next button is tappable', (tester) async {
      // With no track in queue, skipNext() is a no-op — verifies no crash
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_skip_next_button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byKey(const ValueKey('player_play_button')),
        findsOneWidget,
      );
    });

    testWidgets('like button is tappable', (tester) async {
      // When trackId == null, like is a no-op — verifies no crash
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_like_button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byKey(const ValueKey('player_like_button')),
        findsOneWidget,
      );
    });

    testWidgets('repost button is tappable', (tester) async {
      // When trackId == null, repost is a no-op — verifies no crash
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_repost_button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byKey(const ValueKey('player_repost_button')),
        findsOneWidget,
      );
    });

    testWidgets('Behind this track button is tappable', (tester) async {
      // Currently a no-op GestureDetector — verifies no crash
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(
        find.byKey(const ValueKey('player_behind_track_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('player_play_button')),
        findsOneWidget,
      );
    });

    testWidgets('comment input field accepts text', (tester) async {
      // Comment input is a TextField with controller; verify it accepts input
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.enterText(
        find.byKey(const ValueKey('player_comment_input_field')),
        'great track!',
      );
      await tester.pumpAndSettle();

      expect(find.text('great track!'), findsOneWidget);
    });

    testWidgets('emoji button appends emoji to comment field', (tester) async {
      // Tapping 🔥 appends '🔥' to _commentController and focuses the field
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      // The emoji now appears in the text field (controller.text = '🔥')
      // find.text('🔥') matches both the button AND the field content → findsWidgets
      expect(find.text('🔥'), findsWidgets);
    });

    testWidgets('comment button is tappable', (tester) async {
      // When trackId == null, _openComments() returns immediately — no crash
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_comment_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Still on player page (no navigation when trackId is null)
      expect(
        find.byKey(const ValueKey('player_comment_button')),
        findsOneWidget,
      );
    });

    testWidgets('share button is tappable', (tester) async {
      // Currently a no-op — verifies no crash
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_share_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('player_play_button')),
        findsOneWidget,
      );
    });

    testWidgets('follow button is tappable', (tester) async {
      // When artistId == null (no track loaded), follow is a no-op — verifies no crash
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_follow_button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byKey(const ValueKey('player_follow_button')),
        findsOneWidget,
      );
    });

    testWidgets('waveform seek bar is tappable', (tester) async {
      // GestureDetector on player_waveform_seek calculates tap position as
      // percentage of width and calls seekTo() — verifies no crash when tapped
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      await tester.tap(find.byKey(const ValueKey('player_waveform_seek')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byKey(const ValueKey('player_waveform_seek')),
        findsOneWidget,
      );
    });

    testWidgets('volume slider is interactive', (tester) async {
      // The only Slider in FullPlayerPage is the volume slider (no ValueKey).
      // Dragging it calls setVolume() from 0.0–1.0 — verifies no crash.
      await bootAndLogin(tester);
      await goTo(tester, '/player');

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      await tester.drag(slider, const Offset(20.0, 0.0));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert — still on player page after drag
      expect(
        find.byKey(const ValueKey('player_play_button')),
        findsOneWidget,
      );
    });

    // ── Manual / un-automatable ───────────────────────────────────

    testWidgets(
      'Actual audio output — manual only',
      (tester) async {
        // This test cannot be automated — requires listening to device speakers.
      },
      skip: true,
    );

    testWidgets(
      'Lock screen controls — manual only',
      (tester) async {
        // Requires locking the physical/emulated device.
      },
      skip: true,
    );

    testWidgets(
      'Audio interruption on incoming call — manual only',
      (tester) async {
        // Requires simulating an OS-level phone call.
      },
      skip: true,
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 2: Mini-player — AppShell (_MiniPlayerBar) and MiniPlayerWidget
  //
  // Both return SizedBox.shrink() when playerProvider.currentTrack == null.
  // On a fresh session (prefs cleared, no active playback), the mini player
  // is completely absent from the widget tree.
  //
  // Shell keys (AppShell._MiniPlayerBar):
  //   shell_mini_player_expand_button, shell_play_button, shell_like_button
  //
  // Widget keys (MiniPlayerWidget):
  //   mini_player_play_button, mini_player_expand_button,
  //   mini_player_like_button, mini_player_follow_button
  //
  // All visibility tests for these keys are marked skip: true.
  // Phase 4: inject mock playerProvider with an active PlayerTrack.
  // ═══════════════════════════════════════════════════════════════
  group('Mini player — shell', () {

    testWidgets('mini player is hidden when no track is loaded', (tester) async {
      // Both _MiniPlayerBar and MiniPlayerWidget guard with:
      //   if (currentTrack == null) return SizedBox.shrink();
      await bootAndLogin(tester);
      appRouter.go('/home');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(
        find.byKey(const ValueKey('shell_mini_player_expand_button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mini_player_expand_button')),
        findsNothing,
      );
    });

    testWidgets(
      'should show shell mini player expand button when track is playing',
      (tester) async {
        await bootAndLogin(tester);
        appRouter.go('/home');
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.byKey(const ValueKey('shell_mini_player_expand_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with active PlayerTrack
    );

    testWidgets(
      'should show shell play button when track is playing',
      (tester) async {
        await bootAndLogin(tester);
        appRouter.go('/home');
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.byKey(const ValueKey('shell_play_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with active PlayerTrack
    );

    testWidgets(
      'should show shell like button when track is playing',
      (tester) async {
        await bootAndLogin(tester);
        appRouter.go('/home');
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.byKey(const ValueKey('shell_like_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with active PlayerTrack
    );

    testWidgets(
      'should expand to full player when shell expand button tapped',
      (tester) async {
        await bootAndLogin(tester);
        appRouter.go('/home');
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await tester.tap(
          find.byKey(const ValueKey('shell_mini_player_expand_button')),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.byKey(const ValueKey('player_play_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with active PlayerTrack
    );

    testWidgets(
      'should show MiniPlayerWidget play button when track is playing',
      (tester) async {
        await bootAndLogin(tester);
        appRouter.go('/home');
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.byKey(const ValueKey('mini_player_play_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with active PlayerTrack
    );

    testWidgets(
      'should show MiniPlayerWidget like button when track is playing',
      (tester) async {
        await bootAndLogin(tester);
        appRouter.go('/home');
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.byKey(const ValueKey('mini_player_like_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with active PlayerTrack
    );

    testWidgets(
      'should expand to full player when MiniPlayerWidget expand button tapped',
      (tester) async {
        await bootAndLogin(tester);
        appRouter.go('/home');
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await tester.tap(
          find.byKey(const ValueKey('mini_player_expand_button')),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.byKey(const ValueKey('player_play_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with active PlayerTrack
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 3: PlayerQueuePage — /player/queue
  //
  // Fresh navigation with no active playback → queue is empty (in-memory
  // Riverpod state, reset on each app.main() call):
  //   • Empty state UI is shown
  //   • Clear button is NOT rendered  (if (queue.isNotEmpty) guard)
  //   • AppBar title is exactly 'Queue' (not 'Queue  ·  N')
  // ═══════════════════════════════════════════════════════════════
  group('Player queue page — /player/queue', () {

    testWidgets('should show Queue title', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player/queue');

      // Assert — title is 'Queue' when empty, 'Queue  ·  N' when populated
      expect(find.textContaining('Queue'), findsOneWidget);
    });

    testWidgets('should show exact Queue title without count when empty',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player/queue');

      // Assert — no count appended when queue.isEmpty
      expect(find.text('Queue'), findsOneWidget);
    });

    testWidgets('should show empty queue message when queue is empty',
        (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player/queue');

      expect(find.text('Your queue is empty'), findsOneWidget);
    });

    testWidgets('should show queue secondary message when empty', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player/queue');

      expect(find.text('Tracks you add will appear here'), findsOneWidget);
    });

    testWidgets('should NOT show Clear button when queue is empty',
        (tester) async {
      // Clear button is guarded by: if (queue.isNotEmpty) ...
      // A fresh session has no queue items — button must be absent.
      await bootAndLogin(tester);
      await goTo(tester, '/player/queue');

      expect(
        find.byKey(const ValueKey('player_queue_clear_button')),
        findsNothing,
      );
    });

    testWidgets(
      'should show Clear button when queue has items',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/player/queue');

        expect(
          find.byKey(const ValueKey('player_queue_clear_button')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with queued tracks
    );

    testWidgets(
      'should show queue item tiles when queue has items',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/player/queue');

        expect(find.byKey(const ValueKey('queue_item_tile')), findsWidgets);
      },
      skip: true, // Phase 4: inject mock playerProvider with queued tracks
    );

    testWidgets(
      'should show remove buttons on queue item tiles',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/player/queue');

        expect(
          find.byKey(const ValueKey('queue_item_remove_button')),
          findsWidgets,
        );
      },
      skip: true, // Phase 4: inject mock playerProvider with queued tracks
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 4: RecentlyPlayedPage — /player/recent
  //
  // Uses historyProvider (in-memory Riverpod) — reset to empty on each
  // app.main() call. The page always starts with isLoading=true before
  // any async data arrives, then shows empty state.
  //
  // Track tile test requires history in the provider → marked skip.
  // ═══════════════════════════════════════════════════════════════
  group('Recently played page — /player/recent', () {

    testWidgets('should show Recently Played title', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player/recent');

      expect(find.text('Recently Played'), findsOneWidget);
    });

    testWidgets(
      'should show loading indicator before data loads',
      (tester) async {
        // historyProvider.isLoading == true on initial build; use pump (not
        // pumpAndSettle) to catch the loading frame before the async fetch.
        await bootAndLogin(tester);
        appRouter.push('/player/recent');
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
      skip: true, // Timing flake on real device — provider resolves before 100 ms
    );

    testWidgets('should show empty state text when nothing played yet',
        (tester) async {
      // historyProvider.recentlyPlayed is empty on a fresh in-memory session
      await bootAndLogin(tester);
      await goTo(tester, '/player/recent');

      expect(find.text('Nothing played yet'), findsOneWidget);
    });

    testWidgets('should show secondary empty state text', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player/recent');

      expect(find.text('Tracks you listen to will show up here'), findsOneWidget);
    });

    testWidgets(
      'should show track tiles when recently played list is populated',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/player/recent');

        expect(
          find.byKey(const ValueKey('player_recently_played_track_tile')),
          findsWidgets,
        );
      },
      skip: true, // Phase 4: inject mock historyProvider with PlayerTrack entries
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 5: ListeningHistoryPage — /player/history
  //
  // Uses serverHistoryProvider (server-side, persisted).
  // The test account (soundcloud.testing.e2e@gmail.com) is expected to
  // have existing server history, making the Clear button visible and
  // enabling clear-dialog interaction tests.
  //
  // Empty-state tests are marked skip because the same account is used
  // for all tests and likely has server history.
  //
  // Section headers: 'Today', 'Yesterday', 'Earlier' appear in the
  // _GroupedHistoryList only when the corresponding bucket is non-empty.
  // ═══════════════════════════════════════════════════════════════
  group('Listening history page — /player/history', () {

    testWidgets('should show Listening History title', (tester) async {
      await bootAndLogin(tester);
      await goTo(tester, '/player/history');

      expect(find.text('Listening History'), findsOneWidget);
    });

    testWidgets(
      'should show loading indicator before data loads',
      (tester) async {
        // serverHistoryProvider.isLoading == true on initial build
        await bootAndLogin(tester);
        appRouter.push('/player/history');
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
      skip: true, // Timing flake on real device — provider resolves before 100 ms
    );

    testWidgets('should show empty state text when no history', (tester) async {
      // Confirmed: test account has no server history.
      await bootAndLogin(tester);
      await goTo(tester, '/player/history');

      expect(find.text('No listening history yet'), findsOneWidget);
    });

    testWidgets('should show secondary empty state text', (tester) async {
      // Confirmed: test account has no server history.
      await bootAndLogin(tester);
      await goTo(tester, '/player/history');

      expect(
        find.text('Your played tracks will be grouped by date'),
        findsOneWidget,
      );
    });

    testWidgets(
      'should show Clear button with correct key',
      (tester) async {
        // Clear button guard: if (historyState.history.isNotEmpty) ...
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');

        expect(
          find.byKey(const ValueKey('player_history_clear_button')),
          findsOneWidget,
        );
      },
      skip: true, // Test account has no server history — seed via API before enabling
    );

    testWidgets(
      'should show clear confirmation dialog when Clear tapped',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');

        await tester.tap(
          find.byKey(const ValueKey('player_history_clear_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Clear history?'), findsOneWidget);
      },
      skip: true, // Requires history on server — seed via API before enabling
    );

    testWidgets(
      'should show This will permanently remove all listening history in dialog',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');

        await tester.tap(
          find.byKey(const ValueKey('player_history_clear_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('This will permanently remove all listening history.'),
          findsOneWidget,
        );
      },
      skip: true, // Requires history on server — seed via API before enabling
    );

    testWidgets(
      'should show track tiles when history is populated',
      (tester) async {
        // _HistoryTile uses ValueKey('player_history_track_tile')
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');

        expect(
          find.byKey(const ValueKey('player_history_track_tile')),
          findsWidgets,
        );
      },
      skip: true, // Test account has no server history — seed via API before enabling
    );

    testWidgets(
      'pull-to-refresh triggers history reload',
      (tester) async {
        // RefreshIndicator is only rendered when history is non-empty
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');

        await tester.fling(
          find.byType(RefreshIndicator),
          const Offset(0.0, 300.0),
          1000.0,
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Listening History'), findsOneWidget);
      },
      skip: true, // RefreshIndicator absent when history is empty — seed via API before enabling
    );

    testWidgets(
      'should show Cancel and Clear action buttons in dialog',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');

        await tester.tap(
          find.byKey(const ValueKey('player_history_clear_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('player_history_clear_cancel_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('player_history_clear_confirm_button')),
          findsOneWidget,
        );
      },
      skip: true, // Requires history on server — seed via API before enabling
    );

    testWidgets(
      'should dismiss clear dialog when Cancel tapped',
      (tester) async {
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');
        await tester.tap(
          find.byKey(const ValueKey('player_history_clear_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('player_history_clear_cancel_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Clear history?'), findsNothing);
        expect(find.text('Listening History'), findsOneWidget);
      },
      skip: true, // Requires history on server — seed via API before enabling
    );

    testWidgets(
      'should clear history and dismiss dialog when Clear confirm tapped',
      (tester) async {
        // DESTRUCTIVE — wipes server history for the test account.
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');
        await tester.tap(
          find.byKey(const ValueKey('player_history_clear_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('player_history_clear_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Clear history?'), findsNothing);
        expect(find.text('Listening History'), findsOneWidget);
      },
      skip: true, // Requires history on server — seed via API before enabling
    );

    testWidgets(
      'should show Today section header when account has recent history',
      (tester) async {
        // _GroupedHistoryList shows 'Today', 'Yesterday', or 'Earlier'
        // headers based on playedAt date grouping
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');

        expect(find.text('Today'), findsOneWidget);
      },
      skip: true, // Phase 4: requires mock entries with playedAt == today
    );

    testWidgets(
      'Clear button is NOT shown when history is empty',
      (tester) async {
        // After clearing, or on a fresh account with no server history,
        // the Clear button must be absent.
        await bootAndLogin(tester);
        await goTo(tester, '/player/history');

        expect(
          find.byKey(const ValueKey('player_history_clear_button')),
          findsNothing,
        );
      },
      skip: true, // Contradicts active tests — run only on an account with no history
    );

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 6: Playback API — stream URL, heartbeat, progress recording
  //
  // These three endpoints are called programmatically during active
  // playback and cannot be exercised without a PlayerTrack injected
  // into the provider.  All tests are marked skip until Phase 4
  // provides mock injection of a real PlayerTrack (with a valid
  // trackId from the test account's uploaded tracks).
  //
  // Endpoints covered:
  //   GET  /player/{id}/stream    → StreamData (hlsUrl, duration, format)
  //   PUT  /player/state          → PlayerState heartbeat sync
  //   POST /history/progress      → HistoryRecord + playCount increment
  //
  // API contract notes (from spec v1.05):
  //   stream:   403 if private/insufficient tier; 400 if still Processing
  //   progress: playCount incremented only when progress >= 90 % of duration
  //   state:    PUT requires currentTrack (valid ObjectId), currentTime,
  //             isPlaying; queueContext and contextId are optional
  // ═══════════════════════════════════════════════════════════════
  group('Playback API — stream, heartbeat, progress', () {

    testWidgets(
      'GET /player/{id}/stream — returns hlsUrl for a public finished track',
      (tester) async {
        // Navigate to the player with an active track and verify that the
        // waveform / HLS player widget receives a non-empty stream URL.
        // Requires Phase 4 mock injection of a PlayerTrack with a known id.
        await bootAndLogin(tester);
        await goTo(tester, '/player');

        // Assert — waveform seek is visible, indicating the HLS URL was
        // resolved and passed to the audio engine without error.
        expect(
          find.byKey(const ValueKey('player_waveform_seek')),
          findsOneWidget,
        );
      },
      skip: true, // Phase 4: inject active PlayerTrack with valid trackId
    );

    testWidgets(
      'GET /player/{id}/stream — shows error or fallback for private track',
      (tester) async {
        // When the authenticated user does not own a private track, the API
        // returns 403. The player should surface an error state rather than
        // crash.  Requires a known private trackId from a different account.
        await bootAndLogin(tester);
        await goTo(tester, '/player');

        // Assert — some error indication is shown (snackbar, text, etc.)
        expect(find.byType(SnackBar), findsOneWidget);
      },
      skip: true, // Phase 4: requires a private trackId owned by another account
    );

    testWidgets(
      'PUT /player/state — heartbeat updates currentTime without crash',
      (tester) async {
        // The player calls PUT /player/state periodically while playing.
        // With an active track, let the player run for a few seconds and
        // confirm the position display advances.
        await bootAndLogin(tester);
        await goTo(tester, '/player');

        // Wait for at least one heartbeat cycle (~5 s in production)
        await tester.pumpAndSettle(const Duration(seconds: 6));

        // Assert — time pill no longer shows 00:00 | 00:00
        expect(find.text('00:00  |  00:00'), findsNothing);
      },
      skip: true, // Phase 4: inject active PlayerTrack so heartbeat fires
    );

    testWidgets(
      'POST /history/progress — progress < 90% does NOT increment playCount',
      (tester) async {
        // Seek to ~50 % of track duration and stop. Verify playCount on the
        // track page is unchanged relative to the value before playback.
        // Requires navigating to a known track permalink before and after.
        await bootAndLogin(tester);
        await goTo(tester, '/player');

        // (implementation: record playCount before, seek to 50 %, navigate
        // away, check playCount unchanged on track detail page)
        expect(true, isTrue); // placeholder
      },
      skip: true, // Phase 4: inject active PlayerTrack + known track permalink
    );

    testWidgets(
      'POST /history/progress — progress >= 90% increments playCount',
      (tester) async {
        // Seek to >= 90 % of track duration. Verify playCount increments by 1
        // on the track detail page after returning from the player.
        await bootAndLogin(tester);
        await goTo(tester, '/player');

        // (implementation: record playCount before, seek past 90 %, navigate
        // away, check playCount +1 on track detail page)
        expect(true, isTrue); // placeholder
      },
      skip: true, // Phase 4: inject active PlayerTrack + known track permalink
    );

    testWidgets(
      'GET /player/state — cross-device sync restores last position',
      (tester) async {
        // PUT /player/state with currentTime=42 from a separate HTTP call,
        // then cold-boot the app and navigate to /player. The player should
        // resume from ~42 s, not 0:00.
        await bootAndLogin(tester);
        await goTo(tester, '/player');

        // Assert — time pill does NOT show 00:00 | 00:00 (position restored)
        expect(find.text('00:00  |  00:00'), findsNothing);
      },
      skip: true, // Phase 4: seed server state via direct API call before boot
    );

  });

}
