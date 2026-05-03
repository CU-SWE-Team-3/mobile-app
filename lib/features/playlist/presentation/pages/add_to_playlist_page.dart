import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/playlist_repository.dart';
import '../providers/playlists_provider.dart';

// ── Lightweight playlist model (API-backed) ──────────────────────────────────

class _ApiPlaylist {
  final String id;
  final String title;
  final String? artworkUrl;
  final String? firstTrackArtworkUrl;
  final int trackCount;
  final bool isPublic;
  final bool containsTrack;

  const _ApiPlaylist({
    required this.id,
    required this.title,
    this.artworkUrl,
    this.firstTrackArtworkUrl,
    required this.trackCount,
    required this.isPublic,
    this.containsTrack = false,
  });
}

// ── Page state ───────────────────────────────────────────────────────────────

class _PageState {
  final List<_ApiPlaylist> playlists;
  final String? selectedId;
  final String avatarUrl;
  final bool loadingPlaylists;
  final bool submitting;
  final String? error;

  const _PageState({
    this.playlists = const [],
    this.selectedId,
    this.avatarUrl = '',
    this.loadingPlaylists = true,
    this.submitting = false,
    this.error,
  });

  _PageState copyWith({
    List<_ApiPlaylist>? playlists,
    String? selectedId,
    String? avatarUrl,
    bool clearSelected = false,
    bool? loadingPlaylists,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) =>
      _PageState(
        playlists: playlists ?? this.playlists,
        selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
        avatarUrl: avatarUrl ?? this.avatarUrl,
        loadingPlaylists: loadingPlaylists ?? this.loadingPlaylists,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class _AddToPlaylistNotifier extends StateNotifier<_PageState> {
  final String trackId;
  final PlaylistRepository _repository;
  final Ref _ref;

  _AddToPlaylistNotifier(
      {required this.trackId,
      required PlaylistRepository repository,
      required Ref ref})
      : _repository = repository,
        _ref = ref,
        super(const _PageState()) {
    _fetchPlaylists();
  }

  Future<void> _fetchPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatarUrl = prefs.getString('avatarUrl') ?? '';
      // Read from the same local store that Library → Playlists uses so both
      // pages always show the same set of playlists.
      final raw = prefs.getString('playlists_data');
      final decoded = raw != null && raw.isNotEmpty
          ? (jsonDecode(raw) as List<dynamic>)
          : <dynamic>[];
      final playlists = decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => _ApiPlaylist(
                id: json['id'] as String? ?? '',
                title: json['title'] as String? ?? '',
                artworkUrl: json['artworkUrl'] as String?,
                firstTrackArtworkUrl: json['firstTrackArtworkUrl'] as String?,
                trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
                isPublic: json['isPublic'] as bool? ?? true,
              ))
          .where((p) => p.id.isNotEmpty)
          .toList();
      if (mounted) {
        state = state.copyWith(
          playlists: playlists,
          avatarUrl: avatarUrl,
          loadingPlaylists: false,
          clearError: true,
        );
      }
      _hydratePlaylists(playlists);
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          loadingPlaylists: false,
          error: 'Failed to load playlists.',
        );
      }
    }
  }

  void select(String playlistId) {
    final playlist = _findPlaylist(playlistId);
    if (playlist?.containsTrack == true) return;
    state = state.copyWith(selectedId: playlistId, clearError: true);
  }

  // Returns true on success. Caller checks and pops / shows error.
  Future<bool> addTrackToSelected() async {
    final playlistId = state.selectedId;
    if (playlistId == null) return false;
    if (_findPlaylist(playlistId)?.containsTrack == true) {
      state = state.copyWith(error: 'This track is already in that playlist.');
      return false;
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      await _repository.appendTrack(playlistId, trackId);
      final snapshot = await _repository.trackSnapshot(playlistId);

      // Sync the real track count back into the local cache so that
      // Library → Playlists shows the correct number immediately.
      await _syncLocalPlaylistPreview(
        playlistId,
        snapshot.count,
        firstTrackArtworkUrl: snapshot.firstTrackArtworkUrl,
      );
      _ref.read(playlistsProvider.notifier).updateTrackPreview(
            playlistId,
            snapshot.count,
            firstTrackArtworkUrl: snapshot.firstTrackArtworkUrl,
            replaceArtwork: true,
          );

      if (mounted) state = state.copyWith(submitting: false);
      return true;
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          submitting: false,
          error: 'Failed to add track to playlist.',
        );
      }
      return false;
    }
  }

  _ApiPlaylist? _findPlaylist(String playlistId) {
    for (final playlist in state.playlists) {
      if (playlist.id == playlistId) return playlist;
    }
    return null;
  }

  Future<void> _hydratePlaylists(List<_ApiPlaylist> playlists) async {
    final hydrated = <_ApiPlaylist>[];
    for (final playlist in playlists) {
      try {
        final snapshot =
            await _repository.trackSnapshot(playlist.id, trackId: trackId);
        hydrated.add(_ApiPlaylist(
          id: playlist.id,
          title: playlist.title,
          artworkUrl: playlist.artworkUrl,
          firstTrackArtworkUrl: snapshot.firstTrackArtworkUrl,
          trackCount: snapshot.count,
          isPublic: playlist.isPublic,
          containsTrack: snapshot.containsTrack,
        ));
      } catch (_) {
        hydrated.add(playlist);
      }
    }
    if (mounted) state = state.copyWith(playlists: hydrated);
  }

  // Writes the updated track count for [playlistId] into SharedPreferences so
  // Library → Playlists reflects the real count without a full re-fetch.
  Future<void> _syncLocalPlaylistPreview(
    String playlistId,
    int newCount, {
    String? firstTrackArtworkUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('playlists_data');
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      bool changed = false;
      for (final entry in list) {
        if (entry['id'] == playlistId) {
          entry['trackCount'] = newCount;
          if (newCount == 0) {
            entry.remove('firstTrackArtworkUrl');
          } else {
            entry['firstTrackArtworkUrl'] = firstTrackArtworkUrl;
          }
          changed = true;
          break;
        }
      }
      if (changed) {
        await prefs.setString('playlists_data', jsonEncode(list));
      }
    } catch (_) {
      // Best-effort; a stale count is non-critical.
    }
  }
}

// ── Provider (auto-dispose family keyed by trackId) ──────────────────────────

final _addToPlaylistProvider = StateNotifierProvider.autoDispose
    .family<_AddToPlaylistNotifier, _PageState, String>(
  (ref, trackId) => _AddToPlaylistNotifier(
    trackId: trackId,
    repository: ref.read(playlistRepositoryProvider),
    ref: ref,
  ),
);

// ── Page ─────────────────────────────────────────────────────────────────────

class AddToPlaylistPage extends ConsumerWidget {
  final String trackId;
  const AddToPlaylistPage({super.key, required this.trackId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_addToPlaylistProvider(trackId));
    final notifier = ref.read(_addToPlaylistProvider(trackId).notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('playlist_back_button'),
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Add to playlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (state.submitting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            TextButton(
              key: const ValueKey('playlist_add_tracks_button'),
              onPressed: state.selectedId == null
                  ? null
                  : () async {
                      final success = await notifier.addTrackToSelected();
                      if (!context.mounted) return;
                      if (success) {
                        Navigator.maybePop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Track added to playlist'),
                            backgroundColor: Color(0xFF1F1F1F),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: Text(
                'Done',
                style: TextStyle(
                  color: state.selectedId == null
                      ? Colors.white38
                      : const Color(0xFFFF5500),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.error != null)
            Container(
              width: double.infinity,
              color: const Color(0xFF3A1A1A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                state.error!,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
              ),
            ),
          Expanded(
            child: state.loadingPlaylists
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white54))
                : state.playlists.isEmpty
                    ? const Center(
                        child: Text(
                          'No playlists found.\nCreate a playlist first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white54, fontSize: 15, height: 1.5),
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.playlists.length,
                        itemBuilder: (_, i) {
                          final pl = state.playlists[i];
                          return _PlaylistRow(
                            key: ValueKey('playlist_tile_${pl.id}'),
                            playlist: pl,
                            avatarUrl: state.avatarUrl,
                            isSelected: state.selectedId == pl.id,
                            onTap: () => notifier.select(pl.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Playlist row ─────────────────────────────────────────────────────────────

class _PlaylistRow extends StatelessWidget {
  final _ApiPlaylist playlist;
  final String avatarUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlaylistRow({
    super.key,
    required this.playlist,
    required this.avatarUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final artworkUrl = _resolvedArtworkUrl();
    return InkWell(
      onTap: playlist.containsTrack ? null : onTap,
      splashColor: Colors.white10,
      highlightColor: Colors.white10,
      child: KeyedSubtree(
        key: const ValueKey('playlist_tile'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: artworkUrl != null
                      ? CachedNetworkImage(
                          imageUrl: artworkUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _artworkPlaceholder(),
                          errorWidget: (_, __, ___) => _artworkPlaceholder(),
                        )
                      : _artworkPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: playlist.containsTrack ? 0.72 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            playlist.containsTrack
                                ? 'Already added'
                                : '${playlist.trackCount} '
                                    '${playlist.trackCount == 1 ? 'track' : 'tracks'}',
                            style: const TextStyle(
                                color: Color(0xFF999999), fontSize: 12),
                          ),
                          if (!playlist.isPublic) ...[
                            const Text(' · ',
                                style: TextStyle(
                                    color: Color(0xFF999999), fontSize: 12)),
                            const Icon(Icons.lock_outline,
                                color: Color(0xFF999999), size: 12),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isSelected ? const Color(0xFFFF5500) : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF5500)
                        : const Color(0xFF666666),
                    width: 2,
                  ),
                ),
                child: playlist.containsTrack
                    ? const Icon(Icons.check,
                        color: Color(0xFF999999), size: 14)
                    : isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolvedArtworkUrl() {
    if (_isUsableArtworkUrl(playlist.artworkUrl)) return playlist.artworkUrl;
    if (playlist.trackCount > 0) {
      return _isUsableArtworkUrl(playlist.firstTrackArtworkUrl)
          ? playlist.firstTrackArtworkUrl
          : null;
    }
    return _isUsableAvatarUrl(avatarUrl) ? avatarUrl : null;
  }

  bool _isUsableArtworkUrl(String? url) =>
      url != null &&
      url.isNotEmpty &&
      url.startsWith('http') &&
      !url.contains('default');

  bool _isUsableAvatarUrl(String? url) =>
      url != null &&
      url.isNotEmpty &&
      url.startsWith('http') &&
      !url.contains('default-avatar');

  Widget _artworkPlaceholder() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.music_note, color: Colors.white38, size: 24),
        ),
      );
}
