import 'package:dio/dio.dart';

class ResourceResolverService {
  const ResourceResolverService(this._dio);

  final Dio _dio;

  Future<ResourceResolution> resolve(Uri uri) async {
    final parsed = ParsedResourceLink.parse(uri);

    switch (parsed.kind) {
      case ResourceLinkKind.user:
        return ResourceResolution.user(permalink: parsed.userPermalink!);
      case ResourceLinkKind.track:
        return _resolveTrack(parsed);
      case ResourceLinkKind.playlistById:
        return _resolvePlaylistById(parsed);
      case ResourceLinkKind.playlistByPermalink:
        return _resolvePlaylistByPermalink(parsed);
      case ResourceLinkKind.unknown:
        return const ResourceResolution.ignored();
    }
  }

  Future<ResourceResolution> _resolveTrack(ParsedResourceLink parsed) async {
    final permalink = parsed.trackPermalink;
    if (permalink == null || permalink.isEmpty) {
      return const ResourceResolution.notFound(
        message: 'This track link is missing its permalink.',
      );
    }

    try {
      final response = await _dio.get('/tracks/$permalink');
      final body = response.data;
      final inner = body is Map ? (body['data'] ?? body) : body;
      final rawTrack = inner is Map<String, dynamic>
          ? (inner['track'] is Map<String, dynamic>
              ? inner['track'] as Map<String, dynamic>
              : inner)
          : null;
      if (rawTrack == null) {
        return const ResourceResolution.notFound(
          message: 'We could not open that track link.',
        );
      }

      return ResourceResolution.track(
        trackId: (rawTrack['_id'] ?? rawTrack['id'] ?? '').toString(),
        title: (rawTrack['title'] ?? '').toString(),
        artworkUrl: rawTrack['artworkUrl'] as String?,
        durationSeconds: (rawTrack['duration'] as num?)?.toInt(),
        trackPermalink: rawTrack['permalink']?.toString() ?? permalink,
        artistId: _readArtistId(rawTrack),
        artistName: _readArtistName(rawTrack),
        artistPermalink: _readArtistPermalink(rawTrack),
      );
    } catch (_) {
      return const ResourceResolution.notFound(
        message: 'We could not open that track link.',
      );
    }
  }

  Future<ResourceResolution> _resolvePlaylistById(
    ParsedResourceLink parsed,
  ) async {
    final playlistId = parsed.playlistId;
    if (playlistId == null || playlistId.isEmpty) {
      return const ResourceResolution.notFound(
        message: 'This playlist link is missing its ID.',
      );
    }

    try {
      await _dio.get(
        '/playlists/$playlistId',
        queryParameters: {
          if (parsed.secretToken != null && parsed.secretToken!.isNotEmpty)
            'secretToken': parsed.secretToken,
        },
      );
      return ResourceResolution.playlist(
        playlistId: playlistId,
        secretToken: parsed.secretToken,
      );
    } catch (_) {
      return const ResourceResolution.notFound(
        message: 'We could not open that playlist link.',
      );
    }
  }

  Future<ResourceResolution> _resolvePlaylistByPermalink(
    ParsedResourceLink parsed,
  ) async {
    final userPermalink = parsed.userPermalink;
    final playlistPermalink = parsed.playlistPermalink;
    if (userPermalink == null ||
        userPermalink.isEmpty ||
        playlistPermalink == null ||
        playlistPermalink.isEmpty) {
      return const ResourceResolution.notFound(
        message: 'This playlist link is missing playlist details.',
      );
    }

    try {
      final profileResponse = await _dio.get('/profile/$userPermalink');
      final profileBody = profileResponse.data;
      final profileInner =
          profileBody is Map ? (profileBody['data'] ?? profileBody) : null;
      final profile = profileInner is Map
          ? (profileInner['user'] ??
              profileInner['profile'] ??
              profileInner['publicProfile'] ??
              profileInner)
          : null;
      final creatorId = profile is Map
          ? (profile['_id'] ?? profile['id'] ?? profile['userId'])?.toString()
          : null;
      if (creatorId == null || creatorId.isEmpty) {
        return const ResourceResolution.notFound(
          message: 'We could not open that playlist link.',
        );
      }

      final playlistsResponse = await _dio.get(
        '/playlists',
        queryParameters: {'creator': creatorId},
      );
      final playlists = _extractList(playlistsResponse.data, 'playlists');
      for (final item in playlists) {
        if (item is! Map) continue;
        final playlist = Map<String, dynamic>.from(item);
        if (playlist['permalink']?.toString() != playlistPermalink) continue;
        final id = (playlist['_id'] ?? playlist['id'])?.toString();
        if (id == null || id.isEmpty) break;
        return ResourceResolution.playlist(
          playlistId: id,
          secretToken: parsed.secretToken,
        );
      }
      return const ResourceResolution.notFound(
        message: 'We could not open that playlist link.',
      );
    } catch (_) {
      return const ResourceResolution.notFound(
        message: 'We could not open that playlist link.',
      );
    }
  }

  static List<dynamic> _extractList(dynamic body, String key) {
    if (body is List) return body;
    if (body is! Map) return const [];
    final data = body['data'];
    if (data is List) return data;
    if (data is Map && data[key] is List) return data[key] as List;
    if (body[key] is List) return body[key] as List;
    return const [];
  }

  static Map<String, dynamic> _artistMap(Map<String, dynamic> rawTrack) {
    final artistRaw = rawTrack['artist'] ?? rawTrack['user'];
    if (artistRaw is Map<String, dynamic>) return artistRaw;
    if (artistRaw is Map) return Map<String, dynamic>.from(artistRaw);
    return const {};
  }

  static String _readArtistId(Map<String, dynamic> rawTrack) {
    final artist = _artistMap(rawTrack);
    return (artist['_id'] ?? artist['id'] ?? '').toString();
  }

  static String _readArtistName(Map<String, dynamic> rawTrack) {
    final artist = _artistMap(rawTrack);
    return (artist['displayName'] ??
            artist['username'] ??
            artist['name'] ??
            rawTrack['artistName'] ??
            '')
        .toString();
  }

  static String? _readArtistPermalink(Map<String, dynamic> rawTrack) {
    final artist = _artistMap(rawTrack);
    final permalink = artist['permalink']?.toString();
    return permalink != null && permalink.isNotEmpty ? permalink : null;
  }
}

enum ResourceLinkKind {
  user,
  track,
  playlistById,
  playlistByPermalink,
  unknown,
}

class ParsedResourceLink {
  const ParsedResourceLink._({
    required this.kind,
    this.userPermalink,
    this.trackPermalink,
    this.playlistId,
    this.playlistPermalink,
    this.secretToken,
  });

  final ResourceLinkKind kind;
  final String? userPermalink;
  final String? trackPermalink;
  final String? playlistId;
  final String? playlistPermalink;
  final String? secretToken;

  factory ParsedResourceLink.parse(Uri uri) {
    final segments = uri.pathSegments
        .map(Uri.decodeComponent)
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    final secretToken = uri.queryParameters['secretToken'] ??
        uri.queryParameters['secret_token'];
    const reservedRoots = {
      'payment-success',
      'payment-cancel',
      'verify-email',
      'reset-password',
      'google',
      'oauth-login',
      'login',
      'register',
      'start',
      'splash',
    };

    if (segments.isEmpty) {
      return const ParsedResourceLink._(kind: ResourceLinkKind.unknown);
    }

    final first = segments.first.replaceFirst('@', '');
    if (reservedRoots.contains(first)) {
      return const ParsedResourceLink._(kind: ResourceLinkKind.unknown);
    }
    if (first == 'playlists' && segments.length >= 2) {
      return ParsedResourceLink._(
        kind: ResourceLinkKind.playlistById,
        playlistId: segments[1],
        secretToken: secretToken,
      );
    }

    if (first == 'tracks' && segments.length >= 2) {
      return ParsedResourceLink._(
        kind: ResourceLinkKind.track,
        trackPermalink: segments[1],
      );
    }

    if (segments.length >= 3 && segments[1] == 'sets') {
      return ParsedResourceLink._(
        kind: ResourceLinkKind.playlistByPermalink,
        userPermalink: first,
        playlistPermalink: segments[2],
        secretToken: secretToken,
      );
    }

    if (segments.length >= 2) {
      return ParsedResourceLink._(
        kind: ResourceLinkKind.track,
        userPermalink: first,
        trackPermalink: segments[1],
      );
    }

    return ParsedResourceLink._(
      kind: ResourceLinkKind.user,
      userPermalink: first,
    );
  }
}

enum ResolvedResourceKind { user, track, playlist, ignored, notFound }

class ResourceResolution {
  const ResourceResolution._({
    required this.kind,
    this.userPermalink,
    this.trackId,
    this.title,
    this.artworkUrl,
    this.durationSeconds,
    this.trackPermalink,
    this.artistId,
    this.artistName,
    this.artistPermalink,
    this.playlistId,
    this.secretToken,
    this.message,
  });

  const ResourceResolution.user({required String permalink})
      : this._(
          kind: ResolvedResourceKind.user,
          userPermalink: permalink,
        );

  const ResourceResolution.track({
    required String trackId,
    required String title,
    required String? artworkUrl,
    required int? durationSeconds,
    required String trackPermalink,
    required String artistId,
    required String artistName,
    required String? artistPermalink,
  }) : this._(
          kind: ResolvedResourceKind.track,
          trackId: trackId,
          title: title,
          artworkUrl: artworkUrl,
          durationSeconds: durationSeconds,
          trackPermalink: trackPermalink,
          artistId: artistId,
          artistName: artistName,
          artistPermalink: artistPermalink,
        );

  const ResourceResolution.playlist({
    required String playlistId,
    required String? secretToken,
  }) : this._(
          kind: ResolvedResourceKind.playlist,
          playlistId: playlistId,
          secretToken: secretToken,
        );

  const ResourceResolution.ignored()
      : this._(kind: ResolvedResourceKind.ignored);

  const ResourceResolution.notFound({required String message})
      : this._(
          kind: ResolvedResourceKind.notFound,
          message: message,
        );

  final ResolvedResourceKind kind;
  final String? userPermalink;
  final String? trackId;
  final String? title;
  final String? artworkUrl;
  final int? durationSeconds;
  final String? trackPermalink;
  final String? artistId;
  final String? artistName;
  final String? artistPermalink;
  final String? playlistId;
  final String? secretToken;
  final String? message;
}
