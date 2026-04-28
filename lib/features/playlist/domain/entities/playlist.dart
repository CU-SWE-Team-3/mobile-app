class Playlist {
  final String id;
  final String title;
  final String? artworkUrl;
  // Persisted by _PlaylistNotifier after fetching GET /playlists/{id} once.
  // Null until the backfill fetch completes. Never stored in the API response.
  final String? firstTrackArtworkUrl;
  final String ownerName;
  final int trackCount;
  final bool isPublic;
  final String? permalink;
  final String? ownerPermalink;
  final String? secretToken;

  Playlist({
    String? id,
    required this.title,
    this.artworkUrl,
    this.firstTrackArtworkUrl,
    required this.ownerName,
    this.trackCount = 0,
    this.isPublic = true,
    this.permalink,
    this.ownerPermalink,
    this.secretToken,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artworkUrl': artworkUrl,
        'firstTrackArtworkUrl': firstTrackArtworkUrl,
        'ownerName': ownerName,
        'trackCount': trackCount,
        'isPublic': isPublic,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    return Playlist(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      firstTrackArtworkUrl: json['firstTrackArtworkUrl'] as String?,
      ownerName: (json['ownerName'] as String?) ??
          (creator?['displayName'] as String?) ??
          '',
      trackCount: json['trackCount'] as int? ?? 0,
      isPublic: json['isPublic'] as bool? ?? true,
      permalink: json['permalink'] as String?,
      ownerPermalink: (json['ownerPermalink'] as String?) ??
          (creator?['permalink'] as String?),
      secretToken: json['secretToken'] as String?,
    );
  }
}
