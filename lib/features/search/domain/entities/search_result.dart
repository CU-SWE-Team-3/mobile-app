enum SearchEntityType { track, user, playlist }

class SearchResultTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
  final String? artworkUrl;
  final String hlsUrl;
  final int? durationSeconds;
  final int playCount;
  final List<int>? waveform;

  const SearchResultTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.artistPermalink,
    this.artworkUrl,
    required this.hlsUrl,
    this.durationSeconds,
    this.playCount = 0,
    this.waveform,
  });

  factory SearchResultTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] is Map<String, dynamic>
        ? json['artist'] as Map<String, dynamic>
        : json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : <String, dynamic>{};
    return SearchResultTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ??
          artist['username'] as String? ??
          json['artistName'] as String? ??
          '',
      artistId: artist['_id'] as String?,
      artistPermalink: artist['permalink'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String? ?? '',
      durationSeconds: (json['duration'] as num?)?.toInt(),
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

class SearchResultUser {
  final String id;
  final String displayName;
  final String? permalink;
  final String? avatarUrl;
  final String? bio;
  final int followerCount;

  const SearchResultUser({
    required this.id,
    required this.displayName,
    this.permalink,
    this.avatarUrl,
    this.bio,
    this.followerCount = 0,
  });

  factory SearchResultUser.fromJson(Map<String, dynamic> json) {
    final fc = json['followerCount'];
    return SearchResultUser(
      id: json['_id'] as String? ?? '',
      displayName: json['displayName'] as String? ??
          json['username'] as String? ??
          '',
      permalink: json['permalink'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      followerCount: fc is int ? fc : int.tryParse(fc?.toString() ?? '') ?? 0,
    );
  }
}

class SearchResultPlaylist {
  final String id;
  final String title;
  final String? artworkUrl;
  final String? creatorName;
  final String? creatorId;
  final int trackCount;

  const SearchResultPlaylist({
    required this.id,
    required this.title,
    this.artworkUrl,
    this.creatorName,
    this.creatorId,
    this.trackCount = 0,
  });

  factory SearchResultPlaylist.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] is Map<String, dynamic>
        ? json['creator'] as Map<String, dynamic>
        : json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : null;
    final tc = json['trackCount'];
    final tracks = json['tracks'];
    return SearchResultPlaylist(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      creatorName:
          creator?['displayName'] as String? ?? json['ownerName'] as String?,
      creatorId: creator?['_id'] as String?,
      trackCount: tc is int
          ? tc
          : tracks is List
              ? tracks.length
              : 0,
    );
  }
}

class SearchHistoryEntry {
  final String id;
  final SearchEntityType type;
  final String displayName;
  final String subtitle;
  final String? imageUrl;
  final String? permalink;
  final String? hlsUrl;
  final String? artistId;
  final DateTime addedAt;

  const SearchHistoryEntry({
    required this.id,
    required this.type,
    required this.displayName,
    required this.subtitle,
    this.imageUrl,
    this.permalink,
    this.hlsUrl,
    this.artistId,
    required this.addedAt,
  });

  SearchHistoryEntry copyWith({
    String? id,
    SearchEntityType? type,
    String? displayName,
    String? subtitle,
    String? imageUrl,
    String? permalink,
    String? hlsUrl,
    String? artistId,
    DateTime? addedAt,
  }) =>
      SearchHistoryEntry(
        id: id ?? this.id,
        type: type ?? this.type,
        displayName: displayName ?? this.displayName,
        subtitle: subtitle ?? this.subtitle,
        imageUrl: imageUrl ?? this.imageUrl,
        permalink: permalink ?? this.permalink,
        hlsUrl: hlsUrl ?? this.hlsUrl,
        artistId: artistId ?? this.artistId,
        addedAt: addedAt ?? this.addedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'displayName': displayName,
        'subtitle': subtitle,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (permalink != null) 'permalink': permalink,
        if (hlsUrl != null) 'hlsUrl': hlsUrl,
        if (artistId != null) 'artistId': artistId,
        'addedAt': addedAt.toIso8601String(),
      };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SearchHistoryEntry(
        id: json['id'] as String? ?? '',
        type: SearchEntityType.values.firstWhere(
          (e) => e.name == (json['type'] as String?),
          orElse: () => SearchEntityType.track,
        ),
        displayName: json['displayName'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        permalink: json['permalink'] as String?,
        hlsUrl: json['hlsUrl'] as String?,
        artistId: json['artistId'] as String?,
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  factory SearchHistoryEntry.fromTrack(SearchResultTrack t) =>
      SearchHistoryEntry(
        id: t.id,
        type: SearchEntityType.track,
        displayName: t.title,
        subtitle: t.artistName,
        imageUrl: t.artworkUrl,
        hlsUrl: t.hlsUrl.isEmpty ? null : t.hlsUrl,
        artistId: t.artistId,
        addedAt: DateTime.now(),
      );

  factory SearchHistoryEntry.fromUser(SearchResultUser u) =>
      SearchHistoryEntry(
        id: u.id,
        type: SearchEntityType.user,
        displayName: u.displayName,
        subtitle: u.bio != null && u.bio!.isNotEmpty
            ? u.bio!
            : '${u.followerCount} followers',
        imageUrl: u.avatarUrl,
        permalink: u.permalink,
        addedAt: DateTime.now(),
      );

  factory SearchHistoryEntry.fromPlaylist(SearchResultPlaylist p) =>
      SearchHistoryEntry(
        id: p.id,
        type: SearchEntityType.playlist,
        displayName: p.title,
        subtitle: p.creatorName ?? '',
        imageUrl: p.artworkUrl,
        addedAt: DateTime.now(),
      );
}
