import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/playlist.dart';

/// Fetches a single playlist by id from GET /playlists/{playlistId}.
/// Mirrors the same fetch pattern used in PlaylistDetailsPage._loadTracks.
/// autoDispose so the cache is released when no card is visible.
final playlistByIdProvider =
    FutureProvider.autoDispose.family<Playlist, String>((ref, playlistId) async {
  final response = await dioClient.dio.get('/playlists/$playlistId');
  final data = response.data['data'] as Map<String, dynamic>? ?? {};
  final playlistData = data['playlist'] as Map<String, dynamic>? ?? {};
  final creator = playlistData['creator'] as Map<String, dynamic>?;

  return Playlist(
    id: playlistId,
    title: playlistData['title'] as String? ?? '',
    artworkUrl: playlistData['artworkUrl'] as String?,
    ownerName: (playlistData['ownerName'] as String?) ??
        (creator?['displayName'] as String?) ??
        '',
    trackCount: (playlistData['trackCount'] as num?)?.toInt() ?? 0,
    isPublic: playlistData['isPublic'] as bool? ?? true,
  );
});
