import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/player_track.dart';

/// A played-track record that pairs a [PlayerTrack] with the wall-clock time
/// at which playback started. [PlayerTrack] carries no timestamp, so this
/// wrapper is the only place date-based grouping (Today / Yesterday / Earlier)
/// can be derived.
class HistoryEntry {
  final PlayerTrack track;
  final DateTime playedAt;

  const HistoryEntry({required this.track, required this.playedAt});
}

/// Persists listening history as JSON in [SharedPreferences].
/// Caps at 50 entries (FIFO — oldest are dropped first).
class HistoryRepository {
  static const String _key = 'listening_history_v1';
  static const int _maxEntries = 50;

  Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _entryFromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final capped =
        entries.length > _maxEntries ? entries.sublist(0, _maxEntries) : entries;
    await prefs.setString(
        _key, jsonEncode(capped.map(_entryToMap).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ---------------------------------------------------------------------------
  // Serialisation helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _entryToMap(HistoryEntry e) => {
        'playedAt': e.playedAt.toIso8601String(),
        'id': e.track.id,
        'title': e.track.title,
        'artist': e.track.artist,
        'audioUrl': e.track.audioUrl,
        if (e.track.coverUrl != null) 'coverUrl': e.track.coverUrl,
        if (e.track.duration != null)
          'durationMs': e.track.duration!.inMilliseconds,
        if (e.track.artistId != null) 'artistId': e.track.artistId,
      };

  static HistoryEntry _entryFromMap(Map<String, dynamic> m) => HistoryEntry(
        playedAt: DateTime.parse(m['playedAt'] as String),
        track: PlayerTrack(
          id: m['id'] as String,
          title: m['title'] as String,
          artist: m['artist'] as String,
          artistId: m['artistId'] as String?,
          audioUrl: m['audioUrl'] as String,
          coverUrl: m['coverUrl'] as String?,
          duration: m['durationMs'] != null
              ? Duration(milliseconds: m['durationMs'] as int)
              : null,
        ),
      );
}
