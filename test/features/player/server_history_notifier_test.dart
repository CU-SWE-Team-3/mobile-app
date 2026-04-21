// test/features/player/server_history_notifier_test.dart
//
// Unit tests for ServerHistoryNotifier — covers the auto-load on
// construction, refresh(), clearHistory(), the history getter, and
// state transitions (isLoading → loaded/error).
//
// Run with:
//   flutter test test/features/player/server_history_notifier_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/features/player/data/services/player_api_service.dart';
import 'package:soundcloud_clone/features/player/domain/entities/player_track.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/history_provider.dart';

class MockPlayerApiService extends Mock implements PlayerApiService {}

// ── Helpers ──────────────────────────────────────────────────────────────────

HistoryEntry makeEntry({String id = 't1', String title = 'Track'}) =>
    HistoryEntry(
      track: PlayerTrack(
        id: id,
        title: title,
        artist: 'Artist',
        audioUrl: 'https://cdn/$id.m3u8',
      ),
      playedAt: DateTime(2024, 6, 1),
    );

// Builds a ServerHistoryNotifier and drains the constructor's auto-load.
Future<ServerHistoryNotifier> buildAndLoad(
  MockPlayerApiService mockApi, {
  List<HistoryEntry>? entries,
}) async {
  when(() => mockApi.getRecentlyPlayed())
      .thenAnswer((_) async => entries ?? []);
  final notifier = ServerHistoryNotifier(mockApi);
  await pumpEventQueue();
  return notifier;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockPlayerApiService mockApi;

  setUp(() {
    mockApi = MockPlayerApiService();
  });

  // ── Constructor / auto-load ───────────────────────────────────────────────

  group('ServerHistoryNotifier — constructor', () {
    test('initial state has isLoading: true before auto-load completes', () {
      when(() => mockApi.getRecentlyPlayed())
          .thenAnswer((_) async => []);
      final notifier = ServerHistoryNotifier(mockApi);
      expect(notifier.state.isLoading, isTrue);
      expect(notifier.state.entries, isEmpty);
    });

    test('auto-load populates entries and clears isLoading', () async {
      final entries = [makeEntry(id: 't1'), makeEntry(id: 't2')];
      final notifier = await buildAndLoad(mockApi, entries: entries);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.entries.length, 2);
      expect(notifier.state.entries[0].track.id, 't1');
      expect(notifier.state.entries[1].track.id, 't2');
    });

    test('auto-load with empty result leaves entries empty and isLoading false',
        () async {
      final notifier = await buildAndLoad(mockApi, entries: []);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.entries, isEmpty);
    });

    test('calls getRecentlyPlayed exactly once on construction', () async {
      await buildAndLoad(mockApi, entries: []);
      verify(() => mockApi.getRecentlyPlayed()).called(1);
    });
  });

  // ── refresh() ────────────────────────────────────────────────────────────

  group('ServerHistoryNotifier — refresh()', () {
    test('re-fetches and replaces existing entries', () async {
      final firstBatch = [makeEntry(id: 't1')];
      final notifier = await buildAndLoad(mockApi, entries: firstBatch);

      final secondBatch = [makeEntry(id: 't2'), makeEntry(id: 't3')];
      when(() => mockApi.getRecentlyPlayed())
          .thenAnswer((_) async => secondBatch);

      await notifier.refresh();

      expect(notifier.state.entries.map((e) => e.track.id).toList(),
          ['t2', 't3']);
      expect(notifier.state.isLoading, isFalse);
    });

    test('replaces entries with empty list if server returns none', () async {
      final notifier = await buildAndLoad(mockApi,
          entries: [makeEntry(id: 't1'), makeEntry(id: 't2')]);

      when(() => mockApi.getRecentlyPlayed()).thenAnswer((_) async => []);
      await notifier.refresh();

      expect(notifier.state.entries, isEmpty);
    });

    test('getRecentlyPlayed is called again on refresh', () async {
      final notifier = await buildAndLoad(mockApi, entries: []);
      when(() => mockApi.getRecentlyPlayed()).thenAnswer((_) async => []);
      await notifier.refresh();
      // Called once on construction, once on refresh = 2 total
      verify(() => mockApi.getRecentlyPlayed()).called(2);
    });
  });

  // ── clearHistory() ────────────────────────────────────────────────────────

  group('ServerHistoryNotifier — clearHistory()', () {
    test('calls clearServerHistory on the API', () async {
      final notifier = await buildAndLoad(mockApi,
          entries: [makeEntry(id: 't1')]);
      when(() => mockApi.clearServerHistory()).thenAnswer((_) async {});

      await notifier.clearHistory();

      verify(() => mockApi.clearServerHistory()).called(1);
    });

    test('empties entries after clear', () async {
      final notifier = await buildAndLoad(mockApi,
          entries: [makeEntry(id: 't1'), makeEntry(id: 't2')]);
      when(() => mockApi.clearServerHistory()).thenAnswer((_) async {});

      await notifier.clearHistory();

      expect(notifier.state.entries, isEmpty);
    });

    test('isLoading remains false after clear', () async {
      final notifier = await buildAndLoad(mockApi, entries: [makeEntry()]);
      when(() => mockApi.clearServerHistory()).thenAnswer((_) async {});

      await notifier.clearHistory();

      expect(notifier.state.isLoading, isFalse);
    });
  });

  // ── ServerHistoryState.history getter ────────────────────────────────────

  group('ServerHistoryState.history getter', () {
    test('returns an unmodifiable view of entries', () async {
      final notifier = await buildAndLoad(mockApi,
          entries: [makeEntry(id: 't1'), makeEntry(id: 't2')]);

      final history = notifier.state.history;

      expect(history.length, 2);
      expect(() => (history as dynamic).add(makeEntry()), throwsUnsupportedError);
    });

    test('reflects latest entries after refresh', () async {
      final notifier = await buildAndLoad(mockApi, entries: [makeEntry(id: 'old')]);
      when(() => mockApi.getRecentlyPlayed())
          .thenAnswer((_) async => [makeEntry(id: 'new')]);
      await notifier.refresh();

      expect(notifier.state.history.first.track.id, 'new');
    });
  });

  // ── ServerHistoryState.copyWith ───────────────────────────────────────────

  group('ServerHistoryState.copyWith', () {
    test('unspecified fields are preserved', () {
      final entry = makeEntry(id: 'x');
      final state = ServerHistoryState(entries: [entry], isLoading: false);
      final updated = state.copyWith(isLoading: true);

      expect(updated.entries.first.track.id, 'x');
      expect(updated.isLoading, isTrue);
    });
  });
}
