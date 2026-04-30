import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../../engagement/presentation/widgets/track_options_sheet.dart';
import '../../../player/presentation/providers/player_provider.dart';

class _PlaylistMeta {
  final String id;
  final String title;
  final String ownerName;
  final String? artworkUrl;
  final String? description;
  final int trackCount;
  int likeCount;
  final DateTime? createdAt;
  final String? subtitleOverride;
  bool isLiked;

  _PlaylistMeta({
    required this.id,
    required this.title,
    required this.ownerName,
    this.artworkUrl,
    this.description,
    this.trackCount = 0,
    this.likeCount = 0,
    this.createdAt,
    this.subtitleOverride,
    this.isLiked = false,
  });

  factory _PlaylistMeta.fromJson(Map<String, dynamic> json) {
    final creator = (json['creator'] is Map<String, dynamic>
            ? json['creator'] as Map<String, dynamic>
            : null) ??
        (json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : null);
    return _PlaylistMeta(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: (json['title'] ?? '').toString(),
      ownerName: _DetailTrack._pickDisplayName(
        [if (creator != null) creator, json],
        const [
          'displayName',
          'username',
          'name',
          'fullName',
          'ownerName',
          'creatorName',
        ],
      ),
      artworkUrl: (json['artworkUrl'] ?? json['artwork_url'])?.toString(),
      description: json['description']?.toString(),
      trackCount: (json['trackCount'] as num?)?.toInt() ??
          (json['track_count'] as num?)?.toInt() ??
          ((json['tracks'] is List) ? (json['tracks'] as List).length : 0),
      likeCount: (json['likeCount'] as num?)?.toInt() ??
          (json['like_count'] as num?)?.toInt() ??
          0,
      createdAt: DateTime.tryParse(
        (json['createdAt'] ?? json['created_at'] ?? '').toString(),
      ),
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }
}

class _DetailTrack {
  final String id;
  final String title;
  final String genre;
  final String artistName;
  final String hlsUrl;
  final String? artworkUrl;
  final String? artistId;
  final String? artistPermalink;
  final String? permalink;
  final List<int>? waveform;
  final int duration;
  final int playCount;
  final int likeCount;
  final DateTime? createdAt;

  _DetailTrack({
    required this.id,
    required this.title,
    required this.genre,
    required this.artistName,
    required this.hlsUrl,
    this.artworkUrl,
    this.artistId,
    this.artistPermalink,
    this.permalink,
    this.waveform,
    this.duration = 0,
    this.playCount = 0,
    this.likeCount = 0,
    this.createdAt,
  });

  _DetailTrack copyWith({
    String? artistName,
  }) => _DetailTrack(
        id: id,
        title: title,
        genre: genre,
        artistName: artistName ?? this.artistName,
        hlsUrl: hlsUrl,
        artworkUrl: artworkUrl,
        artistId: artistId,
        artistPermalink: artistPermalink,
        permalink: permalink,
        waveform: waveform,
        duration: duration,
        playCount: playCount,
        likeCount: likeCount,
        createdAt: createdAt,
      );

  factory _DetailTrack.fromJson(Map<String, dynamic> json) {
    final root = json;
    final target = root['target'];
    final nestedTrack = root['track'];
    final track = target is Map<String, dynamic>
        ? target
        : nestedTrack is Map<String, dynamic>
            ? nestedTrack
            : root;
    final artist = _pickEntityMap(
          [track, root],
          const ['artist', 'user', 'creator', 'owner', 'uploadedBy', 'uploader'],
        ) ??
        const <String, dynamic>{};
    final media = track['media'] is Map<String, dynamic>
        ? track['media'] as Map<String, dynamic>
        : null;
    final rawTranscodings = media == null ? null : media['transcodings'];
    final transcodings =
        rawTranscodings is List ? rawTranscodings.cast<dynamic>() : const <dynamic>[];
    Map<String, dynamic>? hlsTranscoding;
    for (final item in transcodings) {
      if (item is! Map<String, dynamic>) continue;
      final format = item['format'] is Map<String, dynamic>
          ? item['format'] as Map<String, dynamic>
          : null;
      if (format?['protocol'] == 'hls') {
        hlsTranscoding = item;
        break;
      }
    }
    final rawGenres = track['genres'];
    final genres = rawGenres is List
        ? rawGenres.whereType<Object>().map((e) => e.toString()).join(', ')
        : rawGenres?.toString() ?? '';
    final trackId =
        track['_id']?.toString() ?? track['id']?.toString() ?? '';
    final rawWaveform = track['waveform'];
    final waveform = rawWaveform is List
        ? rawWaveform.whereType<num>().map((e) => e.toInt()).toList()
        : null;
    final artistName = _pickDisplayName(
      [artist, track, root],
      const [
        'displayName',
        'username',
        'name',
        'fullName',
        'userName',
        'artist',
        'artistName',
        'creatorName',
        'uploadedByName',
        'uploaderName',
        'ownerName',
      ],
    );
    return _DetailTrack(
      id: trackId,
      title: (track['title'] ?? '').toString(),
      genre: (track['genre'] ?? genres).toString(),
      artistName: artistName,
      artistId: artist['_id']?.toString() ?? artist['id']?.toString(),
      artistPermalink: artist['permalink']?.toString(),
      permalink: track['permalink']?.toString(),
      artworkUrl: (track['artworkUrl'] ?? track['artwork_url'])?.toString(),
      hlsUrl: (track['hlsUrl'] ??
              media?['hlsUrl'] ??
              hlsTranscoding?['url'] ??
              track['audioUrl'] ??
              track['streamUrl'] ??
              (trackId.isNotEmpty
                  ? 'https://biobeatsstorage2026.blob.core.windows.net/biobeats-audio/hls/$trackId/playlist.m3u8'
                  : '') ??
              '')
          .toString(),
      waveform: waveform,
      duration: (track['duration'] as num?)?.toInt() ?? 0,
      playCount: (track['playCount'] as num?)?.toInt() ??
          (track['playback_count'] as num?)?.toInt() ??
          0,
      likeCount: (track['likeCount'] as num?)?.toInt() ??
          (track['like_count'] as num?)?.toInt() ??
          0,
      createdAt: track['created_at'] != null
          ? DateTime.tryParse(track['created_at'].toString())
          : track['createdAt'] != null
              ? DateTime.tryParse(track['createdAt'].toString())
              : null,
    );
  }

  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: id,
        title: title,
        artist: artistName,
        artistId: artistId,
        artistPermalink: artistPermalink,
        audioUrl: hlsUrl,
        coverUrl: artworkUrl?.isEmpty ?? true ? null : artworkUrl,
        waveform: waveform,
        trackPermalink: permalink?.isEmpty ?? true ? null : permalink,
      );

  static Map<String, dynamic>? _pickEntityMap(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];
        if (value is Map<String, dynamic>) return value;
      }
    }
    return null;
  }

  static String _pickDisplayName(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final rawValue = source[key];
        if (rawValue is Map || rawValue is List) continue;
        final value = rawValue?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }
}

class RnbPlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistId;
  final bool useBuzzingPreset;

  const RnbPlaylistDetailPage({
    super.key,
    required this.playlistId,
    this.useBuzzingPreset = false,
  });

  @override
  ConsumerState<RnbPlaylistDetailPage> createState() =>
      _RnbPlaylistDetailPageState();
}

class _SessionIdentity {
  final String userId;
  final String displayName;
  final String avatarUrl;
  final String permalink;

  const _SessionIdentity({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.permalink,
  });
}

class _RnbPlaylistDetailPageState extends ConsumerState<RnbPlaylistDetailPage> {
  _PlaylistMeta? _meta;
  List<_DetailTrack> _tracks = [];
  bool _isLoading = true;
  bool _hasError = false;
  _SessionIdentity? _currentUserIdentity;

  bool get _isBuzzingPreset => widget.useBuzzingPreset;
  static const _rnbQuery = 'R&B';
  static const _rnbGenreQueries = [
    'R&B',
    'RnB',
    'Rnb',
    'R & B',
    'R&B & Soul',
    'R and B',
  ];
  static const _buzzingLikeKey = 'buzzing_rnb_liked';

  static const _buzzingDescription =
      'Audio omakase based on what real R&B fans are connecting with. '
      'A spot on Buzzing is determined by what listeners are replaying, '
      'sharing, and keeping in rotation right now.';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserIdentity();
    _fetch();
  }

  _PlaylistMeta _buildBuzzingPresetMeta(
    List<_DetailTrack> tracks, {
    required bool isLiked,
    int? likeCount,
  }) {
    return _PlaylistMeta(
      id: widget.playlistId,
      title: 'Buzzing R&B',
      ownerName: 'New!',
      artworkUrl: _resolveBuzzingArtworkUrl(tracks),
      description: _buzzingDescription,
      trackCount: tracks.length,
      likeCount: likeCount ?? _resolveBuzzingLikeCount(tracks),
      isLiked: isLiked,
    );
  }

  String? _resolveBuzzingArtworkUrl(List<_DetailTrack> tracks) {
    final orderedTracks = List<_DetailTrack>.from(tracks)
      ..sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

    for (final track in orderedTracks) {
      final artworkUrl = track.artworkUrl;
      if (artworkUrl != null &&
          artworkUrl.isNotEmpty &&
          !artworkUrl.contains('default-artwork')) {
        return artworkUrl;
      }
    }
    return null;
  }

  int _resolveBuzzingLikeCount(List<_DetailTrack> tracks) {
    return tracks.fold(0, (sum, track) => sum + track.likeCount);
  }

  Future<void> _fetchBuzzingGenreTracks() async {
    final currentUser = await _loadCurrentUserIdentity();
    final discoveryResponses = await Future.wait(
      _rnbGenreQueries.map(
        (genre) => dioClient.dio
            .get('/discovery/genre/${Uri.encodeComponent(genre)}')
            .then<dynamic>((resp) => resp.data)
            .catchError((_) => null),
      ),
    );
    final trendingBody = await dioClient.dio
        .get(
          '/discovery/trending',
          queryParameters: {'genre': _rnbQuery},
        )
        .then<dynamic>((resp) => resp.data)
        .catchError((_) => null);
    final playlistBody = widget.playlistId.isNotEmpty
        ? await dioClient.dio
            .get('/playlists/${widget.playlistId}')
            .then<dynamic>((resp) => resp.data)
            .catchError((_) => null)
        : null;

    final mergedTracks = <_DetailTrack>[
      for (final body in discoveryResponses) ..._extractTracks(body),
      ..._extractTracks(trendingBody),
      ..._extractPlaylistTracks(playlistBody),
    ];
    var tracks = _dedupeTracks(mergedTracks);

    if (tracks.isEmpty) {
      final searchResponses = await Future.wait(
        _rnbGenreQueries.map(
          (query) => dioClient.dio
              .get(
                '/tracks/search',
                queryParameters: {'q': query, 'page': 1, 'limit': 24},
              )
              .then<dynamic>((resp) => resp.data)
              .catchError((_) => null),
        ),
      );
      tracks = _dedupeTracks([
        for (final body in searchResponses) ..._extractTracks(body),
      ]);
    }

    if (tracks.isEmpty) {
      final myTracksBody = await dioClient.dio
          .get('/tracks/my-tracks')
          .then<dynamic>((resp) => resp.data)
          .catchError((_) => null);
      tracks = _dedupeTracks(
        _extractTracks(myTracksBody)
            .where((track) => _matchesRnbGenre(track.genre))
            .map((track) => _applyCurrentUserIdentity(track, currentUser))
            .toList(),
      );
    }

    int? playlistLikeCount;
    if (playlistBody is Map<String, dynamic>) {
      final playlist =
          ((playlistBody['data'] as Map<String, dynamic>?)?['playlist'])
              as Map<String, dynamic>? ??
          {};
      playlistLikeCount = (playlist['likeCount'] as num?)?.toInt() ??
          (playlist['like_count'] as num?)?.toInt();
    }
    final prefs = await SharedPreferences.getInstance();
    final isLiked = prefs.getBool(_buzzingLikeKey) ?? false;
    if (!mounted) return;
    final resolvedTracks = tracks
        .map((track) => _applyCurrentUserIdentity(track, currentUser))
        .toList();
    setState(() {
      _meta = _buildBuzzingPresetMeta(
        resolvedTracks,
        isLiked: isLiked,
        likeCount: playlistLikeCount,
      );
      _tracks = resolvedTracks;
      _isLoading = false;
    });
  }

  List<_DetailTrack> _dedupeTracks(List<_DetailTrack> tracks) {
    final byId = <String, _DetailTrack>{};
    for (final track in tracks) {
      if (track.id.isEmpty) continue;
      byId.putIfAbsent(track.id, () => track);
    }
    return byId.values.toList();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    if (_isBuzzingPreset) {
      try {
        await _fetchBuzzingGenreTracks();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }
    try {
      final resp = await dioClient.dio.get('/playlists/${widget.playlistId}');
      final data = resp.data as Map<String, dynamic>;
      final playlist =
          ((data['data'] as Map<String, dynamic>?)?['playlist'])
              as Map<String, dynamic>? ??
          {};
      final meta = _PlaylistMeta.fromJson(playlist);
      final tracks = _extractPlaylistTracks(data);
      final currentUser = await _loadCurrentUserIdentity();
      if (!mounted) return;
      final resolvedTracks = tracks
          .map((track) => _applyCurrentUserIdentity(track, currentUser))
          .toList();
      setState(() {
        _meta = meta.trackCount == 0 && resolvedTracks.isNotEmpty
            ? _PlaylistMeta(
                id: meta.id,
                title: meta.title,
                ownerName: meta.ownerName,
                artworkUrl: meta.artworkUrl,
                description: meta.description,
                trackCount: resolvedTracks.length,
                likeCount: meta.likeCount,
                createdAt: meta.createdAt,
                subtitleOverride: meta.subtitleOverride,
                isLiked: meta.isLiked,
              )
            : meta;
        _tracks = resolvedTracks;
        _isLoading = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  List<_DetailTrack> _extractTracks(dynamic body) {
    if (body is! Map<String, dynamic>) return [];
    final data = body['data'];
    final raw = _coerceList(
      data,
      candidateKeys: const ['tracks', 'trending', 'items', 'results'],
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_DetailTrack.fromJson)
        .where((track) => track.id.isNotEmpty)
        .toList();
  }

  List<_DetailTrack> _extractPlaylistTracks(dynamic body) {
    if (body is! Map<String, dynamic>) return [];
    final playlist =
        ((body['data'] is Map<String, dynamic> ? body['data'] : null)?['playlist']
                is Map<String, dynamic>)
            ? (((body['data'] as Map<String, dynamic>)['playlist'])
                as Map<String, dynamic>)
            : null;
    final raw = _coerceList(
      playlist,
      candidateKeys: const ['tracks', 'items', 'results'],
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_DetailTrack.fromJson)
        .where((track) => track.id.isNotEmpty)
        .toList();
  }

  Future<_SessionIdentity?> _loadCurrentUserIdentity() async {
    if (_currentUserIdentity != null) return _currentUserIdentity;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final displayName = (prefs.getString('displayName') ??
            prefs.getString('username') ??
            prefs.getString('name') ??
            '')
        .trim();
    final avatarUrl = (prefs.getString('avatarUrl') ?? '').trim();
    final permalink = (prefs.getString('permalink') ?? '').trim();
    if (userId.isEmpty &&
        displayName.isEmpty &&
        avatarUrl.isEmpty &&
        permalink.isEmpty) {
      return null;
    }
    _currentUserIdentity = _SessionIdentity(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      permalink: permalink,
    );
    return _currentUserIdentity;
  }

  _DetailTrack _applyCurrentUserIdentity(
    _DetailTrack track,
    _SessionIdentity? currentUser,
  ) {
    if (currentUser == null) return track;
    return _DetailTrack(
      id: track.id,
      title: track.title,
      genre: track.genre,
      artistName: currentUser.displayName.isNotEmpty
          ? currentUser.displayName
          : track.artistName,
      hlsUrl: track.hlsUrl,
      artworkUrl: track.artworkUrl,
      artistId:
          currentUser.userId.isNotEmpty ? currentUser.userId : track.artistId,
      artistPermalink: currentUser.permalink.isNotEmpty
          ? currentUser.permalink
          : track.artistPermalink,
      permalink: track.permalink,
      waveform: track.waveform,
      duration: track.duration,
      playCount: track.playCount,
      likeCount: track.likeCount,
      createdAt: track.createdAt,
    );
  }

  List<dynamic> _coerceList(
    dynamic value, {
    List<String> candidateKeys = const [],
  }) {
    if (value is List<dynamic>) return value;
    if (value is Map<String, dynamic>) {
      for (final key in candidateKeys) {
        final nested = value[key];
        if (nested is List<dynamic>) return nested;
      }
      for (final nested in value.values) {
        if (nested is List<dynamic>) return nested;
      }
    }
    return const <dynamic>[];
  }

  bool _matchesRnbGenre(String? genre) {
    final normalized = _normalizeGenre(genre);
    return normalized.contains('rnb') ||
        normalized.contains('rb') ||
        normalized.contains('r and b') ||
        normalized.contains('soul');
  }

  String _normalizeGenre(String? value) {
    if (value == null) return '';
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _toggleLike() async {
    final meta = _meta;
    if (meta == null) return;
    final wasLiked = meta.isLiked;
    final previousLikeCount = meta.likeCount;
    setState(() {
      meta.isLiked = !wasLiked;
      meta.likeCount = wasLiked
          ? (previousLikeCount > 0 ? previousLikeCount - 1 : 0)
          : previousLikeCount + 1;
    });
    if (_isBuzzingPreset || meta.id.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_buzzingLikeKey, !wasLiked);
      return;
    }
    try {
      if (wasLiked) {
        await dioClient.dio.delete(
          '/tracks/${meta.id}/like',
          data: {'targetModel': 'Playlist'},
        );
      } else {
        await dioClient.dio.post(
          '/tracks/${meta.id}/like',
          data: {'targetModel': 'Playlist'},
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          meta.isLiked = wasLiked;
          meta.likeCount = previousLikeCount;
        });
      }
    }
  }

  void _showTrackOptionsSheet(String trackId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TrackOptionsSheet(trackId: trackId),
    );
  }

  void _playFrom(int tappedIndex) {
    final valid = _tracks.where((t) => t.hlsUrl.isNotEmpty).toList();
    if (valid.isEmpty) return;
    final queue = valid.map((t) => t.toPlayerTrack()).toList();
    final tappedId = _tracks[tappedIndex].id;
    final start = valid.indexWhere((t) => t.id == tappedId);
    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: start < 0 ? 0 : start,
        );
  }

  List<PlayerTrack> _playableQueue() => _tracks
      .where((track) => track.hlsUrl.isNotEmpty)
      .map((track) => track.toPlayerTrack())
      .toList();

  bool _sameQueue(List<PlayerTrack> a, List<PlayerTrack> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _shufflePlay() {
    final playableIndices = [
      for (var i = 0; i < _tracks.length; i++)
        if (_tracks[i].hlsUrl.isNotEmpty) i,
    ];
    if (playableIndices.isEmpty) return;
    final idx = playableIndices[Random().nextInt(playableIndices.length)];
    _playFrom(idx);
  }

  void _showDescriptionSheet(String desc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  splashRadius: 20,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                              'Buzzing R&B',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                desc,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtLikeCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  String _fmtPlayCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _fmtTotalDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String _fmtTrackDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String? _formatAge(DateTime? createdAt) {
    if (createdAt == null) return null;
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  int get _totalSeconds => _tracks.fold(0, (sum, t) => sum + t.duration);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Playlist',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF252525),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: context.pop,
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.cast_outlined, color: Colors.white70, size: 28),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            )
          : _hasError
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to load playlist.',
            style: TextStyle(color: Colors.grey[400], fontSize: 15),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final meta = _meta!;
    final hasDesc = meta.description != null && meta.description!.isNotEmpty;
    final fixedCount = hasDesc ? 3 : 2;

    return RefreshIndicator(
      onRefresh: _fetch,
      color: const Color(0xFFFF5500),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: fixedCount + (_tracks.isEmpty ? 1 : _tracks.length),
        itemBuilder: (_, i) {
          if (i == 0) return _buildHeaderItem(meta);
          if (i == 1) return _buildActionRow(meta);
          if (hasDesc && i == 2) return _buildDescriptionItem(meta.description!);
          if (_tracks.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No tracks',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ),
            );
          }
          return _buildTrackTile(i - fixedCount);
        },
      ),
    );
  }

  Widget _buildHeaderItem(_PlaylistMeta meta) {
    final hasArtwork = meta.artworkUrl != null &&
        meta.artworkUrl!.isNotEmpty &&
        !meta.artworkUrl!.contains('default-artwork');
    final totalSecs = _totalSeconds;
    final subtitle = meta.subtitleOverride ??
        _buildSubtitle(meta.trackCount, totalSecs, meta.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: hasArtwork
                ? CachedNetworkImage(
                    imageUrl: meta.artworkUrl!,
                    width: 156,
                    height: 156,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _artworkFallback156(),
                  )
                : _isBuzzingPreset
                    ? _buzzingPlaylistArtwork(156)
                    : _artworkFallback156(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(color: Colors.white24),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'By ${meta.ownerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildSubtitle(int trackCount, int totalSecs, DateTime? createdAt) {
    final parts = <String>['Playlist', '$trackCount Tracks'];
    if (totalSecs > 0) parts.add(_fmtTotalDuration(totalSecs));
    final age = _formatAge(createdAt);
    if (age != null) parts.add(age);
    return parts.join(' | ');
  }

  Widget _buildActionRow(_PlaylistMeta meta) {
    final playerState = ref.watch(playerProvider);
    final playableQueue = _playableQueue();
    final currentTrackId = playerState.currentTrack?.id;
    final isBuzzingActive = currentTrackId != null &&
        _sameQueue(playerState.queue, playableQueue) &&
        playableQueue.any((track) => track.id == currentTrackId);
    final showPause = isBuzzingActive && playerState.isPlaying;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleLike,
            child: Row(
              children: [
                Icon(
                  meta.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: meta.isLiked
                      ? const Color(0xFFFF5500)
                      : Colors.white54,
                  size: 28,
                ),
                if (meta.likeCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    _fmtLikeCount(meta.likeCount),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          const Icon(Icons.more_vert, color: Colors.white54, size: 28),
          const Spacer(),
          GestureDetector(
            onTap: _shufflePlay,
            child: const Icon(
              Icons.shuffle_rounded,
              color: Colors.white70,
              size: 30,
            ),
          ),
          const SizedBox(width: 26),
          GestureDetector(
            onTap: playableQueue.isEmpty
                ? null
                : () {
                    if (isBuzzingActive) {
                      ref.read(playerProvider.notifier).togglePlayPause();
                    } else {
                      _playFrom(0);
                    }
                  },
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: showPause ? 28 : 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionItem(String desc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showDescriptionSheet(desc),
            child: const Text(
              'Show more',
              style: TextStyle(
                color: Color(0xFF6EA8FF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(int i) {
    final track = _tracks[i];
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        !track.artworkUrl!.contains('default-artwork');
    return GestureDetector(
      onTap: () => _playFrom(i),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: track.artworkUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _artworkFallback60(),
                    )
                  : _artworkFallback60(),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName.isEmpty
                        ? 'Unknown artist'
                        : track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white54,
                        size: 15,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _fmtPlayCount(track.playCount),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (track.duration > 0) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        Text(
                          _fmtTrackDuration(track.duration),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showTrackOptionsSheet(track.id),
              icon: const Icon(Icons.more_vert, color: Colors.white38, size: 24),
              padding: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              splashRadius: 18,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buzzingPlaylistArtwork(double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1AA6A6),
              Color(0xFF0E1B1C),
              Color(0xFF0F7C80),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -size * 0.14,
              top: size * 0.1,
              child: _pixelSteps(size * 0.56),
            ),
            Positioned(
              right: -size * 0.08,
              bottom: size * 0.18,
              child: _pixelSteps(size * 0.48),
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                width: size * 0.58,
                height: size * 0.58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF94B9F8),
                      Color(0xFF1B2546),
                      Color(0xFF090B16),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  color: Colors.black87,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 7,
              child: Text(
                'BUZZING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 7,
              child: Text(
                          'R&B',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.08,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pixelSteps(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Wrap(
        spacing: size * 0.08,
        runSpacing: size * 0.08,
        children: List.generate(
          9,
          (index) => Container(
            width: size * 0.2,
            height: size * 0.2,
            color: index.isEven
                ? const Color(0xFFB8F2EE)
                : const Color(0xFF137C7F),
          ),
        ),
      ),
    );
  }

  Widget _artworkFallback156() => Container(
        width: 156,
        height: 156,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.queue_music, color: Colors.white38, size: 48),
      );

  Widget _artworkFallback60() => Container(
        width: 60,
        height: 60,
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.music_note, color: Colors.white38, size: 24),
      );
}
