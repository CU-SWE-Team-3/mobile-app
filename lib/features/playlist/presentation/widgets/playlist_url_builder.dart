import '../../domain/entities/playlist.dart';

const _kBase = 'https://biobeats.duckdns.org';

/// Returns the canonical share URL for [playlist].
/// Appends `?secretToken=...` when the playlist is private and has a token.
String buildPlaylistUrl(Playlist playlist) {
  final ownerPermalink = playlist.ownerPermalink?.trim().replaceFirst('@', '');
  final playlistPermalink = playlist.permalink?.trim();
  final path = ownerPermalink != null &&
          ownerPermalink.isNotEmpty &&
          playlistPermalink != null &&
          playlistPermalink.isNotEmpty
      ? '$_kBase/$ownerPermalink/sets/$playlistPermalink'
      : '$_kBase/playlists/${playlist.id}';

  final st = playlist.secretToken;
  if (!playlist.isPublic && st != null && st.isNotEmpty) {
    return '$path?secretToken=$st';
  }
  return path;
}
