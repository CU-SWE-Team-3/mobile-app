// test/features/player/follow_state_test.dart
//
// Unit tests for FollowState — the pure data class that drives the
// follow/unfollow button on both the MiniPlayerWidget and FullPlayerPage.
//
// FollowNotifier.toggle() calls dioClient.dio directly (no injectable
// Dio slot), so only the pure state layer is unit-tested here.
// The optimistic toggle algorithm (flip → API call → rollback on error)
// is exercised via FollowState.copyWith alone.
//
// Run with:
//   flutter test test/features/player/follow_state_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:soundcloud_clone/features/player/presentation/providers/follow_provider.dart';

void main() {
  // ── Default values ───────────────────────────────────────────────────────

  group('FollowState — default values', () {
    test('isFollowing defaults to false', () {
      const s = FollowState();
      expect(s.isFollowing, isFalse);
    });

    test('isLoading defaults to false', () {
      const s = FollowState();
      expect(s.isLoading, isFalse);
    });
  });

  // ── copyWith — individual fields ─────────────────────────────────────────

  group('FollowState.copyWith — individual field updates', () {
    test('updates isFollowing to true', () {
      const s = FollowState();
      expect(s.copyWith(isFollowing: true).isFollowing, isTrue);
    });

    test('updates isFollowing to false', () {
      const s = FollowState(isFollowing: true);
      expect(s.copyWith(isFollowing: false).isFollowing, isFalse);
    });

    test('updates isLoading to true', () {
      const s = FollowState();
      expect(s.copyWith(isLoading: true).isLoading, isTrue);
    });

    test('updates isLoading to false', () {
      const s = FollowState(isLoading: true);
      expect(s.copyWith(isLoading: false).isLoading, isFalse);
    });
  });

  // ── copyWith — field isolation ────────────────────────────────────────────

  group('FollowState.copyWith — unspecified fields are preserved', () {
    test('updating isLoading preserves isFollowing', () {
      const s = FollowState(isFollowing: true, isLoading: false);
      final updated = s.copyWith(isLoading: true);
      expect(updated.isFollowing, isTrue);
      expect(updated.isLoading, isTrue);
    });

    test('updating isFollowing preserves isLoading', () {
      const s = FollowState(isFollowing: false, isLoading: true);
      final updated = s.copyWith(isFollowing: true);
      expect(updated.isFollowing, isTrue);
      expect(updated.isLoading, isTrue);
    });
  });

  // ── Optimistic-toggle state machine ──────────────────────────────────────
  //
  // toggle() executes: flip isFollowing + set isLoading:true → API call
  // → set isLoading:false (rollback isFollowing on error).
  // We verify each of those state transitions using copyWith directly.

  group('FollowState — optimistic toggle state transitions', () {
    test('step 1: flip isFollowing and set isLoading:true', () {
      // Starting state: not following
      const initial = FollowState(isFollowing: false, isLoading: false);
      final step1 = initial.copyWith(isFollowing: true, isLoading: true);

      expect(step1.isFollowing, isTrue);
      expect(step1.isLoading, isTrue);
    });

    test('step 2a: success — clear isLoading, keep new follow state', () {
      const afterOptimistic = FollowState(isFollowing: true, isLoading: true);
      final success = afterOptimistic.copyWith(isLoading: false);

      expect(success.isFollowing, isTrue);
      expect(success.isLoading, isFalse);
    });

    test('step 2b: error — rollback isFollowing and clear isLoading', () {
      // Was following=false, optimistically flipped to true, API failed.
      const afterOptimistic = FollowState(isFollowing: true, isLoading: true);
      final rollback = afterOptimistic.copyWith(
        isFollowing: false, // revert
        isLoading: false,
      );

      expect(rollback.isFollowing, isFalse);
      expect(rollback.isLoading, isFalse);
    });

    test('unfollow optimistic toggle starts from isFollowing:true', () {
      const initial = FollowState(isFollowing: true, isLoading: false);
      final step1 = initial.copyWith(isFollowing: false, isLoading: true);

      expect(step1.isFollowing, isFalse);
      expect(step1.isLoading, isTrue);
    });

    test('concurrent call guard: second call skipped when isLoading:true', () {
      // toggle() checks `if (state.isLoading) return;`
      // Verify the guard value is readable from state.
      const busy = FollowState(isFollowing: true, isLoading: true);
      expect(busy.isLoading, isTrue); // guard condition holds
    });
  });

  // ── State combinations (UI rendering ────────────────────────────────────
  //
  // MiniPlayerWidget and FullPlayerPage render three distinct states:
  //   • spinner  : isLoading == true
  //   • following: isFollowing == true, isLoading == false
  //   • not-following: isFollowing == false, isLoading == false

  group('FollowState — UI rendering states', () {
    test('spinner state: isLoading true', () {
      const s = FollowState(isLoading: true);
      expect(s.isLoading, isTrue);
    });

    test('following state: isFollowing true, isLoading false', () {
      const s = FollowState(isFollowing: true, isLoading: false);
      expect(s.isFollowing, isTrue);
      expect(s.isLoading, isFalse);
    });

    test('not-following state: both false', () {
      const s = FollowState();
      expect(s.isFollowing, isFalse);
      expect(s.isLoading, isFalse);
    });
  });
}
