import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';

/// Single owner of all network calls to /playlists/*.
/// Every method throws on API failure — callers decide how to surface errors.
/// Never returns raw Response objects; returns parsed primitives or domain types.
class PlaylistRepository {
  PlaylistRepository({DioClient? client}) : _client = client ?? dioClient;

  final DioClient _client;
  Dio get _dio => _client.dio;

  // ── Write operations ────────────────────────────────────────────────────────

  /// POST /playlists — returns the server-issued playlist ID.
  Future<String> create(String title, bool isPublic) async {
    final response = await _dio.post(
      '/playlists',
      data: {'title': title, 'isPrivate': !isPublic},
    );
    final dataField = response.data['data'];
    final Map<String, dynamic> playlistMap;
    if (dataField is Map<String, dynamic>) {
      playlistMap =
          (dataField['playlist'] as Map<String, dynamic>?) ?? dataField;
    } else {
      playlistMap = {};
    }
    final id = playlistMap['_id'] as String? ?? '';
    if (id.isEmpty) throw Exception('No _id in response');
    return id;
  }

  /// PATCH /playlists/{id} — update mutable metadata fields (title, etc.).
  Future<void> updateMetadata(String id, {String? title}) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (body.isEmpty) return;
    await _dio.patch('/playlists/$id', data: body);
  }

  /// PATCH /playlists/{id} — toggle public/private visibility.
  Future<void> updatePrivacy(String id, bool isPublic) async {
    await _dio.patch('/playlists/$id', data: {'isPrivate': !isPublic});
  }

  /// DELETE /playlists/{id}.
  Future<void> deletePlaylist(String id) async {
    await _dio.delete('/playlists/$id');
  }

  /// PUT /playlists/{id}/tracks — full replacement with the supplied ordered list.
  Future<void> replaceTracks(String id, List<String> trackIds) async {
    await _dio.put('/playlists/$id/tracks', data: {'tracks': trackIds});
  }

  // ── Read operations ─────────────────────────────────────────────────────────

  /// GET /playlists/{id} — returns the raw playlist map (includes tracks array).
  Future<Map<String, dynamic>> fetchById(String id) async {
    final response = await _dio.get('/playlists/$id');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['playlist'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return data;
  }

  /// GET /playlists/{id}/embed — retrieve embeddable HTML snippet.
  Future<String> getEmbedCode(String id) async {
    final response = await _dio.get('/playlists/$id/embed');
    return response.data['data']['embedCode'] as String? ?? '';
  }

  // ── Track-mutation helpers (encapsulate the read-then-write pattern) ─────────

  /// Fetches the current track list, appends [trackId] (dedup), PUTs back.
  /// Returns the new track count.
  Future<int> appendTrack(String playlistId, String trackId) async {
    final playlistData = await fetchById(playlistId);
    final ids = _extractTrackIds(playlistData);
    if (!ids.contains(trackId)) ids.add(trackId);
    await replaceTracks(playlistId, ids);
    return ids.length;
  }

  /// Fetches the current track list, removes [trackId], PUTs back.
  /// Returns the new track count.
  Future<int> removeTrack(String playlistId, String trackId) async {
    final playlistData = await fetchById(playlistId);
    final ids = _extractTrackIds(playlistData)..remove(trackId);
    await replaceTracks(playlistId, ids);
    return ids.length;
  }

  /// PUT /playlists/{id}/tracks — re-PUT a fully ordered list to reorder tracks.
  Future<void> reorderTracks(String id, List<String> orderedTrackIds) =>
      replaceTracks(id, orderedTrackIds);

  // ── Artwork ─────────────────────────────────────────────────────────────────

  /// POST /playlists/{id}/artwork — upload cover image bytes.
  /// Returns the new artworkUrl.
  Future<String> uploadArtwork(
      String id, List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'artwork': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post('/playlists/$id/artwork', data: formData);
    return response.data['data']['artworkUrl'] as String? ?? '';
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  List<String> _extractTrackIds(Map<String, dynamic> playlistData) {
    final rawTracks = (playlistData['tracks'] as List<dynamic>?) ?? [];
    return rawTracks
        .map<String>((t) {
          if (t is String) return t;
          if (t is Map) {
            return (t as Map<String, dynamic>)['_id'] as String? ?? '';
          }
          return '';
        })
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
