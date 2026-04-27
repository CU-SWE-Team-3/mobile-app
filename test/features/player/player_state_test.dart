// test/features/player/player_state_test.dart
//
// Unit tests for PlayerState — covers initial values, copyWith() (all
// fields + flag overrides), backward-compat getters, and PlayerTrack
// equality semantics.  No platform plugins are involved; all pure Dart.
//
// Run with:
//   flutter test test/features/player/player_state_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

PlayerTrack makeTrack({
  String id = 't1',
  String title = 'Song',
  String artist = 'Artist',
  String audioUrl = 'https://example.com/audio.m3u8',
  String? coverUrl,
  Duration? duration,
  String? artistId,
  String? artistPermalink,
}) =>
    PlayerTrack(
      id: id,
      title: title,
      artist: artist,
      audioUrl: audioUrl,
      coverUrl: coverUrl,
      duration: duration,
      artistId: artistId,
      artistPermalink: artistPermalink,
    );

void main() {
  // ── PlayerTrack ─────────────────────────────────────────────────────────

  group('PlayerTrack equality', () {
    test('two tracks with same id are equal', () {
      final a = makeTrack(id: 'x', title: 'Foo');
      final b = makeTrack(id: 'x', title: 'Bar'); // different title, same id
      expect(a, equals(b));
    });

    test('two tracks with different ids are not equal', () {
      final a = makeTrack(id: 'x');
      final b = makeTrack(id: 'y');
      expect(a, isNot(equals(b)));
    });

    test('hashCode is derived from id', () {
      final a = makeTrack(id: 'abc');
      final b = makeTrack(id: 'abc');
      expect(a.hashCode, b.hashCode);
    });
  });

  // ── PlayerState defaults ─────────────────────────────────────────────────

  group('PlayerState — default values', () {
    test('initial state has sensible defaults', () {
      const s = PlayerState();
      expect(s.currentTrack, isNull);
      expect(s.isPlaying, isFalse);
      expect(s.position, Duration.zero);
      expect(s.duration, Duration.zero);
      expect(s.queue, isEmpty);
      expect(s.currentQueueIndex, 0);
      expect(s.history, isEmpty);
      expect(s.isLoading, isFalse);
      expect(s.error, isNull);
      expect(s.volume, 0.7);
    });
  });

  // ── PlayerState.copyWith ─────────────────────────────────────────────────

  group('PlayerState.copyWith — field updates', () {
    test('updates currentTrack', () {
      const s = PlayerState();
      final track = makeTrack(id: 't1');
      final updated = s.copyWith(currentTrack: track);
      expect(updated.currentTrack, track);
      expect(updated.isPlaying, isFalse); // others unchanged
    });

    test('updates isPlaying', () {
      const s = PlayerState();
      expect(s.copyWith(isPlaying: true).isPlaying, isTrue);
    });

    test('updates position', () {
      const s = PlayerState();
      const pos = Duration(seconds: 45);
      expect(s.copyWith(position: pos).position, pos);
    });

    test('updates duration', () {
      const s = PlayerState();
      const dur = Duration(minutes: 3, seconds: 22);
      expect(s.copyWith(duration: dur).duration, dur);
    });

    test('updates queue', () {
      const s = PlayerState();
      final tracks = [makeTrack(id: 'a'), makeTrack(id: 'b')];
      expect(s.copyWith(queue: tracks).queue, tracks);
    });

    test('updates currentQueueIndex', () {
      const s = PlayerState();
      expect(s.copyWith(currentQueueIndex: 3).currentQueueIndex, 3);
    });

    test('updates history', () {
      const s = PlayerState();
      final hist = [makeTrack(id: 'h1')];
      expect(s.copyWith(history: hist).history, hist);
    });

    test('updates isLoading', () {
      const s = PlayerState();
      expect(s.copyWith(isLoading: true).isLoading, isTrue);
    });

    test('updates error', () {
      const s = PlayerState();
      expect(s.copyWith(error: 'oops').error, 'oops');
    });

    test('updates volume', () {
      const s = PlayerState();
      expect(s.copyWith(volume: 0.5).volume, 0.5);
    });
  });

  group('PlayerState.copyWith — unspecified fields are preserved', () {
    test('all fields survive a single-field update', () {
      final track = makeTrack(id: 'x');
      final full = PlayerState(
        currentTrack: track,
        isPlaying: true,
        position: const Duration(seconds: 10),
        duration: const Duration(minutes: 4),
        queue: [makeTrack(id: 'q1')],
        currentQueueIndex: 2,
        history: [makeTrack(id: 'h1')],
        isLoading: false,
        error: null,
        volume: 0.8,
      );

      final updated = full.copyWith(isPlaying: false);

      expect(updated.currentTrack, track);
      expect(updated.isPlaying, isFalse);
      expect(updated.position, const Duration(seconds: 10));
      expect(updated.duration, const Duration(minutes: 4));
      expect(updated.queue.first.id, 'q1');
      expect(updated.currentQueueIndex, 2);
      expect(updated.history.first.id, 'h1');
      expect(updated.volume, 0.8);
    });
  });

  group('PlayerState.copyWith — flag overrides', () {
    test('clearCurrentTrack: true sets currentTrack to null', () {
      final s = PlayerState(currentTrack: makeTrack(id: 't1'));
      expect(s.copyWith(clearCurrentTrack: true).currentTrack, isNull);
    });

    test('clearCurrentTrack: false preserves existing track', () {
      final track = makeTrack(id: 't1');
      final s = PlayerState(currentTrack: track);
      expect(s.copyWith(clearCurrentTrack: false).currentTrack, track);
    });

    test('clearError: true sets error to null', () {
      const s = PlayerState(error: 'something broke');
      expect(s.copyWith(clearError: true).error, isNull);
    });

    test('clearError: false preserves existing error', () {
      const s = PlayerState(error: 'something broke');
      expect(s.copyWith(clearError: false).error, 'something broke');
    });

    test('passing a new error value overrides the existing one', () {
      const s = PlayerState(error: 'old error');
      expect(s.copyWith(error: 'new error').error, 'new error');
    });
  });

  // ── Backward-compat getters ──────────────────────────────────────────────

  group('PlayerState — backward-compat getters', () {
    test('currentTrackPath returns audioUrl of current track', () {
      final s = PlayerState(
          currentTrack: makeTrack(audioUrl: 'https://cdn.example.com/t.m3u8'));
      expect(s.currentTrackPath, 'https://cdn.example.com/t.m3u8');
    });

    test('currentTrackTitle returns title of current track', () {
      final s = PlayerState(currentTrack: makeTrack(title: 'My Track'));
      expect(s.currentTrackTitle, 'My Track');
    });

    test('currentTrackArtist returns artist of current track', () {
      final s = PlayerState(currentTrack: makeTrack(artist: 'My Artist'));
      expect(s.currentTrackArtist, 'My Artist');
    });

    test('currentTrackArtworkUrl returns coverUrl of current track', () {
      final s = PlayerState(
          currentTrack:
              makeTrack(coverUrl: 'https://cdn.example.com/cover.jpg'));
      expect(s.currentTrackArtworkUrl, 'https://cdn.example.com/cover.jpg');
    });

    test('all getters return null when no track is loaded', () {
      const s = PlayerState();
      expect(s.currentTrackPath, isNull);
      expect(s.currentTrackTitle, isNull);
      expect(s.currentTrackArtist, isNull);
      expect(s.currentTrackArtworkUrl, isNull);
    });
  });

  // ── Volume clamping semantics (expected by setVolume) ────────────────────

  group('PlayerState — volume field stores any double (clamping done in notifier)', () {
    test('volume can be stored as 0.0', () {
      const s = PlayerState(volume: 0.0);
      expect(s.volume, 0.0);
    });

    test('volume can be stored as 1.0', () {
      const s = PlayerState(volume: 1.0);
      expect(s.volume, 1.0);
    });
  });
}
