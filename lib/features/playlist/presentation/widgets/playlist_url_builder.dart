import '../../domain/entities/playlist.dart';

const _kBase = 'https://biobeats.duckdns.org';

/// Returns the canonical share URL for [playlist].
/// Appends `?secret_token=...` when the playlist is private and has a token.
String buildPlaylistUrl(Playlist playlist) {
  final op = playlist.ownerPermalink;
  final pp = playlist.permalink;

  final path = (op != null && op.isNotEmpty && pp != null && pp.isNotEmpty)
      ? '$_kBase/$op/sets/$pp'
      : '$_kBase/playlists/${playlist.id}';

  final st = playlist.secretToken;
  if (!playlist.isPublic && st != null && st.isNotEmpty) {
    return '$path?secret_token=$st';
  }
  return path;
}
