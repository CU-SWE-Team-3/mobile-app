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
    final type = (json['type'] as String? ?? '').toLowerCase();
    final refRaw = json['referenceId'];

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
      title = refMap['title'] as String?;
      artworkUrl = refMap['artworkUrl'] as String?;
      permalink = refMap['permalink'] as String?;

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
      title = json['title'] as String?;
      artworkUrl = json['artworkUrl'] as String?;
      permalink = json['permalink'] as String?;
      artistName = json['artistName'] as String?;
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
}
