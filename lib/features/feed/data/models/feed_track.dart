import 'package:soundcloud_clone/features/player/domain/entities/player_track.dart';

class FeedTrack {
  final String id;
  final String title;
  final String? artworkUrl;
  final String? audioUrl;
  final String artistId;
  final String artistName;
  final String? artistAvatarUrl;
  final String? artistPermalink;
  final int likeCount;
  final int repostCount;
  final int commentCount;
  final bool isLiked;
  final bool isReposted;
  final List<int>? waveform;
  // Following-feed activity fields — null for Discover tracks.
  final String? activityType;       // "post" or "repost"
  final String? actorName;
  final String? actorAvatarUrl;
  final DateTime? activityTimestamp;

  const FeedTrack({
    required this.id,
    required this.title,
    this.artworkUrl,
    this.audioUrl,
    required this.artistId,
    required this.artistName,
    this.artistAvatarUrl,
    this.artistPermalink,
    this.likeCount = 0,
    this.repostCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isReposted = false,
    this.waveform,
    this.activityType,
    this.actorName,
    this.actorAvatarUrl,
    this.activityTimestamp,
  });

  factory FeedTrack.fromJson(Map<String, dynamic> json) {
    // Use is-checks instead of direct casts: the trending endpoint may include
    // an 'artist' field that isn't a Map (e.g. a genre string), which would
    // cause `as Map<String, dynamic>?` to throw a TypeError at runtime.
    final rawArtist = json['artist'];
    final rawUser = json['user'];
    final artistMap = (rawArtist is Map<String, dynamic> ? rawArtist : null) ??
        (rawUser is Map<String, dynamic> ? rawUser : null) ??
        const <String, dynamic>{};

    // Activity metadata is injected under underscore-prefixed keys by
    // followingFeedProvider's extractor so they never collide with real track
    // fields. Discover tracks won't have these keys → fields stay null.
    final rawActor = json['_actor'];
    final actorMap = rawActor is Map<String, dynamic> ? rawActor : null;
    final String? tsRaw = json['_activityTimestamp'] as String?;

    return FeedTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
      artistId: artistMap['_id'] as String? ?? '',
      artistName: artistMap['displayName'] as String? ?? '',
      artistAvatarUrl: artistMap['avatarUrl'] as String?,
      artistPermalink: artistMap['permalink'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isReposted: json['isReposted'] as bool? ?? false,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      activityType: json['_activityType'] as String?,
      actorName: actorMap?['displayName'] as String?,
      actorAvatarUrl: actorMap?['avatarUrl'] as String?,
      activityTimestamp: tsRaw != null ? DateTime.tryParse(tsRaw) : null,
    );
  }

  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: id,
        title: title,
        artist: artistName,
        audioUrl: audioUrl ?? '',
        coverUrl: artworkUrl,
        waveform: waveform,
        artistId: artistId.isNotEmpty ? artistId : null,
        artistPermalink: artistPermalink,
      );
}
