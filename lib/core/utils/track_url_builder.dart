const _kBioBeatsShareBase = 'https://biobeats.duckdns.org';

String buildTrackUrl({
  required String trackId,
  String? artistPermalink,
  String? trackPermalink,
}) {
  final track = trackPermalink?.trim();
  final trackRef = track != null && track.isNotEmpty ? track : trackId.trim();

  return Uri.parse(_kBioBeatsShareBase)
      .replace(pathSegments: ['tracks', trackRef]).toString();
}
