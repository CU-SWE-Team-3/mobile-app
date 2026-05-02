import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/services/player_api_service.dart';
import 'player_provider.dart';

export '../../data/repositories/history_repository.dart' show HistoryEntry;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class HistoryState {
  /// Full list, newest first, capped at 50.
  final List<HistoryEntry> entries;
  final bool isLoading;

  const HistoryState({
    this.entries = const [],
    this.isLoading = false,
  });

  /// Last 20 tracks for the Recently Played screen.
  List<PlayerTrack> get recentlyPlayed {
    final seen = <String>{};
    final tracks = <PlayerTrack>[];
    for (final entry in entries) {
      if (seen.add(entry.track.id)) tracks.add(entry.track);
      if (tracks.length == 20) break;
    }
    return tracks;
  }

  /// Full entry list for the Listening History screen (date grouping lives in
  /// the UI layer, not here).
  List<HistoryEntry> get history => List.unmodifiable(entries);

  HistoryState copyWith({List<HistoryEntry>? entries, bool? isLoading}) =>
      HistoryState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class HistoryNotifier extends StateNotifier<HistoryState> {
  final Ref _ref;
  final HistoryRepository _repo;

  /// The last track we recorded — used to deduplicate rapid state emissions.
  String? _lastRecordedTrackId;
  DateTime? _lastRecordedAt;

  HistoryNotifier(this._ref, this._repo)
      : super(const HistoryState(isLoading: true)) {
    // Wire observation synchronously so no track switch is ever missed,
    // even during the async initial load below.
    _ref.listen<PlayerState>(
      playerProvider,
      (_, next) => _onPlayerStateChanged(next),
    );
    _loadPersistedHistory();
  }

  Future<void> _loadPersistedHistory() async {
    final saved = await _repo.load();
    if (mounted) {
      state = state.copyWith(entries: saved, isLoading: false);
    }
  }

  void _onPlayerStateChanged(PlayerState next) {
    final current = next.currentTrack;
    if (current == null) return;
    if (!next.isPlaying || next.isLoading) return;

    final now = DateTime.now();
    final lastAt = _lastRecordedAt;
    if (_lastRecordedTrackId == current.id &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(seconds: 2)) {
      return;
    }

    _lastRecordedTrackId = current.id;
    _lastRecordedAt = now;
    _record(current, playedAt: now, progress: next.position);
  }

  void _record(
    PlayerTrack track, {
    required DateTime playedAt,
    Duration? progress,
  }) {
    final updated = [
      HistoryEntry(track: track, playedAt: playedAt, progress: progress),
      ...state.entries,
    ];
    final capped =
        updated.length > 50 ? updated.sublist(0, 50) : updated;
    state = state.copyWith(entries: capped);
    _repo.save(capped); // fire-and-forget persistence
  }

  Future<void> clearHistory() async {
    await _repo.clear();
    _lastRecordedTrackId = null;
    _lastRecordedAt = null;
    if (mounted) state = state.copyWith(entries: []);
  }

  /// Pull-to-refresh: re-read from SharedPreferences (e.g. after a cold
  /// restart where in-memory state is empty but disk has data).
  Future<void> refresh() async {
    final saved = await _repo.load();
    if (mounted) state = state.copyWith(entries: saved);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  return HistoryNotifier(ref, HistoryRepository(userId));
});

// ---------------------------------------------------------------------------
// Server-backed history (used by ListeningHistoryPage)
// ---------------------------------------------------------------------------

/// State for history fetched from GET /history/recently-played.
class ServerHistoryState {
  final List<HistoryEntry> entries;
  final bool isLoading;

  const ServerHistoryState({
    this.entries = const [],
    this.isLoading = false,
  });

  List<HistoryEntry> get history => List.unmodifiable(entries);

  ServerHistoryState copyWith({
    List<HistoryEntry>? entries,
    bool? isLoading,
  }) =>
      ServerHistoryState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
      );
}

class ServerHistoryNotifier extends StateNotifier<ServerHistoryState> {
  final PlayerApiService _api;

  ServerHistoryNotifier(this._api)
      : super(const ServerHistoryState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    final entries = await _api.getRecentlyPlayed();
    if (mounted) {
      state = state.copyWith(entries: entries, isLoading: false);
    }
  }

  /// Pull-to-refresh: re-fetches from the server.
  Future<void> refresh() => _load();

  /// Clears history on the server then empties local state.
  Future<void> clearHistory() async {
    await _api.clearServerHistory();
    if (mounted) state = state.copyWith(entries: []);
  }
}

/// Auto-disposed so it re-fetches each time ListeningHistoryPage is opened.
final serverHistoryProvider = StateNotifierProvider.autoDispose<
    ServerHistoryNotifier, ServerHistoryState>((ref) {
  return ServerHistoryNotifier(ref.read(playerApiServiceProvider));
});
