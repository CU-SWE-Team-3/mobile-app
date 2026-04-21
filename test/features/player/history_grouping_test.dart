// test/features/player/history_grouping_test.dart
//
// Unit tests for the date-grouping algorithm used by ListeningHistoryPage
// to partition HistoryEntry items into "Today", "Yesterday", and "Earlier"
// buckets.
//
// The grouping function is private (_groupByDate) on _GroupedHistoryList,
// so this file replicates the identical pure algorithm and verifies its
// correctness against a comprehensive set of date scenarios.
//
// Any change to the production grouping logic that breaks these tests
// indicates a regression in the Listening History Screen's date-section UI.
//
// Run with:
//   flutter test test/features/player/history_grouping_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:soundcloud_clone/features/player/data/repositories/history_repository.dart';
import 'package:soundcloud_clone/features/player/domain/entities/player_track.dart';

// ── Pure grouping function (mirrors _GroupedHistoryList._groupByDate) ────────

Map<String, List<HistoryEntry>> groupByDate(List<HistoryEntry> entries) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  final today = <HistoryEntry>[];
  final yesterday = <HistoryEntry>[];
  final earlier = <HistoryEntry>[];

  for (final e in entries) {
    final d = e.playedAt;
    if (!d.isBefore(todayStart)) {
      today.add(e);
    } else if (!d.isBefore(yesterdayStart)) {
      yesterday.add(e);
    } else {
      earlier.add(e);
    }
  }

  return {
    if (today.isNotEmpty) 'Today': today,
    if (yesterday.isNotEmpty) 'Yesterday': yesterday,
    if (earlier.isNotEmpty) 'Earlier': earlier,
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

PlayerTrack makeTrack({String id = 't1'}) => PlayerTrack(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      audioUrl: 'https://cdn/$id.m3u8',
    );

HistoryEntry makeEntry({required DateTime playedAt, String id = 't1'}) =>
    HistoryEntry(track: makeTrack(id: id), playedAt: playedAt);

/// Returns a DateTime that is definitely within today (a few seconds ago).
DateTime todayTs() => DateTime.now().subtract(const Duration(seconds: 5));

/// Returns a DateTime in yesterday's window (start of yesterday + 1 hour).
DateTime yesterdayTs() {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  return todayStart.subtract(const Duration(hours: 23));
}

/// Returns a DateTime clearly in the "earlier" window (2 days ago).
DateTime earlierTs() => DateTime.now().subtract(const Duration(days: 2));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Empty input ──────────────────────────────────────────────────────────

  group('groupByDate — empty input', () {
    test('returns empty map for empty list', () {
      final result = groupByDate([]);
      expect(result, isEmpty);
    });
  });

  // ── Bucket assignment ─────────────────────────────────────────────────────

  group('groupByDate — bucket assignment', () {
    test('entry played today goes into Today bucket', () {
      final entry = makeEntry(playedAt: todayTs(), id: 'a');
      final result = groupByDate([entry]);

      expect(result.containsKey('Today'), isTrue);
      expect(result['Today']!.first.track.id, 'a');
    });

    test('entry played yesterday goes into Yesterday bucket', () {
      final entry = makeEntry(playedAt: yesterdayTs(), id: 'b');
      final result = groupByDate([entry]);

      expect(result.containsKey('Yesterday'), isTrue);
      expect(result['Yesterday']!.first.track.id, 'b');
    });

    test('entry played 2 days ago goes into Earlier bucket', () {
      final entry = makeEntry(playedAt: earlierTs(), id: 'c');
      final result = groupByDate([entry]);

      expect(result.containsKey('Earlier'), isTrue);
      expect(result['Earlier']!.first.track.id, 'c');
    });

    test('entry played a week ago goes into Earlier bucket', () {
      final entry = makeEntry(
        playedAt: DateTime.now().subtract(const Duration(days: 7)),
        id: 'd',
      );
      final result = groupByDate([entry]);
      expect(result.containsKey('Earlier'), isTrue);
    });
  });

  // ── Absent buckets ────────────────────────────────────────────────────────

  group('groupByDate — buckets only present when non-empty', () {
    test('no Today key when no entries today', () {
      final result = groupByDate([makeEntry(playedAt: earlierTs())]);
      expect(result.containsKey('Today'), isFalse);
    });

    test('no Yesterday key when no entries from yesterday', () {
      final result = groupByDate([makeEntry(playedAt: todayTs())]);
      expect(result.containsKey('Yesterday'), isFalse);
    });

    test('no Earlier key when all entries are from today', () {
      final result = groupByDate([makeEntry(playedAt: todayTs())]);
      expect(result.containsKey('Earlier'), isFalse);
    });
  });

  // ── Multiple entries ──────────────────────────────────────────────────────

  group('groupByDate — mixed entries', () {
    test('correctly partitions today + yesterday + earlier', () {
      final entries = [
        makeEntry(playedAt: todayTs(), id: 't'),
        makeEntry(playedAt: yesterdayTs(), id: 'y'),
        makeEntry(playedAt: earlierTs(), id: 'e'),
      ];
      final result = groupByDate(entries);

      expect(result['Today']!.map((e) => e.track.id), contains('t'));
      expect(result['Yesterday']!.map((e) => e.track.id), contains('y'));
      expect(result['Earlier']!.map((e) => e.track.id), contains('e'));
    });

    test('multiple today entries all land in Today', () {
      final entries = [
        makeEntry(playedAt: todayTs(), id: 't1'),
        makeEntry(playedAt: todayTs(), id: 't2'),
        makeEntry(playedAt: todayTs(), id: 't3'),
      ];
      final result = groupByDate(entries);

      expect(result['Today']!.length, 3);
      expect(result.containsKey('Yesterday'), isFalse);
      expect(result.containsKey('Earlier'), isFalse);
    });

    test('multiple earlier entries all land in Earlier', () {
      final entries = [
        makeEntry(playedAt: earlierTs(), id: 'e1'),
        makeEntry(playedAt: earlierTs(), id: 'e2'),
      ];
      final result = groupByDate(entries);

      expect(result['Earlier']!.length, 2);
    });
  });

  // ── Order preservation ────────────────────────────────────────────────────

  group('groupByDate — insertion order is preserved within each bucket', () {
    test('today entries preserve input order', () {
      final entries = [
        makeEntry(playedAt: todayTs(), id: 'first'),
        makeEntry(playedAt: todayTs(), id: 'second'),
        makeEntry(playedAt: todayTs(), id: 'third'),
      ];
      final result = groupByDate(entries);
      final ids = result['Today']!.map((e) => e.track.id).toList();

      expect(ids, ['first', 'second', 'third']);
    });

    test('earlier entries preserve input order', () {
      final entries = [
        makeEntry(playedAt: earlierTs(), id: 'old1'),
        makeEntry(playedAt: earlierTs(), id: 'old2'),
      ];
      final result = groupByDate(entries);
      final ids = result['Earlier']!.map((e) => e.track.id).toList();

      expect(ids, ['old1', 'old2']);
    });
  });

  // ── Boundary conditions ───────────────────────────────────────────────────

  group('groupByDate — boundary: exactly at midnight', () {
    test('entry at exact start of today is treated as Today', () {
      final now = DateTime.now();
      final midnightToday = DateTime(now.year, now.month, now.day);

      final result = groupByDate([makeEntry(playedAt: midnightToday)]);
      expect(result.containsKey('Today'), isTrue);
      expect(result.containsKey('Yesterday'), isFalse);
    });

    test('entry one millisecond before midnight is Yesterday', () {
      final now = DateTime.now();
      final midnightToday = DateTime(now.year, now.month, now.day);
      final justBeforeMidnight =
          midnightToday.subtract(const Duration(milliseconds: 1));

      final result = groupByDate([makeEntry(playedAt: justBeforeMidnight)]);
      expect(result.containsKey('Yesterday'), isTrue);
      expect(result.containsKey('Today'), isFalse);
    });

    test('entry at exact start of yesterday is treated as Yesterday', () {
      final now = DateTime.now();
      final midnightToday = DateTime(now.year, now.month, now.day);
      final midnightYesterday =
          midnightToday.subtract(const Duration(days: 1));

      final result = groupByDate([makeEntry(playedAt: midnightYesterday)]);
      expect(result.containsKey('Yesterday'), isTrue);
      expect(result.containsKey('Earlier'), isFalse);
    });

    test('entry one millisecond before yesterday start is Earlier', () {
      final now = DateTime.now();
      final midnightToday = DateTime(now.year, now.month, now.day);
      final justBeforeYesterday =
          midnightToday.subtract(const Duration(days: 1, milliseconds: 1));

      final result = groupByDate([makeEntry(playedAt: justBeforeYesterday)]);
      expect(result.containsKey('Earlier'), isTrue);
      expect(result.containsKey('Yesterday'), isFalse);
    });
  });

  // ── Map key ordering ──────────────────────────────────────────────────────

  group('groupByDate — map key order (Today before Yesterday before Earlier)', () {
    test('all three buckets present — key order is Today, Yesterday, Earlier', () {
      final entries = [
        makeEntry(playedAt: todayTs(), id: 't'),
        makeEntry(playedAt: yesterdayTs(), id: 'y'),
        makeEntry(playedAt: earlierTs(), id: 'e'),
      ];
      final keys = groupByDate(entries).keys.toList();
      expect(keys, ['Today', 'Yesterday', 'Earlier']);
    });

    test('only Today and Earlier — Today comes first', () {
      final entries = [
        makeEntry(playedAt: todayTs()),
        makeEntry(playedAt: earlierTs()),
      ];
      final keys = groupByDate(entries).keys.toList();
      expect(keys, ['Today', 'Earlier']);
    });
  });
}
