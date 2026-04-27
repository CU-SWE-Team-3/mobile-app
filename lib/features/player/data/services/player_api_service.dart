import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/player_track.dart';
import '../repositories/history_repository.dart';

/// Thin wrapper around the player/history REST endpoints.
/// All methods swallow exceptions — callers treat failures as best-effort
/// (fire-and-forget sync or graceful fallback to local data).
class PlayerApiService {
  final Dio _dio;

  const PlayerApiService(this._dio);

  // ── Stream resolution ─────────────────────────────────────────────────────

  /// GET /player/{trackId}/stream — returns the server-authorized HLS URL.
  /// Returns null on any error so the caller can fall back to track.audioUrl.
  Future<String?> getStreamUrl(String trackId) async {
    try {
      final response = await _dio.get('/player/$trackId/stream');
      final body = response.data;
      final inner = body is Map ? (body['data'] ?? body) : null;
      if (inner is Map) {
        final url = inner['streamUrl'] ?? inner['url'];
        if (url is String && url.isNotEmpty) return url;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  /// PUT /player/state — fire-and-forget position heartbeat every few seconds.
  Future<void> syncPlayerState({
    required String trackId,
    required double position,
    required bool isPlaying,
    required double volume,
  }) async {
    try {
      await _dio.put('/player/state', data: {
        'trackId': trackId,
        'position': position,
        'isPlaying': isPlaying,
        'volume': volume,
      });
    } catch (_) {}
  }

  // ── History write ─────────────────────────────────────────────────────────

  /// POST /history/progress — records listen progress when a track ends/is skipped.
  Future<void> reportProgress({
    required String trackId,
    required int listenedSeconds,
    required int totalSeconds,
  }) async {
    try {
      await _dio.post('/history/progress', data: {
        'trackId': trackId,
        'progress': listenedSeconds,
      });
    } catch (_) {}
  }

  // ── History read ──────────────────────────────────────────────────────────

  /// GET /history/recently-played — returns server-persisted history.
  /// Returns an empty list on any error.
  Future<List<HistoryEntry>> getRecentlyPlayed() async {
    try {
      final response = await _dio.get('/history/recently-played');
      final body = response.data;
      final inner = body is Map ? (body['data'] ?? body) : body;
      List<dynamic> raw;
      if (inner is List) {
        raw = inner;
      } else if (inner is Map) {
        raw = (inner['recentlyPlayed'] ??
                inner['tracks'] ??
                inner['history'] ??
                inner['items'] ??
                []) as List<dynamic>;
      } else {
        raw = [];
      }
      return raw
          .map((item) => _entryFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// DELETE /history — clears all server-side history for the authenticated user.
  Future<void> clearServerHistory() async {
    try {
      await _dio.delete('/history');
    } catch (_) {}
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  static HistoryEntry _entryFromJson(Map<String, dynamic> m) {
    final t = (m['track'] is Map ? m['track'] : m) as Map<String, dynamic>;

    final artistRaw = t['artist'];
    final String artistName;
    final String? artistId;
    final String? artistPermalink;
    if (artistRaw is Map) {
      artistName = ((artistRaw['displayName'] ??
              artistRaw['name'] ??
              'Unknown') as Object)
          .toString();
      artistId = artistRaw['_id'] as String?;
      artistPermalink = artistRaw['permalink'] as String?;
    } else {
      artistName = (artistRaw ?? 'Unknown').toString();
      artistId = null;
      artistPermalink = null;
    }

    final listenedAtRaw =
        m['playedAt'] ?? m['listenedAt'] ?? m['createdAt'];
    final playedAt = listenedAtRaw != null
        ? DateTime.tryParse(listenedAtRaw.toString()) ?? DateTime.now()
        : DateTime.now();

    final durationRaw = t['duration'];
    final duration = durationRaw != null
        ? Duration(seconds: (durationRaw as num).toInt())
        : null;

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
      ),
      playedAt: playedAt,
    );
  }
}

final playerApiServiceProvider = Provider<PlayerApiService>((ref) {
  return PlayerApiService(ref.read(dioClientProvider).dio);
});
