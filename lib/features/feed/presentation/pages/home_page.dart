import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/engagement/presentation/widgets/like_button.dart';
import 'package:soundcloud_clone/features/engagement/presentation/widgets/track_options_sheet.dart';
import 'package:soundcloud_clone/features/followers/presentation/widgets/suggested_row.dart';
import 'package:soundcloud_clone/features/notifications/presentation/providers/notification_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';
import 'package:soundcloud_clone/features/playlist/domain/entities/playlist.dart';
import 'package:soundcloud_clone/features/library/presentation/providers/upload_provider.dart';

class _FeedTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
  final String? artworkUrl;
  final String hlsUrl;
  final int playCount;
  final int? durationSeconds;
  final int likeCount;
  final int repostCount;
  final bool isLiked;
  final bool isReposted;
  final List<int>? waveform;
  final String? trackPermalink;
  final String? likedByName;
  final String? likedByAvatarUrl;

  const _FeedTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artworkUrl,
    required this.hlsUrl,
    required this.playCount,
    this.durationSeconds,
    this.artistId,
    this.artistPermalink,
    this.likeCount = 0,
    this.repostCount = 0,
    this.isLiked = false,
    this.isReposted = false,
    this.waveform,
    this.trackPermalink,
    this.likedByName,
    this.likedByAvatarUrl,
  });

  factory _FeedTrack.fromJson(Map<String, dynamic> json) {
    final target = _asMap(json['target']);
    final targetTrack = _asMap(target?['track']);
    final nestedTrack = _asMap(json['track']);
    final track = targetTrack ?? target ?? nestedTrack ?? json;
    final artist = _asMap(track['artist']) ??
        _asMap(track['user']) ??
        _asMap(json['artist']) ??
        _asMap(json['user']) ??
        const <String, dynamic>{};
    final audio = _asMap(track['audio']);
    final media = _asMap(track['media']);
    final isActivity = target != null || json.containsKey('activityType');
    final actor = isActivity ? _activityActor(json) : null;
    final trackId = track['_id']?.toString() ?? track['id']?.toString() ?? '';
    final fallbackHlsUrl = trackId.isEmpty
        ? ''
        : 'https://biobeatsstorage2026.blob.core.windows.net/biobeats-audio/hls/$trackId/playlist.m3u8';
    final artworkUrl = (track['artworkUrl'] ??
            track['artwork_url'] ??
            json['artworkUrl'] ??
            json['artwork_url'])
        ?.toString();
    final artistName = (artist['displayName'] ??
            artist['username'] ??
            artist['name'] ??
            track['artistName'] ??
            track['ownerName'] ??
            json['artistName'])
        ?.toString();
    return _FeedTrack(
      id: trackId,
      title: track['title']?.toString() ?? '',
      artistName: artistName ?? '',
      artistId: artist['_id']?.toString() ?? artist['id']?.toString(),
      artistPermalink: artist['permalink']?.toString(),
      artworkUrl: artworkUrl,
      hlsUrl: _extractHlsUrl(track, audio, media) ?? fallbackHlsUrl,
      playCount: (track['playCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (track['duration'] as num?)?.toInt(),
      likeCount: (track['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (track['repostCount'] as num?)?.toInt() ?? 0,
      isLiked: track['isLiked'] as bool? ?? false,
      isReposted: track['isReposted'] as bool? ?? false,
      waveform: (track['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      trackPermalink: track['permalink']?.toString(),
      likedByName: actor?['displayName'] as String? ??
          actor?['username'] as String? ??
          actor?['name'] as String?,
      likedByAvatarUrl: actor?['avatarUrl'] as String? ??
          actor?['profileImageUrl'] as String? ??
          actor?['photoUrl'] as String?,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _extractHlsUrl(
    Map<String, dynamic> track,
    Map<String, dynamic>? audio,
    Map<String, dynamic>? media,
  ) {
    final direct = (track['hlsUrl'] ??
            audio?['hlsUrl'] ??
            media?['hlsUrl'] ??
            track['audioUrl'] ??
            track['streamUrl'])
        ?.toString();
    if (direct != null && direct.isNotEmpty) return direct;

    final transcodings = media?['transcodings'];
    if (transcodings is List) {
      for (final item in transcodings) {
        final transcoding = _asMap(item);
        if (transcoding == null) continue;
        final format = _asMap(transcoding['format']);
        final protocol = format?['protocol']?.toString();
        final preset = format?['preset']?.toString();
        final url = transcoding['url']?.toString();
        if (url == null || url.isEmpty) continue;
        if (protocol == 'hls' ||
            (preset?.toLowerCase().contains('hls') ?? false)) {
          return url;
        }
      }

      for (final item in transcodings) {
        final transcoding = _asMap(item);
        final url = transcoding?['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _activityActor(Map<String, dynamic> json) {
    final actors = json['actors'];
    if (actors is List && actors.isNotEmpty) {
      final first = actors.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }

    final actor =
        json['actor'] ?? json['user'] ?? json['createdBy'] ?? json['profile'];
    if (actor is Map<String, dynamic>) return actor;
    if (actor is Map) return Map<String, dynamic>.from(actor);
    return null;
  }

  _FeedTrack copyWith({
    bool? isLiked,
    bool? isReposted,
    int? likeCount,
    int? repostCount,
    String? likedByName,
    String? likedByAvatarUrl,
  }) {
    return _FeedTrack(
      id: id,
      title: title,
      artistName: artistName,
      artworkUrl: artworkUrl,
      hlsUrl: hlsUrl,
      playCount: playCount,
      durationSeconds: durationSeconds,
      artistId: artistId,
      artistPermalink: artistPermalink,
      likeCount: likeCount ?? this.likeCount,
      repostCount: repostCount ?? this.repostCount,
      isLiked: isLiked ?? this.isLiked,
      isReposted: isReposted ?? this.isReposted,
      waveform: waveform,
      trackPermalink: trackPermalink,
      likedByName: likedByName ?? this.likedByName,
      likedByAvatarUrl: likedByAvatarUrl ?? this.likedByAvatarUrl,
    );
  }
}

class _GenreTheme {
  final String label;
  final String query;
  final List<String> trendingQueries;
  final Color accent;
  final Color glow;
  final List<Color> surface;

  const _GenreTheme({
    required this.label,
    required this.query,
    this.trendingQueries = const [],
    required this.accent,
    required this.glow,
    required this.surface,
  });

  List<String> get effectiveTrendingQueries =>
      trendingQueries.isEmpty ? <String>[query] : trendingQueries;
}

class _HomePlaylistSummary {
  final String id;
  final String title;
  final String ownerName;
  final String? artworkUrl;
  final int trackCount;

  const _HomePlaylistSummary({
    required this.id,
    required this.title,
    required this.ownerName,
    this.artworkUrl,
    this.trackCount = 0,
  });

  factory _HomePlaylistSummary.fromJson(Map<String, dynamic> json) {
    final creator = _FeedTrack._asMap(json['creator'] ?? json['user']);
    return _HomePlaylistSummary(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      ownerName: (json['ownerName'] ??
              creator?['displayName'] ??
              creator?['username'] ??
              '')
          .toString(),
      artworkUrl: (json['artworkUrl'] ?? json['artwork_url'])?.toString(),
      trackCount: (json['trackCount'] as num?)?.toInt() ??
          (json['tracks'] is List ? (json['tracks'] as List).length : 0),
    );
  }

  Playlist toPlaylist({String? fallbackArtworkUrl}) => Playlist(
        id: id,
        title: title,
        artworkUrl: artworkUrl ?? fallbackArtworkUrl,
        ownerName: ownerName,
        trackCount: trackCount,
      );
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const List<_GenreTheme> _genres = [
    _GenreTheme(
      label: 'HIP-HOP & RAP',
      query: 'Hiphop & rap',
      accent: Color(0xFF9B5CFF),
      glow: Color(0x339B5CFF),
      surface: [Color(0xFF24173B), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'ELECTRONIC',
      query: 'Electronic',
      accent: Color(0xFFFF4AA2),
      glow: Color(0x33FF4AA2),
      surface: [Color(0xFF2B1B27), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'POP',
      query: 'Pop',
      accent: Color(0xFFEED17A),
      glow: Color(0x33EED17A),
      surface: [Color(0xFF2A2418), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'TECHNO',
      query: 'Techno',
      accent: Color(0xFFFF5AA7),
      glow: Color(0x33FF5AA7),
      surface: [Color(0xFF2E1B25), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'R&B',
      query: 'R&B',
      trendingQueries: [
        'R&B',
        'R&B & Soul',
        'R&B & soul',
        'RnB',
        'Rnb',
        'R & B',
        'R and B',
      ],
      accent: Color(0xFF22C7B8),
      glow: Color(0x3322C7B8),
      surface: [Color(0xFF163032), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'HOUSE',
      query: 'House',
      accent: Color(0xFFFF5AA7),
      glow: Color(0x33FF5AA7),
      surface: [Color(0xFF321A28), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'INDIE',
      query: 'Indie',
      accent: Color(0xFF6A89FF),
      glow: Color(0x333C5BFF),
      surface: [Color(0xFF182033), Color(0xFF13161F)],
    ),
  ];

  int _selectedGenreIndex = 2;
  List<_FeedTrack> _tracks = [];
  List<_FeedTrack> _likedTracks = [];
  List<_FeedTrack> _trendingTracks = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isTrendingLoading = false;
  String _displayName = 'you';

  List<_FeedTrack> _recommendedTracks = [];
  List<_FeedTrack> _mixedShelfTracks = [];
  List<_FeedTrack> _stationCards = [];
  List<_FeedTrack> _madeForYouCards = [];
  List<_FeedTrack> _curatedTracks = [];
  List<_FeedTrack> _likedByFollowingTracks = [];
  Map<String, List<_FeedTrack>> _buzzingGenreTracks = {};
  Map<String, _HomePlaylistSummary> _buzzingGenrePlaylists = {};

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchFeed();
    _fetchTrending();
    _fetchRecommended();
    _fetchMixedForYou();
    _fetchCurated();
    _fetchBuzzingGenres();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('displayName') ??
        prefs.getString('username') ??
        prefs.getString('name') ??
        'you';
    if (mounted) {
      setState(() => _displayName = name);
    }
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final response = await dioClient.dio.get('/feed');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final rawFeed = data['feed'] as List<dynamic>? ?? [];
      var tracks = rawFeed
          .map((e) => _FeedTrack.fromJson(e as Map<String, dynamic>))
          .where((track) => track.id.isNotEmpty)
          .toList();

      final feedLikedTracks = rawFeed
          .where((item) {
            final m = item as Map<String, dynamic>;
            return (m['activityType'] as String?) == 'LIKE' &&
                (m['targetModel'] as String?) == 'Track';
          })
          .map((e) => _FeedTrack.fromJson(e as Map<String, dynamic>))
          .where((t) => t.id.isNotEmpty)
          .toList();

      final likedIds = <String>{};
      final repostedIds = <String>{};
      final likedTracks = <_FeedTrack>[];

      if (userId.isNotEmpty) {
        try {
          final likesResponse =
              await dioClient.dio.get('/profile/$userId/likes');
          final likesData =
              likesResponse.data['data'] as Map<String, dynamic>? ?? {};
          final likedItems = likesData['likedTracks'] as List<dynamic>? ?? [];
          for (final item in likedItems) {
            final itemMap = item as Map<String, dynamic>;
            final trackMap = (itemMap['target'] ?? itemMap['track'])
                as Map<String, dynamic>?;
            if (trackMap == null) continue;
            final id = trackMap['_id'] as String? ?? '';
            if (id.isEmpty) continue;
            likedIds.add(id);
            likedTracks.add(_FeedTrack.fromJson(trackMap));
          }
        } catch (_) {}

        try {
          final repostsResponse =
              await dioClient.dio.get('/profile/$userId/reposts');
          final repostData =
              repostsResponse.data['data'] as Map<String, dynamic>? ?? {};
          final repostItems =
              repostData['repostedTracks'] as List<dynamic>? ?? [];
          for (final item in repostItems) {
            final trackMap = (item as Map<String, dynamic>)['track']
                as Map<String, dynamic>?;
            final id = trackMap?['_id'] as String? ?? '';
            if (id.isNotEmpty) {
              repostedIds.add(id);
            }
          }
        } catch (_) {}
      }

      tracks = tracks
          .map(
            (track) => track.copyWith(
              isLiked: likedIds.contains(track.id),
              isReposted: repostedIds.contains(track.id),
              likeCount: likedIds.contains(track.id)
                  ? max(track.likeCount, 1)
                  : track.likeCount,
              repostCount: repostedIds.contains(track.id)
                  ? max(track.repostCount, 1)
                  : track.repostCount,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          _tracks = tracks;
          _likedTracks = likedTracks;
          _likedByFollowingTracks = feedLikedTracks;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Home feed error: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _fetchTrending() async {
    final selectedIndex = _selectedGenreIndex;
    final genre = _genres[selectedIndex];

    setState(() {
      _isTrendingLoading = true;
    });

    try {
      final tracks = await _fetchTrendingForGenre(genre);

      if (mounted) {
        if (_selectedGenreIndex != selectedIndex) return;
        setState(() {
          _trendingTracks = tracks;
          _isTrendingLoading = false;
        });
      }
    } on DioException catch (error) {
      debugPrint(
          'Trending error: ${error.response?.statusCode} ${error.message}');
      if (mounted) {
        setState(() => _isTrendingLoading = false);
      }
    } catch (error) {
      debugPrint('Trending error: $error');
      if (mounted) {
        setState(() => _isTrendingLoading = false);
      }
    }
  }

  Future<List<_FeedTrack>> _fetchTrendingForGenre(
    _GenreTheme genre, {
    int? limit,
  }) async {
    for (final query in genre.effectiveTrendingQueries) {
      try {
        final response = await dioClient.dio.get(
          '/discovery/trending',
          queryParameters: {
            'genre': query,
            if (limit != null) 'limit': limit,
          },
        );
        final tracks = _extractTrendingTracks(response.data);
        if (tracks.isNotEmpty) return tracks;
      } catch (error) {
        debugPrint('Trending ${genre.label} query "$query" error: $error');
      }
    }
    return const <_FeedTrack>[];
  }

  List<_FeedTrack> _extractTrendingTracks(dynamic body) {
    final data = body is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>?
        : null;
    final rawTrending = data?['trending'] as List<dynamic>? ?? [];
    return rawTrending
        .whereType<Map<String, dynamic>>()
        .map(_FeedTrack.fromJson)
        .where((track) => track.id.isNotEmpty)
        .toList();
  }

  Future<void> _fetchRecommended() async {
    try {
      final response = await dioClient.dio.get('/discovery/recommended');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final rawTracks = data['tracks'] as List<dynamic>? ?? [];
      final tracks = rawTracks
          .map((e) => _FeedTrack.fromJson(e as Map<String, dynamic>))
          .where((t) => t.id.isNotEmpty)
          .toList();
      if (mounted) setState(() => _recommendedTracks = tracks);
    } catch (e) {
      debugPrint('Recommended error: $e');
    }
  }

  Future<void> _fetchMixedForYou() async {
    try {
      final response = await dioClient.dio.get('/discovery/mixed-for-you');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final rawStations = data['stations'] as List<dynamic>? ?? [];

      final mixedShelf = <_FeedTrack>[];
      final stationCards = <_FeedTrack>[];
      final madeForYou = <_FeedTrack>[];

      for (final station in rawStations) {
        final stationMap = station as Map<String, dynamic>;
        final stationId =
            stationMap['id'] as String? ?? stationMap['_id'] as String? ?? '';
        final stationTitle = stationMap['title'] as String? ?? '';
        final stationType = stationMap['type'] as String? ?? '';
        final rawTracks = stationMap['tracks'] as List<dynamic>? ?? [];

        if (rawTracks.isEmpty) continue;

        final firstTrack =
            _FeedTrack.fromJson(rawTracks[0] as Map<String, dynamic>);
        if (firstTrack.id.isEmpty) continue;

        mixedShelf.add(firstTrack);

        // Find the first non-empty artworkUrl across all tracks in this station.
        String? stationArtworkUrl = firstTrack.artworkUrl;
        if (stationArtworkUrl == null || stationArtworkUrl.isEmpty) {
          for (final rawT in rawTracks.skip(1)) {
            final url = (rawT as Map<String, dynamic>)['artworkUrl'] as String?;
            if (url != null && url.isNotEmpty) {
              stationArtworkUrl = url;
              break;
            }
          }
        }

        final displayTitle =
            stationTitle.isNotEmpty ? stationTitle : firstTrack.artistName;
        final stationTrack = _FeedTrack(
          id: stationId.isNotEmpty ? stationId : firstTrack.id,
          title: displayTitle,
          artistName: displayTitle,
          artworkUrl: stationArtworkUrl,
          hlsUrl: firstTrack.hlsUrl,
          playCount: firstTrack.playCount,
          durationSeconds: firstTrack.durationSeconds,
          artistId: firstTrack.artistId,
          artistPermalink: firstTrack.artistPermalink,
          waveform: firstTrack.waveform,
          trackPermalink: firstTrack.trackPermalink,
        );

        stationCards.add(stationTrack);

        if (stationType == 'genre' && madeForYou.length < 2) {
          madeForYou.add(stationTrack);
        }
      }

      if (mounted) {
        setState(() {
          _mixedShelfTracks = mixedShelf;
          _stationCards = stationCards;
          _madeForYouCards = madeForYou;
        });
      }
    } catch (e) {
      debugPrint('Mixed-for-you error: $e');
    }
  }

  Future<void> _fetchCurated() async {
    try {
      final response = await dioClient.dio.get('/discovery/curated');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final rawCurated = data['curated'] as List<dynamic>? ?? [];
      final tracks = <_FeedTrack>[];
      for (final bucket in rawCurated) {
        final bucketMap = bucket as Map<String, dynamic>;
        final bucketTracks = bucketMap['tracks'] as List<dynamic>? ?? [];
        for (final t in bucketTracks) {
          final track = _FeedTrack.fromJson(t as Map<String, dynamic>);
          if (track.id.isNotEmpty) tracks.add(track);
        }
      }
      if (mounted) setState(() => _curatedTracks = tracks);
    } catch (e) {
      debugPrint('Curated error: $e');
    }
  }

  Future<void> _fetchBuzzingGenres() async {
    final entries = await Future.wait(
      _genres.map((genre) async {
        try {
          final results = await Future.wait([
            _fetchTrendingForGenre(genre, limit: 5),
            _fetchPlaylistForGenre(genre),
          ]);
          return (
            query: genre.query,
            tracks: results[0] as List<_FeedTrack>,
            playlist: results[1] as _HomePlaylistSummary?,
          );
        } catch (e) {
          debugPrint('Buzzing ${genre.query} error: $e');
          return (
            query: genre.query,
            tracks: <_FeedTrack>[],
            playlist: null,
          );
        }
      }),
    );

    if (mounted) {
      setState(() {
        _buzzingGenreTracks = {
          for (final entry in entries) entry.query: entry.tracks,
        };
        _buzzingGenrePlaylists = {
          for (final entry in entries)
            if (entry.playlist != null) entry.query: entry.playlist!,
        };
      });
    }
  }

  Future<_HomePlaylistSummary?> _fetchPlaylistForGenre(
    _GenreTheme genre,
  ) async {
    for (final query in genre.effectiveTrendingQueries) {
      try {
        final response = await dioClient.dio.get(
          '/playlists',
          queryParameters: {
            'genre': query,
            'releaseType': 'playlist',
          },
        );
        final data = response.data['data'] as Map<String, dynamic>? ?? {};
        final raw = data['playlists'] as List<dynamic>? ?? [];
        for (final item in raw.whereType<Map<String, dynamic>>()) {
          final playlist = _HomePlaylistSummary.fromJson(item);
          if (playlist.id.isNotEmpty) return playlist;
        }
      } catch (e) {
        debugPrint('Buzzing playlist ${genre.label} query "$query" error: $e');
      }
    }
    return null;
  }

  void _playTrackCollection(
    WidgetRef ref, {
    required _FeedTrack track,
    required List<_FeedTrack> source,
  }) {
    if (track.hlsUrl.isEmpty) return;

    final queue = source
        .where((item) => item.hlsUrl.isNotEmpty)
        .map(
          (item) => PlayerTrack(
            id: item.id,
            title: item.title,
            artist: item.artistName,
            artistId: item.artistId,
            artistPermalink: item.artistPermalink,
            audioUrl: item.hlsUrl,
            coverUrl: item.artworkUrl,
            duration: item.durationSeconds != null
                ? Duration(seconds: item.durationSeconds!)
                : null,
            waveform: item.waveform,
            trackPermalink: item.trackPermalink,
          ),
        )
        .toList();
    if (queue.isEmpty) return;

    final playable = source.where((item) => item.hlsUrl.isNotEmpty).toList();
    final startIndex = playable.indexWhere((item) => item.id == track.id);
    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: startIndex < 0 ? 0 : startIndex,
        );
  }

  Future<void> _pickUploadFromHome() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null || filePath.isEmpty) return;

      await ref
          .read(uploadProvider.notifier)
          .initializeUpload(audioFilePath: filePath);

      if (mounted) context.push('/upload');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionHeader(
    String title, {
    bool showSeeAll = false,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'See All',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTrackOptions(_FeedTrack track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TrackOptionsSheet(
        trackId: track.id,
        title: track.title,
        artistName: track.artistName,
        artworkUrl: track.artworkUrl,
        audioUrl: track.hlsUrl,
        waveform: track.waveform,
        artistId: track.artistId,
        artistPermalink: track.artistPermalink,
        trackPermalink: track.trackPermalink,
        initialIsLiked: track.isLiked,
        initialIsReposted: track.isReposted,
        initialLikeCount: track.likeCount,
        initialRepostCount: track.repostCount,
      ),
    );
  }

  Widget _buildLikesBanner() {
    final mergedLikesAsync = ref.watch(mergedUserLikesProvider);
    final likedOrder = ref.watch(likedTrackOrderProvider);
    final likedTracksById = {
      for (final track in _likedTracks) track.id: track,
    };
    final visibleLikedTracks = mergedLikesAsync.maybeWhen(
      data: (tracks) => tracks.map(
        (track) {
          final rawTrack = likedTracksById[track.id];
          return _FeedTrack(
            id: track.id,
            title: track.title,
            artistName: track.artistName,
            artworkUrl: track.artworkUrl,
            hlsUrl: rawTrack?.hlsUrl ?? _hlsUrlFromTrackSummary(track),
            playCount: track.playCount,
            artistId: track.artistId,
            artistPermalink: track.artistPermalink,
            likeCount: track.likeCount,
            repostCount: track.repostCount,
            isLiked: true,
            waveform: track.waveform,
          );
        },
      ).toList(),
      orElse: () => _likedTracks,
    );
    final orderedLikedTracks = _applyLikedOrder(visibleLikedTracks, likedOrder);
    return GestureDetector(
      onTap: () => context.push('/library/likes'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF5A281B), Color(0xFF2A1E1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const _LikesGlyph(),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Your likes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (orderedLikedTracks.isEmpty) return;
                    final shuffled = List<_FeedTrack>.from(orderedLikedTracks)
                      ..shuffle(Random());
                    ref.read(likedTrackOrderProvider.notifier).state =
                        shuffled.map((track) => track.id).toList();
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shuffle_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (orderedLikedTracks.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tracks you like will show up here.',
                  style: TextStyle(color: Color(0xFFD0D0D0), fontSize: 12),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          
                          child: _SmallTrackTile(track: orderedLikedTracks[0])),
                      if (orderedLikedTracks.length > 1) ...[
                        const SizedBox(width: 10),
                        Expanded(
                            child:
                                _SmallTrackTile(track: orderedLikedTracks[1])),
                      ],
                    ],
                  ),
                  if (orderedLikedTracks.length > 2) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child:
                                _SmallTrackTile(track: orderedLikedTracks[2])),
                        if (orderedLikedTracks.length > 3) ...[
                          const SizedBox(width: 10),
                          Expanded(
                              child: _SmallTrackTile(
                                  track: orderedLikedTracks[3])),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<_FeedTrack> _applyLikedOrder(
    List<_FeedTrack> tracks,
    List<String> likedOrder,
  ) {
    if (likedOrder.isEmpty) return tracks;
    final order = {
      for (var i = 0; i < likedOrder.length; i++) likedOrder[i]: i,
    };
    final sorted = List<_FeedTrack>.from(tracks);
    sorted.sort((a, b) {
      final ai = order[a.id];
      final bi = order[b.id];
      if (ai == null && bi == null) return 0;
      if (ai == null) return 1;
      if (bi == null) return -1;
      return ai.compareTo(bi);
    });
    return sorted;
  }

  String _hlsUrlFromTrackSummary(TrackSummary track) {
    final url = track.audioUrl;
    if (url == null || url.isEmpty) return '';
    final lower = url.toLowerCase();
    final isHls = lower.contains('.m3u8') || lower.contains('/hls/');
    final guessedFallback =
        'https://biobeatsstorage2026.blob.core.windows.net/biobeats-audio/hls/${track.id}/playlist.m3u8';
    return isHls && url != guessedFallback ? url : '';
  }

  Widget _buildSquareShelf(
    List<_FeedTrack> tracks, {
    bool showMixRibbon = false,
    bool compact = false,
    Key? listKey,
  }) {
    return SizedBox(
      height: compact ? 216 : 232,
      child: ListView.separated(
        key: listKey,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, index) => _ArtworkShelfCard(
          track: tracks[index],
          width: compact ? 136 : 138,
          ribbonLabel: showMixRibbon ? 'MIX ${index + 1}' : null,
          onTap: () => _playTrackCollection(
            ref,
            track: tracks[index],
            source: tracks,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    final theme = _genres[_selectedGenreIndex];
    final tracks = _trendingTracks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Trending by genre'),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _genres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final genre = _genres[index];
              final selected = index == _selectedGenreIndex;
              return GestureDetector(
                key: ValueKey('home_genre_chip_${genre.label.toLowerCase()}'),
                onTap: () {
                  setState(() => _selectedGenreIndex = index);
                  _fetchTrending();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? genre.accent : Colors.white70,
                    ),
                  ),
                  child: Text(
                    genre.label,
                    style: TextStyle(
                      color: selected ? genre.accent : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isTrendingLoading && tracks.isEmpty
              ? const Padding(
                  key: ValueKey('trending_loading'),
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                  ),
                )
              : !_isTrendingLoading && tracks.isEmpty
                  ? SizedBox(
                      key: ValueKey('${theme.label}_empty'),
                      height: 80,
                      child: const Center(
                        child: Text(
                          'No tracks for this genre',
                          style: TextStyle(
                            color: Color(0xFF808080),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      key: ValueKey(theme.label),
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: (tracks.length / 3).ceil(),
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          final window =
                              tracks.skip(index * 3).take(3).toList();
                          return _TrendingPanel(
                            theme: theme,
                            tracks: window,
                            onPlay: (track) => _playTrackCollection(
                              ref,
                              track: track,
                              source: tracks,
                            ),
                            onMore: _showTrackOptions,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTrackRowsSection(List<_FeedTrack> tracks, {Key? listKey}) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        key: listKey,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: (tracks.length / 3).ceil(),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final window = tracks.skip(index * 3).take(3).toList();
          return _LikedByPanel(
            tracks: window,
            onPlay: (track) =>
                _playTrackCollection(ref, track: track, source: tracks),
            onMore: _showTrackOptions,
          );
        },
      ),
    );
  }

  Widget _buildMadeForYou(List<_FeedTrack> tracks) {
    final colors = [
      (
        bg: const [Color(0xFF193D8F), Color(0xFF1F1F1F)],
        label: 'DAILY DROPS',
        description: 'New releases based on your taste. Updated every day',
      ),
      (
        bg: const [Color(0xFF7E3500), Color(0xFF1F1F1F)],
        label: 'WEEKLY WAVE',
        description:
            'The best of SoundCloud just for you. Updated every Monday',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < min(2, tracks.length); i++) ...[
            Expanded(
              child: _MadeForYouCard(
                track: tracks[i],
                colors: colors[i].bg,
                label: colors[i].label,
                description: colors[i].description,
                onTap: () => _playTrackCollection(
                  ref,
                  track: tracks[i],
                  source: tracks,
                ),
              ),
            ),
            if (i == 0) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildBuzzingShelf({Key? listKey}) {
    return SizedBox(
      height: 184,
      child: ListView.separated(
        key: listKey,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final genre = _genres[index];
          final tracks =
              _buzzingGenreTracks[genre.query] ?? const <_FeedTrack>[];
          final playlist = _buzzingGenrePlaylists[genre.query];
          return _BuzzingCard(
            genre: genre,
            track: tracks.isNotEmpty ? tracks.first : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: '/home/genre-station'),
                builder: (_) => _GenreStationPage(
                  genre: genre,
                  tracks: tracks,
                  playlist: playlist,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(likesRefreshTickProvider, (previous, next) {
      if (previous != next) {
        _fetchFeed();
      }
    });

    final recommendationTracks = _recommendedTracks;
    final mixedTracks = _mixedShelfTracks;
    final followLikedTracks = _likedByFollowingTracks;
    final curatedTracks = _curatedTracks;
    final likedByTracks = followLikedTracks;
    final stationTracks =
        _stationCards.isNotEmpty ? _stationCards : _mixedShelfTracks;
    final madeForYouTracks =
        _madeForYouCards.isNotEmpty ? _madeForYouCards : recommendationTracks;

    return Scaffold(
      key: const ValueKey('home_scaffold'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        toolbarHeight: 58,
        actions: [
          TextButton(
            key: const ValueKey('home_get_pro_button'),
            onPressed: () => context.push('/upgrade'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'GET PRO',
              style: TextStyle(
                color: Color(0xFFFF6B1A),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('home_upload_button'),
            onPressed: _pickUploadFromHome,
            icon: const Icon(Icons.arrow_circle_up_outlined, size: 23),
          ),
          IconButton(
            key: const ValueKey('home_messages_button'),
            onPressed: () => context.push('/messages'),
            icon: const Icon(Icons.mail_outline, size: 23),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                key: const ValueKey('home_notifications_button'),
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_none, size: 23),
              ),
              Builder(
                builder: (context) {
                  final unread = ref.watch(notificationProvider).unreadCount;
                  if (unread == 0) return const SizedBox.shrink();
                  return Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5500),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchFeed(),
            _fetchTrending(),
            _fetchRecommended(),
            _fetchMixedForYou(),
            _fetchCurated(),
            _fetchBuzzingGenres(),
          ]);
        },
        color: const Color(0xFFFF5500),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          key: const ValueKey('home_content_list'),
          padding: const EdgeInsets.only(top: 12, bottom: 140),
          children: [
            _buildLikesBanner(),
            _buildSectionHeader(
              'More of what you like',
              showSeeAll: true,
              onSeeAll: () => context.push('/home/recommended'),
            ),
            _buildSquareShelf(recommendationTracks,
                listKey: const ValueKey('home_recommended_list')),
            const SizedBox(height: 28),
            _buildTrendingSection(),
            const SizedBox(height: 28),
            _buildSectionHeader('Mixed for $_displayName'),
            _buildSquareShelf(mixedTracks,
                showMixRibbon: true,
                compact: true,
                listKey: const ValueKey('home_mixed_list')),
            const SizedBox(height: 28),
            _buildSectionHeader('Liked by people you follow'),
            _buildTrackRowsSection(followLikedTracks,
                listKey: const ValueKey('home_liked_by_following_list')),
            const SizedBox(height: 28),
            _buildSectionHeader('Made for you'),
            _buildMadeForYou(madeForYouTracks),
            const SizedBox(height: 28),
            _buildSectionHeader('Curated by SoundCloud'),
            _buildSquareShelf(curatedTracks,
                compact: true, listKey: const ValueKey('home_curated_list')),
            const SizedBox(height: 28),
            _buildSectionHeader('Liked By'),
            _buildSquareShelf(likedByTracks,
                compact: true, listKey: const ValueKey('home_liked_by_list')),
            const SizedBox(height: 28),
            _buildSectionHeader('Discover with Stations'),
            _buildStationShelf(stationTracks,
                listKey: const ValueKey('home_station_list')),
            const SizedBox(height: 28),
            _buildSectionHeader('New crew, suggested for you'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SuggestedRow(title: null, compact: true),
            ),
            const SizedBox(height: 28),
            _buildSectionHeader('Artists to watch out for'),
            _buildBuzzingShelf(listKey: const ValueKey('home_buzzing_list')),
            if (_isLoading && _tracks.isEmpty)
              const Padding(
                key: ValueKey('home_loading'),
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
              )
            else if (_hasError)
              const Padding(
                key: ValueKey('home_error'),
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Some home content could not be loaded.',
                  style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationShelf(List<_FeedTrack> tracks, {Key? listKey}) {
    return SizedBox(
      height: 192,
      child: ListView.separated(
        key: listKey,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) => _StationCard(
          track: tracks[index],
          onTap: () => _playTrackCollection(
            ref,
            track: tracks[index],
            source: tracks,
          ),
        ),
      ),
    );
  }
}

class _SmallTrackTile extends StatelessWidget {
  final _FeedTrack track;

  const _SmallTrackTile({required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF363636),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 42,
              height: 42,
              child: _NetworkArtwork(url: track.artworkUrl),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD3D3D3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkShelfCard extends StatelessWidget {
  final _FeedTrack track;
  final double width;
  final String? ribbonLabel;
  final VoidCallback onTap;

  const _ArtworkShelfCard({
    required this.track,
    required this.width,
    required this.onTap,
    this.ribbonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: width,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: _NetworkArtwork(url: track.artworkUrl),
                    ),
                  ),
                  if (ribbonLabel != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C9EFA),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ribbonLabel!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  if (track.likedByName != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Column(
                          children: [
                            const Text(
                              'LIKED BY',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFCFCFCF),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              track.likedByName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (track.waveform != null && track.waveform!.isNotEmpty)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: ribbonLabel == null ? 8 : 34,
                      child: _MiniWaveformStrip(samples: track.waveform!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 30,
              child: Text(
                track.artistName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFBEBEBE),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingListRow extends StatelessWidget {
  final _FeedTrack track;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _TrendingListRow({
    required this.track,
    required this.accent,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('trending_track_tile'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 42,
                height: 42,
                child: _NetworkArtwork(url: track.artworkUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD6D6D6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onMore,
              child: Icon(
                Icons.more_vert,
                color: accent.withValues(alpha: 0.9),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingPanel extends StatelessWidget {
  final _GenreTheme theme;
  final List<_FeedTrack> tracks;
  final void Function(_FeedTrack track) onPlay;
  final void Function(_FeedTrack track) onMore;

  const _TrendingPanel({
    required this.theme,
    required this.tracks,
    required this.onPlay,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        min(MediaQuery.of(context).size.width - 32, 360).toDouble();
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: theme.surface,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: RadialGradient(
                  center: const Alignment(0.1, -0.05),
                  radius: 0.95,
                  colors: [
                    theme.glow,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final track in tracks)
                      _TrendingListRow(
                        track: track,
                        accent: theme.accent,
                        onTap: () => onPlay(track),
                        onMore: () => onMore(track),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LikedByPanel extends StatelessWidget {
  final List<_FeedTrack> tracks;
  final void Function(_FeedTrack track) onPlay;
  final void Function(_FeedTrack track) onMore;

  const _LikedByPanel({
    required this.tracks,
    required this.onPlay,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        min(MediaQuery.of(context).size.width - 32, 360).toDouble();
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF181C29), Color(0xFF0F121A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const RadialGradient(
                  center: Alignment(0.0, -0.2),
                  radius: 0.92,
                  colors: [
                    Color(0x332F4FFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final track in tracks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => onPlay(track),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: _NetworkArtwork(url: track.artworkUrl),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (track.likedByName != null) ...[
                                          const Text(
                                            'Liked by ',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color(0xFF9DA8FF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        Flexible(
                                          child: Text(
                                            track.likedByName ??
                                                track.artistName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFFD0D0D0),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _TinyAvatar(
                                            url: track.likedByAvatarUrl),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => onMore(track),
                                child: const Icon(
                                  Icons.more_vert,
                                  color: Color(0xFF9DA8FF),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyAvatar extends StatelessWidget {
  final String? url;

  const _TinyAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty && url!.startsWith('http');
    return CircleAvatar(
      radius: 8,
      backgroundColor: const Color(0xFF515151),
      backgroundImage: hasUrl ? CachedNetworkImageProvider(url!) : null,
      child: hasUrl
          ? null
          : const Icon(
              Icons.person,
              size: 10,
              color: Colors.white70,
            ),
    );
  }
}

class _MadeForYouCard extends StatelessWidget {
  final _FeedTrack track;
  final List<Color> colors;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _MadeForYouCard({
    required this.track,
    required this.colors,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 246,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  size: 12,
                  color: Colors.white70,
                ),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: _NetworkArtwork(url: track.artworkUrl),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: Colors.black.withValues(alpha: 0.42),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final _FeedTrack track;
  final VoidCallback onTap;

  const _StationCard({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 136,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                color: const Color(0xFF202020),
                border: Border.all(color: const Color(0xFF414141)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _StationPainter()),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STATION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 18,
                    child: ClipOval(
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _NetworkArtwork(url: track.artworkUrl),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: Text(
                'Based on ${track.artistName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD0D0D0),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuzzingCard extends StatelessWidget {
  final _GenreTheme genre;
  final _FeedTrack? track;
  final VoidCallback onTap;

  const _BuzzingCard({
    required this.genre,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 126,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BuzzingPainter(accent: genre.accent),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Text(
                      'BUZZING',
                      style: TextStyle(
                        color: genre.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 58,
                        child: _NetworkArtwork(url: track?.artworkUrl),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              genre.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreStationPage extends ConsumerWidget {
  final _GenreTheme genre;
  final List<_FeedTrack> tracks;
  final _HomePlaylistSummary? playlist;

  const _GenreStationPage({
    required this.genre,
    required this.tracks,
    this.playlist,
  });

  void _playTrack(
    WidgetRef ref, {
    required _FeedTrack track,
  }) {
    final playable = tracks.where((item) => item.hlsUrl.isNotEmpty).toList();
    if (playable.isEmpty) return;

    final queue = playable
        .map(
          (item) => PlayerTrack(
            id: item.id,
            title: item.title,
            artist: item.artistName,
            artistId: item.artistId,
            artistPermalink: item.artistPermalink,
            audioUrl: item.hlsUrl,
            coverUrl: item.artworkUrl,
            duration: item.durationSeconds != null
                ? Duration(seconds: item.durationSeconds!)
                : null,
            waveform: item.waveform,
            trackPermalink: item.trackPermalink,
          ),
        )
        .toList();
    final startIndex = playable.indexWhere((item) => item.id == track.id);
    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: startIndex < 0 ? 0 : startIndex,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroTrack = tracks.isNotEmpty ? tracks.first : null;
    final playlistEntity = playlist?.toPlaylist(
      fallbackArtworkUrl: heroTrack?.artworkUrl,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Introducing',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: genre.surface,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: genre.accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  genre.label,
                  style: TextStyle(
                    color: genre.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'BUZZING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _NetworkArtwork(url: heroTrack?.artworkUrl),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  heroTrack?.title ?? 'No tracks yet',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  heroTrack?.artistName ?? 'Check back soon',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC9C9C9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: heroTrack == null
                          ? null
                          : () => _playTrack(ref, track: heroTrack),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: genre.accent,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF333333),
                        disabledForegroundColor: const Color(0xFF777777),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (playlistEntity != null)
                      PlaylistLikeButton(playlist: playlistEntity)
                    else
                      IconButton(
                        onPressed: null,
                        icon: const Icon(Icons.favorite_border),
                        color: Colors.white38,
                        style: IconButton.styleFrom(
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          for (final track in tracks)
            _GenreStationTrackRow(
              track: track,
              accent: genre.accent,
              onTap: () => _playTrack(ref, track: track),
            ),
        ],
      ),
    );
  }
}

class _GenreStationTrackRow extends StatelessWidget {
  final _FeedTrack track;
  final Color accent;
  final VoidCallback onTap;

  const _GenreStationTrackRow({
    required this.track,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 54,
                height: 54,
                child: _NetworkArtwork(url: track.artworkUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFAFAFAF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_arrow_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

class _NetworkArtwork extends StatelessWidget {
  final String? url;

  const _NetworkArtwork({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty || !url!.startsWith('http')) {
      return const _ArtworkPlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
    );
  }
}

class _MiniWaveformStrip extends StatelessWidget {
  final List<int> samples;

  const _MiniWaveformStrip({required this.samples});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: CustomPaint(
            painter: _MiniWaveformPainter(samples),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _MiniWaveformPainter extends CustomPainter {
  final List<int> samples;

  const _MiniWaveformPainter(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    final visibleBars = min(samples.length, (size.width / 3).floor());
    if (visibleBars <= 0) return;
    final stride = max(1, (samples.length / visibleBars).floor());
    final maxSample = samples.reduce(max).clamp(1, 100).toDouble();
    final gap = size.width / visibleBars;
    for (var i = 0; i < visibleBars; i++) {
      final sample = samples[min(i * stride, samples.length - 1)];
      final normalized = (sample / maxSample).clamp(0.12, 1.0).toDouble();
      final barHeight = size.height * normalized;
      final x = (i * gap) + (gap / 2);
      canvas.drawLine(
        Offset(x, (size.height - barHeight) / 2),
        Offset(x, (size.height + barHeight) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWaveformPainter oldDelegate) =>
      oldDelegate.samples != samples;
}

class _LikesGlyph extends StatelessWidget {
  const _LikesGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        children: [
          for (int i = 3; i >= 0; i--)
            Positioned(
              left: i * 3,
              top: i * 2,
              child: Icon(
                Icons.favorite_outline,
                color: const Color(0xFFFF6A2A).withValues(
                  alpha: 0.34 + ((3 - i) * 0.16),
                ),
                size: 30,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3A3A3A),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white38, size: 28),
      ),
    );
  }
}

class _StationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6A1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (int i = 0; i < 5; i++) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width * 0.4, size.height * 0.42),
          radius: 38 + (i * 8),
        ),
        1.1,
        2.7,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BuzzingPainter extends CustomPainter {
  final Color accent;

  const _BuzzingPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accent;
    for (int i = 0; i < 8; i++) {
      final top = i * 14.0;
      canvas.drawRect(
        Rect.fromLTWH(i.isEven ? 0 : 10, top, 12, 6),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width - (i.isEven ? 22 : 12), top + 4, 12, 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BuzzingPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}
