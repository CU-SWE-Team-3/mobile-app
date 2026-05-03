import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/playlist.dart';

class PlaylistTrackSnapshot {
  final int count;
  final String? firstTrackArtworkUrl;
  final bool containsTrack;

  const PlaylistTrackSnapshot({
    required this.count,
    required this.firstTrackArtworkUrl,
    this.containsTrack = false,
  });
}

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
    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        '/playlists',
        data: {'title': title, 'isPrivate': !isPublic},
      );
    } on DioException catch (e) {
      final raw = e.response?.data ?? e.message;
      debugPrint('[PlaylistRepository.create] raw: $raw');
      throw Exception(
        'Create playlist failed (${e.response?.statusCode}): $raw',
      );
    }
    final raw = response.data;
    debugPrint('[PlaylistRepository.create] raw: $raw');

    // Try each known response shape in order of specificity.
    String? id;
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map) {
        final playlist = data['playlist'];
        if (playlist is Map) id = playlist['_id'] as String?;
        if (id == null || id.isEmpty) {
          final set = data['set'];
          if (set is Map) id = set['_id'] as String?;
        }
        if (id == null || id.isEmpty) id = data['_id'] as String?;
      }
      if (id == null || id.isEmpty) {
        final playlist = raw['playlist'];
        if (playlist is Map) id = playlist['_id'] as String?;
      }
      if (id == null || id.isEmpty) id = raw['_id'] as String?;
    }

    if (id == null || id.isEmpty) {
      throw Exception('No _id in response: $raw');
    }
    return id;
  }

  /// PATCH /playlists/{id} — update mutable metadata fields in a single call.
  Future<void> updateMetadata(
    String id, {
    String? title,
    bool? isPublic,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (isPublic != null) body['isPublic'] = isPublic;
    if (description != null) body['description'] = description;
    if (body.isEmpty) return;
    try {
      await _dio.patch('/playlists/$id', data: body);
    } on DioException catch (e) {
      if (isPublic == null || !_shouldRetryVisibilityPatch(e)) rethrow;
      final fallback = Map<String, dynamic>.from(body)
        ..remove('isPublic')
        ..['isPrivate'] = !isPublic;
      await _dio.patch('/playlists/$id', data: fallback);
    }
  }

  /// PATCH /playlists/{id} — toggle public/private visibility.
  Future<Playlist?> updatePrivacy(String id, bool isPublic) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.patch(
        '/playlists/$id',
        data: {'isPublic': isPublic},
      );
    } on DioException catch (e) {
      if (!_shouldRetryVisibilityPatch(e)) rethrow;
      response = await _dio.patch(
        '/playlists/$id',
        data: {'isPrivate': !isPublic},
      );
    }
    final data = response.data is Map ? response.data['data'] : null;
    final raw = data is Map ? data['playlist'] : null;
    if (raw is Map) {
      return Playlist.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
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

  Future<PlaylistTrackSnapshot> trackSnapshot(
    String playlistId, {
    String? trackId,
  }) async {
    final playlistData = await fetchById(playlistId);
    final rawTracks = (playlistData['tracks'] as List<dynamic>?) ?? [];
    String? firstArtwork;
    var containsTrack = false;
    for (var index = 0; index < rawTracks.length; index++) {
      final raw = rawTracks[index];
      String id = '';
      String? artwork;
      if (raw is String) {
        id = raw;
      } else if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final nestedTrack = map['track'];
        final trackMap =
            nestedTrack is Map ? Map<String, dynamic>.from(nestedTrack) : map;
        id = (trackMap['_id'] ?? trackMap['id'] ?? map['_id'] ?? map['id'])
                ?.toString() ??
            '';
        artwork = (trackMap['artworkUrl'] ??
            trackMap['coverUrl'] ??
            map['artworkUrl'] ??
            map['coverUrl']) as String?;
      }
      if (index == 0) {
        firstArtwork = _isUsableArtworkUrl(artwork) ? artwork : null;
      }
      if (trackId != null && id == trackId) {
        containsTrack = true;
      }
    }
    return PlaylistTrackSnapshot(
      count: rawTracks.length,
      firstTrackArtworkUrl: firstArtwork,
      containsTrack: containsTrack,
    );
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

  // ── User playlist list ───────────────────────────────────────────────────────

  /// GET /playlists?creator={userId} — returns all playlists owned by [userId].
  /// Response shape mirrors ProfilePage._fetchPlaylists: data.playlists[].
  /// MongoDB _id is normalised to id before Playlist.fromJson to handle the
  /// backend's _id field that Playlist.fromJson doesn't natively read.
  /// Throws on API failure.
  Future<List<Playlist>> fetchAll(String userId) async {
    final response = await _dio.get(
      '/playlists',
      queryParameters: {'creator': userId},
    );
    final raw = response.data;
    List<dynamic> items = [];
    if (raw is Map) {
      final d = raw['data'];
      if (d is Map) {
        final p = d['playlists'];
        items = p is List ? p : [];
      }
    }
    return items.whereType<Map<String, dynamic>>().map((json) {
      final normalized = Map<String, dynamic>.from(json);
      normalized['id'] ??= normalized['_id'];
      return Playlist.fromJson(normalized);
    }).toList();
  }

  // ── Artwork ─────────────────────────────────────────────────────────────────

  /// PATCH /playlists/{id}/artwork — upload cover image bytes.
  /// Returns the new artworkUrl.
  Future<String> uploadArtwork(
      String id, List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'artwork': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.patch('/playlists/$id/artwork', data: formData);
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

  bool _isUsableArtworkUrl(String? url) =>
      url != null &&
      url.isNotEmpty &&
      url.startsWith('http') &&
      !url.contains('default');

  bool _shouldRetryVisibilityPatch(DioException e) {
    final status = e.response?.statusCode;
    return status == 400 || status == 404 || status == 422;
  }
}
