import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/playlist_repository.dart';
import '../../domain/entities/playlist.dart';

const _kPlaylistsKey = 'playlists_data';

class PlaylistNotifier extends StateNotifier<List<Playlist>> {
  PlaylistNotifier(this._repository) : super([]) {
    _load();
  }

  final PlaylistRepository _repository;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlaylistsKey);
    if (raw != null && raw.isNotEmpty) {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        state = list;
        // Backfill firstTrackArtworkUrl for cached playlists missing it.
        _backfillArtwork();
      }
    }

    // Server refresh: fetch authoritative list so fresh installs and stale
    // caches get up-to-date data. Runs after cache so UI appears instantly.
    final userId = prefs.getString('userId') ?? '';
    if (userId.isEmpty) return;
    try {
      final serverList = await _repository.fetchAll(userId);
      if (!mounted) return;
      // Preserve already-backfilled firstTrackArtworkUrl from cached state so
      // _backfillArtwork doesn't re-fetch every playlist on every startup.
      final cached = {for (final p in state) p.id: p};
      state = serverList.map((p) {
        final prev = cached[p.id];
        if (prev?.firstTrackArtworkUrl == null) return p;
        return Playlist(
          id: p.id,
          title: p.title,
          artworkUrl: p.artworkUrl,
          firstTrackArtworkUrl: prev!.firstTrackArtworkUrl,
          ownerName: p.ownerName,
          trackCount: p.trackCount,
          isPublic: p.isPublic,
          permalink: p.permalink,
          ownerPermalink: p.ownerPermalink,
          creatorId: p.creatorId,
          secretToken: p.secretToken,
        );
      }).toList();
      _backfillArtwork();
      await _persist();
    } catch (_) {
      // Offline or server error — cached state is retained as-is.
    }
  }

  // Fetches GET /playlists/{id} for each playlist missing firstTrackArtworkUrl.
  // Runs sequentially with 300 ms throttle to avoid hammering the API.
  Future<void> _backfillArtwork() async {
    for (final p in List<Playlist>.from(state)) {
      if (!mounted) return;
      if (p.firstTrackArtworkUrl != null) continue;
      await _fetchAndStoreFirstTrackArtwork(p.id);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _fetchAndStoreFirstTrackArtwork(String playlistId) async {
    try {
      final playlistData = await _repository.fetchById(playlistId);
      final tracks = playlistData['tracks'] as List? ?? [];
      String? artwork;
      for (final raw in tracks) {
        if (raw is Map<String, dynamic>) {
          final url = raw['artworkUrl'] as String?;
          if (url != null &&
              url.startsWith('https://') &&
              !url.contains('default')) {
            artwork = url;
            break;
          }
        }
      }
      if (artwork == null || !mounted) return;
      state = state.map((p) {
        if (p.id != playlistId) return p;
        return Playlist(
          id: p.id,
          title: p.title,
          artworkUrl: p.artworkUrl,
          firstTrackArtworkUrl: artwork,
          ownerName: p.ownerName,
          trackCount: p.trackCount,
          isPublic: p.isPublic,
          permalink: p.permalink,
          ownerPermalink: p.ownerPermalink,
          creatorId: p.creatorId,
          secretToken: p.secretToken,
        );
      }).toList();
      await _persist();
    } catch (_) {}
  }

  /// Appends [playlist] to local state and persists. Does not call the API —
  /// callers are responsible for creating the playlist on the server first.
  Future<void> add(Playlist playlist) async {
    state = [...state, playlist];
    await _persist();
  }

  /// Calls DELETE /playlists/{id} then removes the playlist from local state.
  /// Throws on API failure so calling UI can surface feedback.
  Future<void> remove(String id) async {
    await _repository.deletePlaylist(id);
    state = state.where((p) => p.id != id).toList();
    await _persist();
  }

  /// Calls PATCH /playlists/{id} to update visibility, then mirrors the change
  /// into local state. Throws on API failure (state is not mutated on error).
  Future<void> updateVisibility(String id, bool isPublic) async {
    await _repository.updatePrivacy(id, isPublic);
    state = state
        .map((p) => p.id == id
            ? Playlist(
                id: p.id,
                title: p.title,
                artworkUrl: p.artworkUrl,
                firstTrackArtworkUrl: p.firstTrackArtworkUrl,
                ownerName: p.ownerName,
                trackCount: p.trackCount,
                isPublic: isPublic,
                permalink: p.permalink,
                ownerPermalink: p.ownerPermalink,
                creatorId: p.creatorId,
                secretToken: p.secretToken,
              )
            : p)
        .toList();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPlaylistsKey, jsonEncode(state.map((p) => p.toJson()).toList()));
  }

  /// PATCH /playlists/{id} — title, visibility, and description in one call.
  /// Throws on any API failure — state is not mutated on error.
  /// Pass [artworkUrl] when the caller has already uploaded new artwork so the
  /// in-memory Playlist reflects the new cover without a separate reload.
  Future<void> updateMetadata(
    String id, {
    required String title,
    required bool isPublic,
    String? artworkUrl,
    String? description,
  }) async {
    await _repository.updateMetadata(
      id,
      title: title,
      isPublic: isPublic,
      description: description,
    );
    state = state
        .map((p) => p.id == id
            ? Playlist(
                id: p.id,
                title: title,
                artworkUrl: artworkUrl ?? p.artworkUrl,
                firstTrackArtworkUrl: p.firstTrackArtworkUrl,
                ownerName: p.ownerName,
                trackCount: p.trackCount,
                isPublic: isPublic,
                permalink: p.permalink,
                ownerPermalink: p.ownerPermalink,
                creatorId: p.creatorId,
                secretToken: p.secretToken,
              )
            : p)
        .toList();
    await _persist();
  }

  /// Updates the cached track count after a server-side track mutation.
  /// Local-only — no API call. Persist is fire-and-forget.
  void updateTrackCount(String id, int newCount) {
    state = state
        .map((p) => p.id == id
            ? Playlist(
                id: p.id,
                title: p.title,
                artworkUrl: p.artworkUrl,
                firstTrackArtworkUrl: p.firstTrackArtworkUrl,
                ownerName: p.ownerName,
                trackCount: newCount,
                isPublic: p.isPublic,
                permalink: p.permalink,
                ownerPermalink: p.ownerPermalink,
                creatorId: p.creatorId,
                secretToken: p.secretToken,
              )
            : p)
        .toList();
    _persist(); // fire-and-forget
  }

  Future<void> reload() => _load();
}

final playlistRepositoryProvider = Provider((_) => PlaylistRepository());

final playlistsProvider =
    StateNotifierProvider<PlaylistNotifier, List<Playlist>>(
  (ref) => PlaylistNotifier(ref.read(playlistRepositoryProvider)),
);
