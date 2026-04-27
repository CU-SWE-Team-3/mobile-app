// ── Autocomplete models ───────────────────────────────────────────────────────

class AutocompleteTrack {
  final String id;
  final String title;
  final String? permalink;
  final String? artworkUrl;

  const AutocompleteTrack({
    required this.id,
    required this.title,
    this.permalink,
    this.artworkUrl,
  });

  factory AutocompleteTrack.fromJson(Map<String, dynamic> json) {
    return AutocompleteTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      permalink: json['permalink'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
    );
  }
}

class AutocompleteUser {
  final String id;
  final String displayName;
  final String? permalink;
  final String? avatarUrl;

  const AutocompleteUser({
    required this.id,
    required this.displayName,
    this.permalink,
    this.avatarUrl,
  });

  factory AutocompleteUser.fromJson(Map<String, dynamic> json) {
    return AutocompleteUser(
      id: json['_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      permalink: json['permalink'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class AutocompleteResult {
  final List<AutocompleteTrack> tracks;
  final List<AutocompleteUser> users;

  const AutocompleteResult({required this.tracks, required this.users});

  const AutocompleteResult.empty()
      : tracks = const [],
        users = const [];

  bool get isEmpty => tracks.isEmpty && users.isEmpty;

  factory AutocompleteResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final rawTracks = data['tracks'] as List<dynamic>? ?? [];
    final rawUsers = data['users'] as List<dynamic>? ?? [];
    return AutocompleteResult(
      tracks: rawTracks
          .whereType<Map<String, dynamic>>()
          .map(AutocompleteTrack.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList(),
      users: rawUsers
          .whereType<Map<String, dynamic>>()
          .map(AutocompleteUser.fromJson)
          .where((u) => u.id.isNotEmpty)
          .toList(),
    );
  }
}

// ── Full search models ────────────────────────────────────────────────────────

class SearchTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final int duration;
  final int playCount;
  final String hlsUrl;

  const SearchTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.artworkUrl,
    this.duration = 0,
    this.playCount = 0,
    this.hlsUrl = '',
  });

  factory SearchTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>?
        ?? json['user'] as Map<String, dynamic>?
        ?? {};
    return SearchTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      hlsUrl: json['hlsUrl'] as String? ?? json['audioUrl'] as String? ?? '',
    );
  }
}

class SearchUser {
  final String id;
  final String displayName;
  final String? permalink;
  final String? avatarUrl;
  final int followerCount;

  const SearchUser({
    required this.id,
    required this.displayName,
    this.permalink,
    this.avatarUrl,
    this.followerCount = 0,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    final fc = json['followerCount'];
    return SearchUser(
      id: json['_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      permalink: json['permalink'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      followerCount: fc is int
          ? fc
          : fc is double
              ? fc.toInt()
              : int.tryParse(fc?.toString() ?? '') ?? 0,
    );
  }
}

class SearchPlaylist {
  final String id;
  final String title;
  final String ownerName;
  final String? artworkUrl;
  final int trackCount;

  const SearchPlaylist({
    required this.id,
    required this.title,
    required this.ownerName,
    this.artworkUrl,
    this.trackCount = 0,
  });

  factory SearchPlaylist.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?
        ?? json['owner'] as Map<String, dynamic>?;
    return SearchPlaylist(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      ownerName: creator?['displayName'] as String?
          ?? json['ownerName'] as String?
          ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class FullSearchResult {
  final List<SearchTrack> tracks;
  final List<SearchUser> users;
  final List<SearchPlaylist> playlists;

  const FullSearchResult({
    required this.tracks,
    required this.users,
    required this.playlists,
  });

  const FullSearchResult.empty()
      : tracks = const [],
        users = const [],
        playlists = const [];

  bool get isEmpty => tracks.isEmpty && users.isEmpty && playlists.isEmpty;

  factory FullSearchResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    List<dynamic> rawTracks = [];
    List<dynamic> rawUsers = [];
    List<dynamic> rawPlaylists = [];

    if (rawData is Map<String, dynamic>) {
      rawTracks = rawData['tracks'] as List<dynamic>? ?? [];
      rawUsers = rawData['users'] as List<dynamic>? ?? [];
      rawPlaylists = rawData['playlists'] as List<dynamic>? ?? [];
    } else if (rawData is List) {
      // Legacy flat list — treat all items as tracks
      rawTracks = rawData;
    }

    return FullSearchResult(
      tracks: rawTracks
          .whereType<Map<String, dynamic>>()
          .map(SearchTrack.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList(),
      users: rawUsers
          .whereType<Map<String, dynamic>>()
          .map(SearchUser.fromJson)
          .where((u) => u.id.isNotEmpty)
          .toList(),
      playlists: rawPlaylists
          .whereType<Map<String, dynamic>>()
          .map(SearchPlaylist.fromJson)
          .where((p) => p.id.isNotEmpty)
          .toList(),
    );
  }
}
