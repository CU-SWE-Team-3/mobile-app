// test/features/player/history_notifier_test.dart
//
// Unit tests for HistoryNotifier — covers initial load from SharedPreferences,
// track recording on player state changes, deduplication (move-to-front),
// the 50-entry FIFO cap, clearHistory(), refresh(), and the recentlyPlayed
// / history getters on HistoryState.
//
// Approach: HistoryNotifier requires a Riverpod Ref for ref.listen(playerProvider).
// We provide a minimal FakeRef that captures the listener callback so tests can
// directly simulate player-state changes without creating a real PlayerNotifier
// (which is untestable due to AudioPlayer tight coupling — see Issues section).
//
// Run with:
//   flutter test test/features/player/history_notifier_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/features/player/data/repositories/history_repository.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/history_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockHistoryRepository extends Mock implements HistoryRepository {}

// ── FakeRef ───────────────────────────────────────────────────────────────────
//
// Minimal Riverpod Ref implementation. HistoryNotifier only calls
// ref.listen(playerProvider, callback) — every other method is intentionally
// left unimplemented (Fake throws UnimplementedError if accidentally called).

// ProviderContainer implements Node (riverpod internals), so it satisfies
// ProviderSubscription's required `source` constructor argument.
// This container is never actually queried for providers.
final _dummyNode = ProviderContainer();

class _NoopSubscription<T> extends ProviderSubscription<T> {
  _NoopSubscription() : super(_dummyNode);

  @override
  T read() => throw UnimplementedError();
}

class FakeRef extends Fake implements Ref {
  void Function(PlayerState?, PlayerState)? _playerListener;

  @override
  ProviderSubscription<T> listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    bool fireImmediately = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    // Capture only the playerProvider listener; ignore anything else.
    _playerListener = listener as void Function(PlayerState?, PlayerState);
    return _NoopSubscription<T>();
  }

  /// Simulate a player state emission (e.g. new track loaded).
  void emitPlayerState(PlayerTrack? track) {
    _playerListener?.call(null, PlayerState(currentTrack: track));
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

PlayerTrack makeTrack({
  String id = 't1',
  String title = 'Song',
  String artist = 'Artist',
}) =>
    PlayerTrack(
      id: id,
      title: title,
      artist: artist,
      audioUrl: 'https://cdn/$id.m3u8',
    );

HistoryEntry makeEntry({String id = 't1', DateTime? playedAt}) => HistoryEntry(
      track: makeTrack(id: id),
      playedAt: playedAt ?? DateTime(2024, 1, 1),
    );

/// Builds a HistoryNotifier backed by [mockRepo] and waits for the
/// constructor's async _loadPersistedHistory() to complete.
Future<({HistoryNotifier notifier, FakeRef fakeRef})> buildAndLoad(
  MockHistoryRepository mockRepo, {
  List<HistoryEntry> initialEntries = const [],
}) async {
  when(() => mockRepo.load()).thenAnswer((_) async => initialEntries);
  when(() => mockRepo.save(any())).thenAnswer((_) async {});
  when(() => mockRepo.clear()).thenAnswer((_) async {});

  final fakeRef = FakeRef();
  final notifier = HistoryNotifier(fakeRef, mockRepo);
  await pumpEventQueue(); // drain _loadPersistedHistory async work
  return (notifier: notifier, fakeRef: fakeRef);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockHistoryRepository mockRepo;

  setUp(() {
    mockRepo = MockHistoryRepository();
  });

  // ── Constructor / initial load ────────────────────────────────────────────

  group('HistoryNotifier — initial load', () {
    test('starts with isLoading: true before async load completes', () {
      when(() => mockRepo.load()).thenAnswer((_) async => []);
      when(() => mockRepo.save(any())).thenAnswer((_) async {});
      final fakeRef = FakeRef();
      final notifier = HistoryNotifier(fakeRef, mockRepo);
      expect(notifier.state.isLoading, isTrue);
    });

    test('populates entries from repo and sets isLoading: false', () async {
      final saved = [makeEntry(id: 'e1'), makeEntry(id: 'e2')];
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo, initialEntries: saved);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.entries.length, 2);
      expect(notifier.state.entries[0].track.id, 'e1');
      expect(notifier.state.entries[1].track.id, 'e2');
    });

    test('leaves entries empty when repo returns nothing', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo);
      expect(notifier.state.entries, isEmpty);
      expect(notifier.state.isLoading, isFalse);
    });
  });

  // ── Track recording (_onCurrentTrackChanged) ──────────────────────────────

  group('HistoryNotifier — track recording', () {
    test('records a track when player emits a new current track', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo);

      fakeRef.emitPlayerState(makeTrack(id: 'new-track'));

      expect(notifier.state.entries.length, 1);
      expect(notifier.state.entries.first.track.id, 'new-track');
    });

    test('null emission is ignored (no entry added)', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo);

      fakeRef.emitPlayerState(null);

      expect(notifier.state.entries, isEmpty);
    });

    test('persists the recorded entry to the repo', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo);
      final track = makeTrack(id: 'persisted');

      fakeRef.emitPlayerState(track);

      // save() should be called with the updated list
      final captured =
          verify(() => mockRepo.save(captureAny())).captured.first
              as List<HistoryEntry>;
      expect(captured.first.track.id, 'persisted');
    });

    test('new track is prepended (most recent first)', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(
        mockRepo,
        initialEntries: [makeEntry(id: 'old')],
      );

      fakeRef.emitPlayerState(makeTrack(id: 'new'));

      expect(notifier.state.entries[0].track.id, 'new');
      expect(notifier.state.entries[1].track.id, 'old');
    });
  });

  // ── Deduplication ─────────────────────────────────────────────────────────

  group('HistoryNotifier — deduplication', () {
    test('same track emitted twice creates only one entry', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo);
      final track = makeTrack(id: 'same');

      fakeRef.emitPlayerState(track);
      fakeRef.emitPlayerState(track); // second emission — same reference

      expect(notifier.state.entries.length, 1);
    });

    test('replaying an existing track moves it to the front', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(
        mockRepo,
        initialEntries: [
          makeEntry(id: 'a'),
          makeEntry(id: 'b'),
          makeEntry(id: 'c'),
        ],
      );

      // Simulate playing 'c' again (already in list)
      fakeRef.emitPlayerState(makeTrack(id: 'c'));

      final ids = notifier.state.entries.map((e) => e.track.id).toList();
      expect(ids[0], 'c'); // moved to front
      expect(ids, containsAll(['a', 'b', 'c']));
      expect(ids.length, 3); // no duplicate
    });

    test('different track IDs each create a separate entry', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo);

      fakeRef.emitPlayerState(makeTrack(id: 'x'));
      fakeRef.emitPlayerState(makeTrack(id: 'y'));

      final ids = notifier.state.entries.map((e) => e.track.id).toList();
      expect(ids, ['y', 'x']); // newest first
    });
  });

  // ── 50-entry cap ──────────────────────────────────────────────────────────

  group('HistoryNotifier — 50-entry cap', () {
    test('does not exceed 50 entries after recording beyond the cap', () async {
      // Pre-load with 50 entries
      final initial = List.generate(50, (i) => makeEntry(id: 'init-$i'));
      final (:notifier, :fakeRef) =
          await buildAndLoad(mockRepo, initialEntries: initial);

      // Adding one more should push the oldest off
      fakeRef.emitPlayerState(makeTrack(id: 'overflow'));

      expect(notifier.state.entries.length, 50);
      expect(notifier.state.entries.first.track.id, 'overflow');
    });
  });

  // ── clearHistory() ────────────────────────────────────────────────────────

  group('HistoryNotifier — clearHistory()', () {
    test('empties entries in state', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(
        mockRepo,
        initialEntries: [makeEntry(id: 'a'), makeEntry(id: 'b')],
      );

      await notifier.clearHistory();

      expect(notifier.state.entries, isEmpty);
    });

    test('calls repo.clear()', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo);
      await notifier.clearHistory();
      verify(() => mockRepo.clear()).called(1);
    });

    test('resets dedup guard so the same track can be re-recorded', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(mockRepo);
      final track = makeTrack(id: 'repeatable');

      fakeRef.emitPlayerState(track); // first play — recorded
      await notifier.clearHistory(); // clear, resets _lastRecorded
      fakeRef.emitPlayerState(track); // second play after clear — should record again

      expect(notifier.state.entries.length, 1);
      expect(notifier.state.entries.first.track.id, 'repeatable');
    });
  });

  // ── refresh() ────────────────────────────────────────────────────────────

  group('HistoryNotifier — refresh()', () {
    test('replaces in-memory entries with latest repo data', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(
        mockRepo,
        initialEntries: [makeEntry(id: 'stale')],
      );

      final fresh = [makeEntry(id: 'fresh-1'), makeEntry(id: 'fresh-2')];
      when(() => mockRepo.load()).thenAnswer((_) async => fresh);

      await notifier.refresh();

      expect(notifier.state.entries.map((e) => e.track.id).toList(),
          ['fresh-1', 'fresh-2']);
    });

    test('clears entries when repo returns empty on refresh', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(
        mockRepo,
        initialEntries: [makeEntry(id: 'old')],
      );
      when(() => mockRepo.load()).thenAnswer((_) async => []);

      await notifier.refresh();

      expect(notifier.state.entries, isEmpty);
    });
  });

  // ── HistoryState getters ──────────────────────────────────────────────────

  group('HistoryState — recentlyPlayed getter', () {
    test('returns up to 20 tracks', () async {
      final entries = List.generate(25, (i) => makeEntry(id: 'e$i'));
      final (:notifier, :fakeRef) =
          await buildAndLoad(mockRepo, initialEntries: entries);

      expect(notifier.state.recentlyPlayed.length, 20);
    });

    test('returns all tracks when fewer than 20 exist', () async {
      final entries = List.generate(5, (i) => makeEntry(id: 'e$i'));
      final (:notifier, :fakeRef) =
          await buildAndLoad(mockRepo, initialEntries: entries);

      expect(notifier.state.recentlyPlayed.length, 5);
    });

    test('preserves insertion order (newest first)', () async {
      final (:notifier, :fakeRef) = await buildAndLoad(
        mockRepo,
        initialEntries: [
          makeEntry(id: 'newest'),
          makeEntry(id: 'oldest'),
        ],
      );

      expect(notifier.state.recentlyPlayed[0].id, 'newest');
      expect(notifier.state.recentlyPlayed[1].id, 'oldest');
    });
  });

  group('HistoryState — history getter', () {
    test('returns full unmodifiable list', () async {
      final entries = List.generate(30, (i) => makeEntry(id: 'e$i'));
      final (:notifier, :fakeRef) =
          await buildAndLoad(mockRepo, initialEntries: entries);

      final history = notifier.state.history;
      expect(history.length, 30);
      expect(
        () => (history as dynamic).add(makeEntry()),
        throwsUnsupportedError,
      );
    });
  });

  // ── HistoryState.copyWith ─────────────────────────────────────────────────

  group('HistoryState.copyWith', () {
    test('unspecified fields are preserved', () {
      final entry = makeEntry(id: 'x');
      final state = HistoryState(entries: [entry], isLoading: false);
      final updated = state.copyWith(isLoading: true);

      expect(updated.entries.first.track.id, 'x');
      expect(updated.isLoading, isTrue);
    });
  });
}
