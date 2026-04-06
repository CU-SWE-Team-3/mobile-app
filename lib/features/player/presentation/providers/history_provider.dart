import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/history_repository.dart';
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
    final tracks = entries.map((e) => e.track).toList();
    return tracks.length > 20 ? tracks.sublist(0, 20) : tracks;
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
  PlayerTrack? _lastRecorded;

  HistoryNotifier(this._ref, this._repo)
      : super(const HistoryState(isLoading: true)) {
    // Wire observation synchronously so no track switch is ever missed,
    // even during the async initial load below.
    _ref.listen<PlayerState>(
      playerProvider,
      (_, next) => _onCurrentTrackChanged(next.currentTrack),
    );
    _loadPersistedHistory();
  }

  Future<void> _loadPersistedHistory() async {
    final saved = await _repo.load();
    if (mounted) {
      state = state.copyWith(entries: saved, isLoading: false);
    }
  }

  void _onCurrentTrackChanged(PlayerTrack? current) {
    if (current == null) return;
    // Guard: same track emitted multiple times (loading / buffering state
    // updates) should not create duplicate entries.
    if (current == _lastRecorded) return;
    _lastRecorded = current;
    _record(current);
  }

  void _record(PlayerTrack track) {
    // Move to front if already present (deduplication).
    final updated = [
      HistoryEntry(track: track, playedAt: DateTime.now()),
      ...state.entries.where((e) => e.track.id != track.id),
    ];
    final capped =
        updated.length > 50 ? updated.sublist(0, 50) : updated;
    state = state.copyWith(entries: capped);
    _repo.save(capped); // fire-and-forget persistence
  }

  Future<void> clearHistory() async {
    await _repo.clear();
    _lastRecorded = null;
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
  return HistoryNotifier(ref, HistoryRepository());
});
