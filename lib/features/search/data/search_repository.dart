import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/search_result.dart';

typedef SearchResults = ({
  List<SearchResultTrack> tracks,
  List<SearchResultUser> users,
  List<SearchResultPlaylist> playlists,
});

class SearchRepository {
  static const _historyKey = 'search_history_v1';
  static const _maxHistory = 30;

  final Dio _dio;
  SearchRepository(this._dio);

  // ── API ──────────────────────────────────────────────────────────────────────

  Future<SearchResults> globalSearch(String query) async {
    final response = await _dio.get(
      '/tracks/search',
      queryParameters: {'q': query, 'page': 1, 'limit': 20},
    );
    return _parse(response.data);
  }

  SearchResults _parse(dynamic responseData) {
    List<SearchResultTrack> tracks = [];
    List<SearchResultUser> users = [];
    List<SearchResultPlaylist> playlists = [];

    if (responseData is! Map) {
      return (tracks: tracks, users: users, playlists: playlists);
    }

    final data = responseData['data'];

    if (data is Map) {
      // Structured response: { data: { tracks: [...], users: [...], playlists: [...] } }
      final rawTracks = data['tracks'];
      final rawUsers = data['users'];
      final rawPlaylists = data['playlists'];
      if (rawTracks is List) {
        tracks = rawTracks
            .whereType<Map<String, dynamic>>()
            .map(SearchResultTrack.fromJson)
            .toList();
      }
      if (rawUsers is List) {
        users = rawUsers
            .whereType<Map<String, dynamic>>()
            .map(SearchResultUser.fromJson)
            .toList();
      }
      if (rawPlaylists is List) {
        playlists = rawPlaylists
            .whereType<Map<String, dynamic>>()
            .map(SearchResultPlaylist.fromJson)
            .toList();
      }
    } else if (data is List) {
      // Flat list — discriminate by 'type' field, default to track
      for (final item in data.whereType<Map<String, dynamic>>()) {
        final kind = item['type'] as String?;
        if (kind == 'user') {
          users.add(SearchResultUser.fromJson(item));
        } else if (kind == 'playlist') {
          playlists.add(SearchResultPlaylist.fromJson(item));
        } else {
          tracks.add(SearchResultTrack.fromJson(item));
        }
      }
    }

    return (tracks: tracks, users: users, playlists: playlists);
  }

  // ── History ──────────────────────────────────────────────────────────────────

  Future<List<SearchHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SearchHistoryEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addToHistory(SearchHistoryEntry entry) async {
    final current = await loadHistory();
    // Deduplicate: same id + type moves to the front
    final deduped = current
        .where((e) => !(e.id == entry.id && e.type == entry.type))
        .toList();
    final updated = [entry, ...deduped];
    final capped = updated.length > _maxHistory
        ? updated.sublist(0, _maxHistory)
        : updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(capped.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> removeFromHistory(String id, SearchEntityType type) async {
    final current = await loadHistory();
    final updated =
        current.where((e) => !(e.id == id && e.type == type)).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
