import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/search_repository.dart';
import '../../domain/entities/search_result.dart';

export '../../domain/entities/search_result.dart';
export '../../data/search_repository.dart' show SearchResults;

// ── Enums ─────────────────────────────────────────────────────────────────────

enum SearchMode { idle, history, results }

enum SearchFilter { all, tracks, users, playlists, albums }

// ── State ─────────────────────────────────────────────────────────────────────

class SearchState {
  final String query;
  final SearchMode mode;
  final List<SearchHistoryEntry> history;
  final List<SearchResultTrack> trackResults;
  final List<SearchResultUser> userResults;
  final List<SearchResultPlaylist> playlistResults;
  final bool isLoading;
  final bool hasError;
  final SearchFilter filter;

  const SearchState({
    this.query = '',
    this.mode = SearchMode.idle,
    this.history = const [],
    this.trackResults = const [],
    this.userResults = const [],
    this.playlistResults = const [],
    this.isLoading = false,
    this.hasError = false,
    this.filter = SearchFilter.all,
  });

  SearchState copyWith({
    String? query,
    SearchMode? mode,
    List<SearchHistoryEntry>? history,
    List<SearchResultTrack>? trackResults,
    List<SearchResultUser>? userResults,
    List<SearchResultPlaylist>? playlistResults,
    bool? isLoading,
    bool? hasError,
    SearchFilter? filter,
  }) =>
      SearchState(
        query: query ?? this.query,
        mode: mode ?? this.mode,
        history: history ?? this.history,
        trackResults: trackResults ?? this.trackResults,
        userResults: userResults ?? this.userResults,
        playlistResults: playlistResults ?? this.playlistResults,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
        filter: filter ?? this.filter,
      );

  // Client-side display filter applied over the fetched results
  List<SearchResultTrack> get visibleTracks =>
      (filter == SearchFilter.all || filter == SearchFilter.tracks)
          ? trackResults
          : [];

  List<SearchResultUser> get visibleUsers =>
      (filter == SearchFilter.all || filter == SearchFilter.users)
          ? userResults
          : [];

  List<SearchResultPlaylist> get visiblePlaylists =>
      (filter == SearchFilter.all || filter == SearchFilter.playlists)
          ? playlistResults
          : [];

  // Albums backend not yet wired — always empty; tab exists for UI completeness
  List<Object> get visibleAlbums => const [];

  bool get hasResults =>
      visibleTracks.isNotEmpty ||
      visibleUsers.isNotEmpty ||
      visiblePlaylists.isNotEmpty;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repo;

  SearchNotifier(this._repo) : super(const SearchState()) {
    _init();
  }

  Future<void> _init() async {
    final history = await _repo.loadHistory();
    if (mounted) state = state.copyWith(history: history);
  }

  void onQueryChanged(String query) {
    if (query.isEmpty) {
      state = state.copyWith(query: '', mode: SearchMode.idle);
    } else {
      state = state.copyWith(query: query, mode: SearchMode.history);
    }
  }

  Future<void> submit(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    state = state.copyWith(
      query: q,
      mode: SearchMode.results,
      isLoading: true,
      hasError: false,
    );
    try {
      final results = await _repo.globalSearch(q);
      if (mounted) {
        state = state.copyWith(
          trackResults: results.tracks,
          userResults: results.users,
          playlistResults: results.playlists,
          isLoading: false,
        );
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  Future<void> saveToHistory(SearchHistoryEntry entry) async {
    await _repo.addToHistory(entry);
    if (mounted) {
      final updated = await _repo.loadHistory();
      if (mounted) state = state.copyWith(history: updated);
    }
  }

  Future<void> removeHistoryEntry(String id, SearchEntityType type) async {
    // Optimistic update for instant UI feedback
    state = state.copyWith(
      history: state.history
          .where((e) => !(e.id == id && e.type == type))
          .toList(),
    );
    await _repo.removeFromHistory(id, type);
  }

  void setFilter(SearchFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void reset() {
    state = state.copyWith(
      query: '',
      mode: SearchMode.idle,
      trackResults: [],
      userResults: [],
      playlistResults: [],
      isLoading: false,
      hasError: false,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(dioClientProvider).dio);
});

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.watch(searchRepositoryProvider));
});
