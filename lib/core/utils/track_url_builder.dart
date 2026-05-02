const _kBioBeatsShareScheme = 'biobeats';
const _kBioBeatsShareHost = 'open';

String buildTrackUrl({
  required String trackId,
  String? artistPermalink,
  String? trackPermalink,
}) {
  final artist = artistPermalink?.trim().replaceFirst('@', '');
  final track = trackPermalink?.trim();

  final segments = artist != null &&
          artist.isNotEmpty &&
          track != null &&
          track.isNotEmpty
      ? [artist, track]
      : ['tracks', trackId.trim()];

  return Uri(
    scheme: _kBioBeatsShareScheme,
    host: _kBioBeatsShareHost,
    pathSegments: segments,
  ).toString();
}
