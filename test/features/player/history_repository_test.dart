// test/features/player/history_repository_test.dart
//
// Unit tests for HistoryRepository — covers load/save/clear using the
// Flutter-provided SharedPreferences mock (no real platform plugin needed).
// Verifies JSON serialization, the 50-entry FIFO cap, roundtrip fidelity,
// and graceful handling of malformed data.
//
// Run with:
//   flutter test test/features/player/history_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/features/player/data/repositories/history_repository.dart';
import 'package:soundcloud_clone/features/player/domain/entities/player_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HistoryRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = HistoryRepository();
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  PlayerTrack makeTrack({
    String id = 't1',
    String title = 'Song',
    String artist = 'Artist',
    String audioUrl = 'https://cdn/t.m3u8',
    String? coverUrl,
    Duration? duration,
    String? artistId,
  }) =>
      PlayerTrack(
        id: id,
        title: title,
        artist: artist,
        audioUrl: audioUrl,
        coverUrl: coverUrl,
        duration: duration,
        artistId: artistId,
      );

  HistoryEntry makeEntry({
    PlayerTrack? track,
    DateTime? playedAt,
  }) =>
      HistoryEntry(
        track: track ?? makeTrack(),
        playedAt: playedAt ?? DateTime(2024, 6, 1, 10, 0),
      );

  // ── load() ────────────────────────────────────────────────────────────────

  group('load()', () {
    test('returns empty list when SharedPreferences has no key', () async {
      final entries = await repo.load();
      expect(entries, isEmpty);
    });

    test('returns empty list when stored value is malformed JSON', () async {
      SharedPreferences.setMockInitialValues({
        'listening_history_v1': '[[[ not valid json',
      });
      final entries = await repo.load();
      expect(entries, isEmpty);
    });

    test('returns empty list when stored value is valid JSON but wrong shape',
        () async {
      SharedPreferences.setMockInitialValues({
        'listening_history_v1': '"just a string"',
      });
      final entries = await repo.load();
      expect(entries, isEmpty);
    });
  });

  // ── save() ────────────────────────────────────────────────────────────────

  group('save()', () {
    test('save then load returns the same entries', () async {
      final entry = makeEntry(
        track: makeTrack(id: 'abc', title: 'My Track', artist: 'Ziad'),
        playedAt: DateTime(2024, 3, 15, 8, 30),
      );

      await repo.save([entry]);
      final loaded = await repo.load();

      expect(loaded.length, 1);
      expect(loaded.first.track.id, 'abc');
      expect(loaded.first.track.title, 'My Track');
      expect(loaded.first.track.artist, 'Ziad');
      expect(loaded.first.playedAt, DateTime(2024, 3, 15, 8, 30));
    });

    test('preserves coverUrl field through roundtrip', () async {
      final entry = makeEntry(
        track: makeTrack(coverUrl: 'https://cdn/cover.jpg'),
      );
      await repo.save([entry]);
      final loaded = await repo.load();
      expect(loaded.first.track.coverUrl, 'https://cdn/cover.jpg');
    });

    test('preserves duration (in milliseconds) through roundtrip', () async {
      final entry = makeEntry(
        track: makeTrack(duration: const Duration(minutes: 3, seconds: 22)),
      );
      await repo.save([entry]);
      final loaded = await repo.load();
      expect(loaded.first.track.duration,
          const Duration(minutes: 3, seconds: 22));
    });

    test('preserves artistId through roundtrip', () async {
      final entry =
          makeEntry(track: makeTrack(artistId: 'artist-uuid-99'));
      await repo.save([entry]);
      final loaded = await repo.load();
      expect(loaded.first.track.artistId, 'artist-uuid-99');
    });

    test('null coverUrl is not stored (key absent after save)', () async {
      final entry = makeEntry(track: makeTrack(coverUrl: null));
      await repo.save([entry]);
      final loaded = await repo.load();
      expect(loaded.first.track.coverUrl, isNull);
    });

    test('caps entries at 50 when saving more than 50', () async {
      // Create 60 entries — save should silently drop the last 10
      final entries = List.generate(
        60,
        (i) => makeEntry(track: makeTrack(id: 'track-$i', title: 'T$i')),
      );

      await repo.save(entries);
      final loaded = await repo.load();

      expect(loaded.length, 50);
      // First entry should be track-0 (FIFO — head is kept)
      expect(loaded.first.track.id, 'track-0');
    });

    test('saves an empty list without error', () async {
      await repo.save([]);
      final loaded = await repo.load();
      expect(loaded, isEmpty);
    });

    test('multiple saves — last write wins', () async {
      await repo.save([makeEntry(track: makeTrack(id: 'first'))]);
      await repo.save([makeEntry(track: makeTrack(id: 'second'))]);
      final loaded = await repo.load();
      expect(loaded.length, 1);
      expect(loaded.first.track.id, 'second');
    });
  });

  // ── clear() ───────────────────────────────────────────────────────────────

  group('clear()', () {
    test('load returns empty list after clear', () async {
      await repo.save([makeEntry()]);
      await repo.clear();
      final loaded = await repo.load();
      expect(loaded, isEmpty);
    });

    test('clear is a no-op when history is already empty', () async {
      await repo.clear();
      final loaded = await repo.load();
      expect(loaded, isEmpty);
    });
  });

  // ── Full roundtrip with multiple entries ──────────────────────────────────

  group('roundtrip — multiple entries', () {
    test('save and load preserves order and count', () async {
      final entries = [
        makeEntry(track: makeTrack(id: 'e1'), playedAt: DateTime(2024, 1, 3)),
        makeEntry(track: makeTrack(id: 'e2'), playedAt: DateTime(2024, 1, 2)),
        makeEntry(track: makeTrack(id: 'e3'), playedAt: DateTime(2024, 1, 1)),
      ];
      await repo.save(entries);
      final loaded = await repo.load();

      expect(loaded.map((e) => e.track.id).toList(), ['e1', 'e2', 'e3']);
    });
  });
}
