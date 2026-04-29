/// A reference pointer to an existing track or playlist.
/// [referenceId] is the MongoDB ObjectId of the referenced entity.
/// [title], [artworkUrl], [permalink], [artistName], [duration] are populated
/// by the REST API when fetching conversation history; absent from socket payloads.
class Attachment {
  final String type; // 'track' | 'playlist'
  final String referenceId;
  final String? title;
  final String? artworkUrl;
  final String? permalink;
  final String? artistName;
  final int? duration; // seconds

  const Attachment({
    required this.type,
    required this.referenceId,
    this.title,
    this.artworkUrl,
    this.permalink,
    this.artistName,
    this.duration,
  });

  bool get hasRichData => title != null && title!.isNotEmpty;

  bool get isAvailable => referenceId.isNotEmpty;

  factory Attachment.fromJson(Map<String, dynamic> json) {
    final type = _normalizeType(json['type']?.toString());
    final refRaw = json['referenceId'] ??
        json['reference'] ??
        json['attachmentId'] ??
        json['targetId'] ??
        json['trackId'] ??
        json['playlistId'] ??
        json['id'] ??
        json['_id'];

    String referenceId;
    String? title;
    String? artworkUrl;
    String? permalink;
    String? artistName;
    int? duration;

    if (refRaw is Map) {
      // REST endpoint populates the reference as an embedded object.
      final refMap = Map<String, dynamic>.from(refRaw);
      referenceId =
          refMap['_id']?.toString() ?? refMap['id']?.toString() ?? '';
      title = _firstString(refMap, const ['title', 'name']);
      artworkUrl = _firstString(refMap, const [
        'artworkUrl',
        'coverUrl',
        'imageUrl',
        'thumbnailUrl',
        'firstTrackArtworkUrl',
      ]);
      permalink = _firstString(refMap, const ['permalink', 'slug']);

      final artistRaw = refMap['artist'] ?? refMap['user'];
      if (artistRaw is Map) {
        final a = Map<String, dynamic>.from(artistRaw);
        final name = a['displayName'] ?? a['username'] ?? a['name'];
        artistName = name?.toString();
      }

      final durRaw = refMap['duration'];
      duration = durRaw is num ? durRaw.toInt() : null;
    } else {
      // Socket payload or already-flattened REST — referenceId is a string.
      referenceId = refRaw?.toString() ?? '';
      title = _firstString(json, const ['title', 'name']);
      artworkUrl = _firstString(json, const [
        'artworkUrl',
        'coverUrl',
        'imageUrl',
        'thumbnailUrl',
        'firstTrackArtworkUrl',
      ]);
      permalink = _firstString(json, const ['permalink', 'slug']);
      artistName = _firstString(json, const ['artistName', 'ownerName']);
      duration = (json['duration'] as num?)?.toInt();
    }

    return Attachment(
      type: type,
      referenceId: referenceId,
      title: title,
      artworkUrl: artworkUrl,
      permalink: permalink,
      artistName: artistName,
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'referenceId': referenceId,
        if (title != null) 'title': title,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
        if (permalink != null) 'permalink': permalink,
        if (artistName != null) 'artistName': artistName,
        if (duration != null) 'duration': duration,
      };

  static String _normalizeType(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.contains('playlist')) return 'playlist';
    if (value.contains('track')) return 'track';
    return value;
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }
}
