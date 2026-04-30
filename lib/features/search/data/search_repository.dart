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
    final responses = await Future.wait<dynamic>([
      _dio.get(
        '/tracks/search',
        queryParameters: {'q': query, 'page': 1, 'limit': 20},
      ),
      _fetchBlockedIds(),
    ]);
    final results = _parse((responses[0] as Response).data);
    final blockedIds = responses[1] as Set<String>;
    if (blockedIds.isEmpty) return results;
    return (
      tracks: results.tracks,
      users: results.users.where((u) => !blockedIds.contains(u.id)).toList(),
      playlists: results.playlists,
    );
  }

  Future<Set<String>> _fetchBlockedIds() async {
    try {
      final response = await _dio.get('/network/blocked-users');
      return _extractBlockedList(response.data)
          .map(_blockedUserId)
          .where((id) => id.isNotEmpty)
          .toSet();
    } on DioException {
      return {};
    }
  }

  List<dynamic> _extractBlockedList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return const [];
    final data = raw['data'];
    if (data is List) return data;
    if (data is Map) {
      for (final key in const ['blockedUsers', 'users', 'blocked']) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    for (final key in const ['blockedUsers', 'users', 'blocked']) {
      final value = raw[key];
      if (value is List) return value;
    }
    return const [];
  }

  String _blockedUserId(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is! Map) return raw.toString();
    final map = Map<String, dynamic>.from(raw);
    for (final key in const ['_id', 'id', 'userId', 'blockedUserId']) {
      final value = map[key]?.toString() ?? '';
      if (value.isNotEmpty) return value;
    }
    for (final key in const ['blockedUser', 'user', 'target']) {
      final value = map[key];
      if (value is Map) {
        final id = _blockedUserId(value);
        if (id.isNotEmpty) return id;
      } else {
        final id = value?.toString() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    return '';
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
