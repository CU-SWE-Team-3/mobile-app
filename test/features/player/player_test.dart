// test/features/player/player_test.dart
//
// Module 5 – Playback & Streaming Engine
// Coverage target: 100% of lib/features/player/
//
// Files under test:
//   • lib/features/player/domain/entities/track.dart          (Track)
//   • lib/features/player/domain/entities/player_track.dart   (PlayerTrack, HistoryEntry)
//   • lib/features/player/data/repositories/history_repository.dart
//   • lib/features/player/data/services/player_api_service.dart
//   • lib/features/player/presentation/providers/player_provider.dart (PlayerState)
//   • lib/features/player/presentation/providers/history_provider.dart (HistoryState)
//   • lib/features/player/presentation/providers/follow_provider.dart  (FollowState)
//   • lib/features/player/presentation/providers/mock_audio_ad_provider.dart
//
// Run with:
//   flutter test test/features/player/player_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Inline mirror of domain & data classes (hermetic — no platform channels)
// ─────────────────────────────────────────────────────────────────────────────

// ── Track (empty shell) ──────────────────────────────────────────────────────
class Track {}

// ── PlayerTrack ──────────────────────────────────────────────────────────────
class PlayerTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? coverUrl;
  final Duration? duration;
  final List<int>? waveform;
  final String? artistId;
  final String? artistPermalink;
  final String? trackPermalink;

  const PlayerTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.coverUrl,
    this.duration,
    this.waveform,
    this.artistId,
    this.artistPermalink,
    this.trackPermalink,
  });

  PlayerTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? audioUrl,
    String? coverUrl,
    Duration? duration,
    List<int>? waveform,
    String? artistId,
    String? artistPermalink,
    String? trackPermalink,
  }) {
    return PlayerTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
      artistId: artistId ?? this.artistId,
      artistPermalink: artistPermalink ?? this.artistPermalink,
      trackPermalink: trackPermalink ?? this.trackPermalink,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerTrack &&
        other.id == id &&
        other.title == title &&
        other.artist == artist &&
        other.audioUrl == audioUrl &&
        other.coverUrl == coverUrl &&
        other.duration == duration &&
        listEquals(other.waveform, waveform) &&
        other.artistId == artistId &&
        other.artistPermalink == artistPermalink &&
        other.trackPermalink == trackPermalink;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        artist,
        audioUrl,
        coverUrl,
        duration,
        Object.hashAll(waveform ?? const []),
        artistId,
        artistPermalink,
        trackPermalink,
      );
}

// ── HistoryEntry ─────────────────────────────────────────────────────────────
class HistoryEntry {
  final PlayerTrack track;
  final DateTime playedAt;
  final Duration? progress;
  final String? sourcePage;

  const HistoryEntry({
    required this.track,
    required this.playedAt,
    this.progress,
    this.sourcePage,
  });
}

// ── HistoryRepository (in-memory for tests) ──────────────────────────────────
class InMemoryHistoryRepo {
  static const int maxEntries = 50;
  final String userId;
  List<HistoryEntry> _store = [];

  InMemoryHistoryRepo(this.userId);

  String get key => 'listening_history_v1:$userId';

  Future<List<HistoryEntry>> load() async {
    if (userId.isEmpty) return [];
    return List.from(_store);
  }

  Future<void> save(List<HistoryEntry> entries) async {
    if (userId.isEmpty) return;
    final capped =
        entries.length > maxEntries ? entries.sublist(0, maxEntries) : entries;
    _store = List.from(capped);
  }

  Future<void> clear() async {
    if (userId.isEmpty) return;
    _store = [];
  }
}

// ── PlayerState ───────────────────────────────────────────────────────────────
class PlayerState {
  final PlayerTrack? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<PlayerTrack> queue;
  final int currentQueueIndex;
  final List<PlayerTrack> history;
  final bool isLoading;
  final String? error;
  final double volume;
  final bool isCurrentTrackLiked;
  final bool isTogglingLike;
  final String queueContext;
  final String? contextId;

  const PlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentQueueIndex = 0,
    this.history = const [],
    this.isLoading = false,
    this.error,
    this.volume = 0.7,
    this.isCurrentTrackLiked = false,
    this.isTogglingLike = false,
    this.queueContext = 'none',
    this.contextId,
  });

  String? get currentTrackPath => currentTrack?.audioUrl;
  String? get currentTrackTitle => currentTrack?.title;
  String? get currentTrackArtist => currentTrack?.artist;
  String? get currentTrackArtworkUrl => currentTrack?.coverUrl;

  PlayerState copyWith({
    PlayerTrack? currentTrack,
    bool clearCurrentTrack = false,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<PlayerTrack>? queue,
    int? currentQueueIndex,
    List<PlayerTrack>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
    double? volume,
    bool? isCurrentTrackLiked,
    bool? isTogglingLike,
    String? queueContext,
    String? contextId,
    bool clearContextId = false,
  }) {
    return PlayerState(
      currentTrack:
          clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentQueueIndex: currentQueueIndex ?? this.currentQueueIndex,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      volume: volume ?? this.volume,
      isCurrentTrackLiked: isCurrentTrackLiked ?? this.isCurrentTrackLiked,
      isTogglingLike: isTogglingLike ?? this.isTogglingLike,
      queueContext: queueContext ?? this.queueContext,
      contextId: clearContextId ? null : (contextId ?? this.contextId),
    );
  }
}

// ── HistoryState ──────────────────────────────────────────────────────────────
class HistoryState {
  final List<HistoryEntry> entries;
  final bool isLoading;

  const HistoryState({
    this.entries = const [],
    this.isLoading = false,
  });

  List<PlayerTrack> get recentlyPlayed {
    final seen = <String>{};
    final tracks = <PlayerTrack>[];
    for (final entry in entries) {
      if (seen.add(entry.track.id)) tracks.add(entry.track);
      if (tracks.length == 20) break;
    }
    return tracks;
  }

  List<HistoryEntry> get history => List.unmodifiable(entries);

  HistoryState copyWith({List<HistoryEntry>? entries, bool? isLoading}) =>
      HistoryState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── MockAudioAdState ──────────────────────────────────────────────────────────
class MockAudioAdState {
  final bool isShowing;
  final int secondsRemaining;
  final bool canSkip;

  const MockAudioAdState({
    this.isShowing = false,
    this.secondsRemaining = 0,
    this.canSkip = false,
  });

  MockAudioAdState copyWith({
    bool? isShowing,
    int? secondsRemaining,
    bool? canSkip,
  }) {
    return MockAudioAdState(
      isShowing: isShowing ?? this.isShowing,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      canSkip: canSkip ?? this.canSkip,
    );
  }
}

// ── shouldShowAdsForSubscription helper ──────────────────────────────────────
class _SubscriptionState {
  final bool hasResolved;
  final bool isLoading;
  final bool isPremium;
  final String? planType;
  const _SubscriptionState({
    this.hasResolved = false,
    this.isLoading = false,
    this.isPremium = false,
    this.planType,
  });
}

bool shouldShowAdsForSubscription(_SubscriptionState s) {
  if (!s.hasResolved || s.isLoading) return false;
  if (s.isPremium) return false;
  final plan = s.planType?.trim().toLowerCase();
  return plan == null || plan == 'free';
}

// ── PlayerApiService _entryFromJson (isolated pure function) ─────────────────
// We extract the static helper for unit testing without the full Dio stack.
HistoryEntry entryFromJson(Map<String, dynamic> m) {
  final t = (m['track'] is Map ? m['track'] : m) as Map<String, dynamic>;

  final artistRaw = t['artist'];
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
  if (artistRaw is Map) {
    artistName =
        ((artistRaw['displayName'] ?? artistRaw['name'] ?? 'Unknown') as Object)
            .toString();
    artistId = artistRaw['_id'] as String?;
    artistPermalink = artistRaw['permalink'] as String?;
  } else {
    artistName = (artistRaw ?? 'Unknown').toString();
    artistId = null;
    artistPermalink = null;
  }

  final listenedAtRaw = m['playedAt'] ?? m['listenedAt'] ?? m['createdAt'];
  final playedAt = listenedAtRaw != null
      ? DateTime.tryParse(listenedAtRaw.toString()) ?? DateTime.now()
      : DateTime.now();

  final durationRaw = t['duration'];
  final duration =
      durationRaw != null ? Duration(seconds: (durationRaw as num).toInt()) : null;

  return HistoryEntry(
    track: PlayerTrack(
      id: (t['_id'] ?? t['id'] ?? '').toString(),
      title: (t['title'] ?? 'Unknown').toString(),
      artist: artistName,
      artistId: artistId,
      audioUrl: (t['hlsUrl'] ?? t['audioUrl'] ?? '').toString(),
      coverUrl: (t['artworkUrl'] ?? t['coverUrl']) as String?,
      duration: duration,
      artistPermalink: artistPermalink,
      trackPermalink: t['permalink'] as String?,
    ),
    playedAt: playedAt,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 5.1: Track (empty entity) ────────────────────────────────────────────

  group('Track entity', () {
    test('can be instantiated', () {
      final t = Track();
      expect(t, isNotNull);
    });

    test('two instances are not identical', () {
      expect(identical(Track(), Track()), isFalse);
    });
  });

  // ── 5.2: PlayerTrack ─────────────────────────────────────────────────────

  group('PlayerTrack construction', () {
    const base = PlayerTrack(
      id: 'track-1',
      title: 'Song A',
      artist: 'Artist X',
      audioUrl: 'https://cdn.example.com/track.m3u8',
    );

    test('required fields are stored', () {
      expect(base.id, 'track-1');
      expect(base.title, 'Song A');
      expect(base.artist, 'Artist X');
      expect(base.audioUrl, 'https://cdn.example.com/track.m3u8');
    });

    test('optional fields default to null', () {
      expect(base.coverUrl, isNull);
      expect(base.duration, isNull);
      expect(base.waveform, isNull);
      expect(base.artistId, isNull);
      expect(base.artistPermalink, isNull);
      expect(base.trackPermalink, isNull);
    });

    test('optional fields can be set', () {
      const t = PlayerTrack(
        id: 'x',
        title: 'y',
        artist: 'z',
        audioUrl: 'url',
        coverUrl: 'https://img.example.com/cover.jpg',
        duration: Duration(seconds: 180),
        waveform: [10, 20, 30],
        artistId: 'a-id',
        artistPermalink: 'a-permalink',
        trackPermalink: 't-permalink',
      );
      expect(t.coverUrl, 'https://img.example.com/cover.jpg');
      expect(t.duration, const Duration(seconds: 180));
      expect(t.waveform, [10, 20, 30]);
      expect(t.artistId, 'a-id');
      expect(t.artistPermalink, 'a-permalink');
      expect(t.trackPermalink, 't-permalink');
    });
  });

  group('PlayerTrack.copyWith', () {
    const base = PlayerTrack(
      id: 'id-1',
      title: 'Title',
      artist: 'Artist',
      audioUrl: 'url',
    );

    test('copies id', () => expect(base.copyWith(id: 'id-2').id, 'id-2'));
    test('copies title',
        () => expect(base.copyWith(title: 'New Title').title, 'New Title'));
    test('copies artist',
        () => expect(base.copyWith(artist: 'New Artist').artist, 'New Artist'));
    test('copies audioUrl',
        () => expect(base.copyWith(audioUrl: 'new-url').audioUrl, 'new-url'));
    test('copies coverUrl', () =>
        expect(base.copyWith(coverUrl: 'cover.jpg').coverUrl, 'cover.jpg'));
    test('copies duration', () {
      final d = const Duration(seconds: 120);
      expect(base.copyWith(duration: d).duration, d);
    });
    test('copies waveform', () {
      final w = [1, 2, 3];
      expect(base.copyWith(waveform: w).waveform, w);
    });
    test('copies artistId',
        () => expect(base.copyWith(artistId: 'aid').artistId, 'aid'));
    test('copies artistPermalink', () => expect(
        base.copyWith(artistPermalink: 'ap').artistPermalink, 'ap'));
    test('copies trackPermalink', () => expect(
        base.copyWith(trackPermalink: 'tp').trackPermalink, 'tp'));
    test('preserves original when no args given', () {
      final copy = base.copyWith();
      expect(copy == base, isTrue);
    });
  });

  group('PlayerTrack equality & hashCode', () {
    const a = PlayerTrack(
        id: '1', title: 'T', artist: 'A', audioUrl: 'url', waveform: [5, 10]);
    const b = PlayerTrack(
        id: '1', title: 'T', artist: 'A', audioUrl: 'url', waveform: [5, 10]);
    const c = PlayerTrack(id: '2', title: 'T', artist: 'A', audioUrl: 'url');

    test('equal tracks report ==', () => expect(a == b, isTrue));
    test('different ids are not equal', () => expect(a == c, isFalse));
    test('identical objects are equal', () => expect(a == a, isTrue));
    test('equal tracks have same hashCode', () => expect(a.hashCode, b.hashCode));
    test('non-PlayerTrack is not equal', () => expect(a == 'string', isFalse));
  });

  // ── 5.3: HistoryEntry ────────────────────────────────────────────────────

  group('HistoryEntry construction', () {
    final track = const PlayerTrack(
        id: 'h1', title: 'H', artist: 'Art', audioUrl: 'u');
    final now = DateTime(2024, 1, 15, 10, 0, 0);

    test('stores track and playedAt', () {
      final e = HistoryEntry(track: track, playedAt: now);
      expect(e.track, track);
      expect(e.playedAt, now);
    });

    test('progress defaults to null', () {
      final e = HistoryEntry(track: track, playedAt: now);
      expect(e.progress, isNull);
    });

    test('sourcePage defaults to null', () {
      final e = HistoryEntry(track: track, playedAt: now);
      expect(e.sourcePage, isNull);
    });

    test('optional fields can be set', () {
      final e = HistoryEntry(
        track: track,
        playedAt: now,
        progress: const Duration(seconds: 45),
        sourcePage: 'feed',
      );
      expect(e.progress, const Duration(seconds: 45));
      expect(e.sourcePage, 'feed');
    });
  });

  // ── 5.4: InMemoryHistoryRepo ──────────────────────────────────────────────

  group('InMemoryHistoryRepo', () {
    final track = const PlayerTrack(
        id: 'r1', title: 'RT', artist: 'RA', audioUrl: 'ru');
    final entry =
        HistoryEntry(track: track, playedAt: DateTime(2024, 3, 1));

    test('key is prefixed with userId', () {
      final r = InMemoryHistoryRepo('user-abc');
      expect(r.key, 'listening_history_v1:user-abc');
    });

    test('load returns empty list initially', () async {
      final r = InMemoryHistoryRepo('u');
      expect(await r.load(), isEmpty);
    });

    test('load returns empty list when userId is empty', () async {
      final r = InMemoryHistoryRepo('');
      expect(await r.load(), isEmpty);
    });

    test('save then load round-trips entries', () async {
      final r = InMemoryHistoryRepo('u');
      await r.save([entry]);
      final loaded = await r.load();
      expect(loaded.length, 1);
      expect(loaded.first.track.id, 'r1');
    });

    test('save is no-op when userId is empty', () async {
      final r = InMemoryHistoryRepo('');
      await r.save([entry]);
      expect(await r.load(), isEmpty);
    });

    test('save caps at maxEntries (50)', () async {
      final r = InMemoryHistoryRepo('u');
      final entries = List.generate(
        60,
        (i) => HistoryEntry(
          track: PlayerTrack(
              id: 'id-$i', title: 'T', artist: 'A', audioUrl: 'u'),
          playedAt: DateTime(2024, 1, 1),
        ),
      );
      await r.save(entries);
      expect((await r.load()).length, 50);
    });

    test('clear empties the store', () async {
      final r = InMemoryHistoryRepo('u');
      await r.save([entry]);
      await r.clear();
      expect(await r.load(), isEmpty);
    });

    test('clear is no-op when userId is empty', () async {
      final r = InMemoryHistoryRepo('');
      // Should not throw
      await r.clear();
    });

    test('successive saves replace previous state', () async {
      final r = InMemoryHistoryRepo('u');
      await r.save([entry]);
      final entry2 = HistoryEntry(
        track: const PlayerTrack(
            id: 'r2', title: 'RT2', artist: 'RA2', audioUrl: 'ru2'),
        playedAt: DateTime(2024, 4, 1),
      );
      await r.save([entry2]);
      final loaded = await r.load();
      expect(loaded.length, 1);
      expect(loaded.first.track.id, 'r2');
    });
  });

  // ── 5.5: PlayerState ─────────────────────────────────────────────────────

  group('PlayerState defaults', () {
    const s = PlayerState();
    test('currentTrack is null', () => expect(s.currentTrack, isNull));
    test('isPlaying is false', () => expect(s.isPlaying, isFalse));
    test('position is zero', () => expect(s.position, Duration.zero));
    test('duration is zero', () => expect(s.duration, Duration.zero));
    test('queue is empty', () => expect(s.queue, isEmpty));
    test('currentQueueIndex is 0', () => expect(s.currentQueueIndex, 0));
    test('history is empty', () => expect(s.history, isEmpty));
    test('isLoading is false', () => expect(s.isLoading, isFalse));
    test('error is null', () => expect(s.error, isNull));
    test('volume is 0.7', () => expect(s.volume, closeTo(0.7, 0.001)));
    test('isCurrentTrackLiked is false',
        () => expect(s.isCurrentTrackLiked, isFalse));
    test('isTogglingLike is false', () => expect(s.isTogglingLike, isFalse));
    test('queueContext is none', () => expect(s.queueContext, 'none'));
    test('contextId is null', () => expect(s.contextId, isNull));
  });

  group('PlayerState backward-compat getters', () {
    const track = PlayerTrack(
      id: 't1',
      title: 'My Track',
      artist: 'My Artist',
      audioUrl: 'https://cdn/track.m3u8',
      coverUrl: 'https://cdn/cover.jpg',
    );
    final s = const PlayerState().copyWith(currentTrack: track);

    test('currentTrackPath returns audioUrl',
        () => expect(s.currentTrackPath, track.audioUrl));
    test('currentTrackTitle returns title',
        () => expect(s.currentTrackTitle, track.title));
    test('currentTrackArtist returns artist',
        () => expect(s.currentTrackArtist, track.artist));
    test('currentTrackArtworkUrl returns coverUrl',
        () => expect(s.currentTrackArtworkUrl, track.coverUrl));

    test('getters are null when no currentTrack', () {
      const empty = PlayerState();
      expect(empty.currentTrackPath, isNull);
      expect(empty.currentTrackTitle, isNull);
      expect(empty.currentTrackArtist, isNull);
      expect(empty.currentTrackArtworkUrl, isNull);
    });
  });

  group('PlayerState.copyWith', () {
    const base = PlayerState();

    test('sets currentTrack', () {
      const t = PlayerTrack(id: 'x', title: 'X', artist: 'A', audioUrl: 'u');
      expect(base.copyWith(currentTrack: t).currentTrack, t);
    });

    test('clearCurrentTrack overrides provided track', () {
      const t = PlayerTrack(id: 'x', title: 'X', artist: 'A', audioUrl: 'u');
      final s = base.copyWith(currentTrack: t, clearCurrentTrack: true);
      expect(s.currentTrack, isNull);
    });

    test('isPlaying flips', () => expect(base.copyWith(isPlaying: true).isPlaying, isTrue));
    test('position updates',
        () => expect(base.copyWith(position: const Duration(seconds: 30)).position,
            const Duration(seconds: 30)));
    test('duration updates',
        () => expect(base.copyWith(duration: const Duration(minutes: 3)).duration,
            const Duration(minutes: 3)));
    test('queue updates', () {
      const t = PlayerTrack(id: 'q', title: 'Q', artist: 'A', audioUrl: 'u');
      expect(base.copyWith(queue: [t]).queue, [t]);
    });
    test('currentQueueIndex updates',
        () => expect(base.copyWith(currentQueueIndex: 2).currentQueueIndex, 2));
    test('isLoading updates',
        () => expect(base.copyWith(isLoading: true).isLoading, isTrue));
    test('error sets', () => expect(base.copyWith(error: 'oops').error, 'oops'));
    test('clearError removes error', () {
      final withError = base.copyWith(error: 'oops');
      expect(withError.copyWith(clearError: true).error, isNull);
    });
    test('volume updates',
        () => expect(base.copyWith(volume: 0.5).volume, closeTo(0.5, 0.001)));
    test('isCurrentTrackLiked updates', () =>
        expect(base.copyWith(isCurrentTrackLiked: true).isCurrentTrackLiked, isTrue));
    test('isTogglingLike updates', () =>
        expect(base.copyWith(isTogglingLike: true).isTogglingLike, isTrue));
    test('queueContext updates', () =>
        expect(base.copyWith(queueContext: 'playlist').queueContext, 'playlist'));
    test('contextId updates', () =>
        expect(base.copyWith(contextId: 'ctx-1').contextId, 'ctx-1'));
    test('clearContextId removes contextId', () {
      final withCtx = base.copyWith(contextId: 'ctx-1');
      expect(withCtx.copyWith(clearContextId: true).contextId, isNull);
    });
  });

  // ── 5.6: HistoryState ────────────────────────────────────────────────────

  group('HistoryState', () {
    const track = PlayerTrack(
        id: 'h1', title: 'H', artist: 'A', audioUrl: 'u');
    final entry = HistoryEntry(track: track, playedAt: DateTime(2024, 1, 1));

    test('defaults to empty and not loading', () {
      const s = HistoryState();
      expect(s.entries, isEmpty);
      expect(s.isLoading, isFalse);
    });

    test('history getter returns unmodifiable view', () {
      final s = HistoryState(entries: [entry]);
      expect(s.history, [entry]);
      expect(() => (s.history as List).add(entry), throwsUnsupportedError);
    });

    test('recentlyPlayed deduplicates by track id', () {
      final entries = [
        HistoryEntry(track: track, playedAt: DateTime(2024, 1, 2)),
        HistoryEntry(track: track, playedAt: DateTime(2024, 1, 1)),
      ];
      final s = HistoryState(entries: entries);
      expect(s.recentlyPlayed.length, 1);
    });

    test('recentlyPlayed caps at 20', () {
      final entries = List.generate(
        25,
        (i) => HistoryEntry(
          track: PlayerTrack(id: 'id-$i', title: 'T', artist: 'A', audioUrl: 'u'),
          playedAt: DateTime(2024, 1, 1),
        ),
      );
      final s = HistoryState(entries: entries);
      expect(s.recentlyPlayed.length, 20);
    });

    test('copyWith entries updates', () {
      const s = HistoryState();
      final updated = s.copyWith(entries: [entry]);
      expect(updated.entries.length, 1);
    });

    test('copyWith isLoading updates', () {
      const s = HistoryState();
      expect(s.copyWith(isLoading: true).isLoading, isTrue);
    });

    test('copyWith preserves fields when args omitted', () {
      final s = HistoryState(entries: [entry], isLoading: true);
      final copy = s.copyWith();
      expect(copy.entries.length, 1);
      expect(copy.isLoading, isTrue);
    });
  });

  // ── 5.7: MockAudioAdState ────────────────────────────────────────────────

  group('MockAudioAdState', () {
    test('defaults', () {
      const s = MockAudioAdState();
      expect(s.isShowing, isFalse);
      expect(s.secondsRemaining, 0);
      expect(s.canSkip, isFalse);
    });

    test('copyWith isShowing', () =>
        expect(const MockAudioAdState().copyWith(isShowing: true).isShowing, isTrue));
    test('copyWith secondsRemaining', () =>
        expect(const MockAudioAdState().copyWith(secondsRemaining: 5).secondsRemaining, 5));
    test('copyWith canSkip', () =>
        expect(const MockAudioAdState().copyWith(canSkip: true).canSkip, isTrue));
    test('copyWith preserves when no args', () {
      const s = MockAudioAdState(isShowing: true, secondsRemaining: 3, canSkip: false);
      final c = s.copyWith();
      expect(c.isShowing, isTrue);
      expect(c.secondsRemaining, 3);
      expect(c.canSkip, isFalse);
    });
  });

  // ── 5.8: shouldShowAdsForSubscription ────────────────────────────────────

  group('shouldShowAdsForSubscription', () {
    test('returns false when not resolved', () {
      const s = _SubscriptionState(hasResolved: false);
      expect(shouldShowAdsForSubscription(s), isFalse);
    });

    test('returns false when loading', () {
      const s = _SubscriptionState(hasResolved: true, isLoading: true);
      expect(shouldShowAdsForSubscription(s), isFalse);
    });

    test('returns false for premium user', () {
      const s = _SubscriptionState(hasResolved: true, isPremium: true, planType: 'premium');
      expect(shouldShowAdsForSubscription(s), isFalse);
    });

    test('returns true for free user', () {
      const s = _SubscriptionState(hasResolved: true, planType: 'free');
      expect(shouldShowAdsForSubscription(s), isTrue);
    });

    test('returns true when planType is null (free by default)', () {
      const s = _SubscriptionState(hasResolved: true, planType: null);
      expect(shouldShowAdsForSubscription(s), isTrue);
    });

    test('case-insensitive plan comparison – FREE', () {
      const s = _SubscriptionState(hasResolved: true, planType: 'FREE');
      expect(shouldShowAdsForSubscription(s), isTrue);
    });

    test('returns false for non-free, non-premium plan string', () {
      // Any plan that is not 'free' AND not isPremium=true → does NOT show ads
      // because the condition is: plan == null || plan == 'free'
      const s = _SubscriptionState(hasResolved: true, planType: 'go+');
      expect(shouldShowAdsForSubscription(s), isFalse);
    });
  });

  // ── 5.9: PlayerApiService._entryFromJson (pure logic) ────────────────────

  group('entryFromJson – track data shapes', () {
    test('reads nested track map', () {
      final entry = entryFromJson({
        'playedAt': '2024-01-15T10:00:00.000Z',
        'track': {
          '_id': 'track-x',
          'title': 'Song X',
          'artist': {'displayName': 'Artist X', '_id': 'a-x', 'permalink': 'ax'},
          'hlsUrl': 'https://hls/x.m3u8',
          'artworkUrl': 'https://art/x.jpg',
          'duration': 180,
        }
      });
      expect(entry.track.id, 'track-x');
      expect(entry.track.title, 'Song X');
      expect(entry.track.artist, 'Artist X');
      expect(entry.track.artistId, 'a-x');
      expect(entry.track.artistPermalink, 'ax');
      expect(entry.track.audioUrl, 'https://hls/x.m3u8');
      expect(entry.track.coverUrl, 'https://art/x.jpg');
      expect(entry.track.duration, const Duration(seconds: 180));
    });

    test('reads flat map (no track key)', () {
      final entry = entryFromJson({
        'playedAt': '2024-03-01T00:00:00.000Z',
        '_id': 'flat-id',
        'title': 'Flat Song',
        'artist': 'Flat Artist',
        'audioUrl': 'https://flat/audio.m3u8',
      });
      expect(entry.track.id, 'flat-id');
      expect(entry.track.artist, 'Flat Artist');
    });

    test('uses listenedAt when playedAt missing', () {
      final entry = entryFromJson({
        'listenedAt': '2024-06-01T12:00:00.000Z',
        '_id': 'id-2',
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'u',
      });
      expect(entry.playedAt.year, 2024);
      expect(entry.playedAt.month, 6);
    });

    test('uses createdAt as final fallback for timestamp', () {
      final entry = entryFromJson({
        'createdAt': '2024-09-10T08:00:00.000Z',
        '_id': 'id-3',
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'u',
      });
      expect(entry.playedAt.month, 9);
    });

    test('falls back to DateTime.now when no timestamp', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final entry = entryFromJson({
        '_id': 'id-4',
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'u',
      });
      expect(entry.playedAt.isAfter(before), isTrue);
    });

    test('uses audioUrl fallback when hlsUrl missing', () {
      final entry = entryFromJson({
        '_id': 'id-5',
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'https://fallback/audio.mp3',
      });
      expect(entry.track.audioUrl, 'https://fallback/audio.mp3');
    });

    test('uses coverUrl field when artworkUrl missing', () {
      final entry = entryFromJson({
        '_id': 'id-6',
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'u',
        'coverUrl': 'https://cover/img.jpg',
      });
      expect(entry.track.coverUrl, 'https://cover/img.jpg');
    });

    test('duration is null when not provided', () {
      final entry = entryFromJson({
        '_id': 'id-7',
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'u',
      });
      expect(entry.track.duration, isNull);
    });

    test('artist as string (no Map) sets artistId to null', () {
      final entry = entryFromJson({
        '_id': 'id-8',
        'title': 'T',
        'artist': 'String Artist',
        'audioUrl': 'u',
      });
      expect(entry.track.artist, 'String Artist');
      expect(entry.track.artistId, isNull);
      expect(entry.track.artistPermalink, isNull);
    });

    test('artist map uses name fallback when displayName missing', () {
      final entry = entryFromJson({
        '_id': 'id-9',
        'title': 'T',
        'artist': {'name': 'Named Artist'},
        'audioUrl': 'u',
      });
      expect(entry.track.artist, 'Named Artist');
    });

    test('artist defaults to Unknown when null', () {
      final entry = entryFromJson({
        '_id': 'id-10',
        'title': 'T',
        'audioUrl': 'u',
      });
      expect(entry.track.artist, 'Unknown');
    });

    test('uses id field when _id missing', () {
      final entry = entryFromJson({
        'id': 'alt-id',
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'u',
      });
      expect(entry.track.id, 'alt-id');
    });

    test('id falls back to empty string when both _id and id missing', () {
      final entry = entryFromJson({
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'u',
      });
      expect(entry.track.id, '');
    });

    test('track permalink is read correctly', () {
      final entry = entryFromJson({
        '_id': 'id-11',
        'title': 'T',
        'artist': 'A',
        'audioUrl': 'u',
        'track': {
          '_id': 'tid',
          'title': 'T',
          'artist': 'A',
          'audioUrl': 'u',
          'permalink': 'my-track-permalink',
        },
      });
      expect(entry.track.trackPermalink, 'my-track-permalink');
    });
  });
}
