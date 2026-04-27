import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_provider.dart';

// ─── Local data models ────────────────────────────────────────────────────────

class _Track {
  final String id;
  final String title;
  final String artistName;
  final String hlsUrl;
  final String? artworkUrl;
  final String? artistId;
  final String? artistPermalink;
  final int playCount;
  final List<int>? waveform;

  _Track({
    required this.id,
    required this.title,
    required this.artistName,
    required this.hlsUrl,
    this.artworkUrl,
    this.artistId,
    this.artistPermalink,
    this.playCount = 0,
    this.waveform,
  });

  factory _Track.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    return _Track(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artistId: artist['_id'] as String?,
      artistPermalink: artist['permalink'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String? ?? json['audioUrl'] as String? ?? '',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }

  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: id,
        title: title,
        artist: artistName,
        artistId: artistId,
        artistPermalink: artistPermalink,
        audioUrl: hlsUrl,
        coverUrl: artworkUrl,
        waveform: waveform,
      );
}

class _PlaylistInfo {
  final String id;
  final String title;
  final String ownerName;
  final String? artworkUrl;
  final int trackCount;

  _PlaylistInfo({
    required this.id,
    required this.title,
    required this.ownerName,
    this.artworkUrl,
    this.trackCount = 0,
  });

  factory _PlaylistInfo.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    return _PlaylistInfo(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      ownerName: creator?['displayName'] as String? ??
          json['ownerName'] as String? ??
          '',
      artworkUrl: json['artworkUrl'] as String?,
      trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class HiphopGenrePage extends ConsumerStatefulWidget {
  const HiphopGenrePage({super.key});

  @override
  ConsumerState<HiphopGenrePage> createState() => _HiphopGenrePageState();
}

class _HiphopGenrePageState extends ConsumerState<HiphopGenrePage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  // All tab — GET /discovery/genre/Hiphop%20%26%20rap
  List<_Track> _tracks = [];
  bool _isLoading = true;
  bool _hasError = false;

  // Trending tab — GET /discovery/trending?genre=Hiphop & rap (public, no auth)
  List<_Track> _trendingTracks = [];
  bool _isTrendingLoading = true;
  bool _trendingError = false;

  // Playlists tab — GET /playlists?genre=Hiphop & rap
  List<_PlaylistInfo> _playlists = [];
  bool _isPlaylistsLoading = true;
  bool _playlistsError = false;

  // Albums tab — GET /playlists?genre=Hiphop & rap&releaseType=album
  List<_PlaylistInfo> _albumPlaylists = [];
  bool _isAlbumsLoading = true;
  bool _albumsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isTrendingLoading = true;
      _trendingError = false;
      _isPlaylistsLoading = true;
      _playlistsError = false;
      _isAlbumsLoading = true;
      _albumsError = false;
    });

    await Future.wait([
      _fetchGenreTracks(),
      _fetchTrendingTracks(),
      _fetchPlaylists(),
      _fetchAlbums(),
    ]);
  }

  Future<void> _fetchGenreTracks() async {
    try {
      final resp = await dioClient.dio.get(
        '/discovery/genre/${Uri.encodeComponent('Hiphop & rap')}',
      );
      final respData = resp.data;
      List<dynamic> rawTracks;
      if (respData['data'] is List) {
        rawTracks = respData['data'] as List<dynamic>;
      } else if (respData['data'] is Map) {
        final m = respData['data'] as Map<String, dynamic>;
        rawTracks =
            (m['tracks'] ?? m['trending'] ?? m['items'] ?? []) as List<dynamic>;
      } else {
        rawTracks = [];
      }
      final tracks = rawTracks
          .whereType<Map<String, dynamic>>()
          .map(_Track.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList();
      if (mounted) setState(() { _tracks = tracks; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _fetchTrendingTracks() async {
    try {
      final resp = await dioClient.dio.get(
        '/discovery/trending',
        queryParameters: {'genre': 'Hiphop & rap'},
      );
      final data = resp.data['data'] as Map<String, dynamic>? ?? {};
      final raw = data['trending'] as List<dynamic>? ?? [];
      final tracks = raw
          .whereType<Map<String, dynamic>>()
          .map(_Track.fromJson)
          .where((t) => t.id.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() { _trendingTracks = tracks; _isTrendingLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _isTrendingLoading = false; _trendingError = true; });
    }
  }

  Future<void> _fetchPlaylists() async {
    try {
      final resp = await dioClient.dio.get(
        '/playlists',
        queryParameters: {'genre': 'Hiphop & rap', 'limit': 10},
      );
      final plData = resp.data;
      List<dynamic> rawPlaylists;
      if (plData['data'] is List) {
        rawPlaylists = plData['data'] as List<dynamic>;
      } else if (plData['data'] is Map) {
        final m = plData['data'] as Map<String, dynamic>;
        rawPlaylists = (m['playlists'] ?? m['items'] ?? []) as List<dynamic>;
      } else {
        rawPlaylists = [];
      }
      final playlists = rawPlaylists
          .whereType<Map<String, dynamic>>()
          .map(_PlaylistInfo.fromJson)
          .where((p) => p.id.isNotEmpty)
          .toList();
      if (mounted) setState(() { _playlists = playlists; _isPlaylistsLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isPlaylistsLoading = false; _playlistsError = true; });
    }
  }

  // Albums are fetched via the same playlists endpoint with a releaseType filter.
  // If the backend does not differentiate, this will return an empty list and
  // "No albums available" is shown — a real API call is still made.
  Future<void> _fetchAlbums() async {
    try {
      final resp = await dioClient.dio.get(
        '/playlists',
        queryParameters: {
          'genre': 'Hiphop & rap',
          'releaseType': 'album',
          'limit': 10,
        },
      );
      final plData = resp.data;
      List<dynamic> rawAlbums;
      if (plData['data'] is List) {
        rawAlbums = plData['data'] as List<dynamic>;
      } else if (plData['data'] is Map) {
        final m = plData['data'] as Map<String, dynamic>;
        rawAlbums = (m['playlists'] ?? m['items'] ?? []) as List<dynamic>;
      } else {
        rawAlbums = [];
      }
      final albums = rawAlbums
          .whereType<Map<String, dynamic>>()
          .map(_PlaylistInfo.fromJson)
          .where((p) => p.id.isNotEmpty)
          .toList();
      if (mounted) setState(() { _albumPlaylists = albums; _isAlbumsLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isAlbumsLoading = false; _albumsError = true; });
    }
  }

  void _playFrom(List<_Track> tracks, int index) {
    final valid = tracks.where((t) => t.hlsUrl.isNotEmpty).toList();
    if (valid.isEmpty) return;
    final queue = valid.map((t) => t.toPlayerTrack()).toList();
    final tapped = tracks[index];
    final start = valid.indexWhere((t) => t.id == tapped.id);
    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: start < 0 ? 0 : start,
        );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: const Color(0xFF111111),
            automaticallyImplyLeading: false,
            leading: GestureDetector(
              onTap: context.pop,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/Hiphop_&_Rap_bg.png',
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xE0111111)],
                        stops: [0.3, 1.0],
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 64,
                    left: 16,
                    right: 16,
                    child: Text(
                      'Hip Hop & Rap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontSize: 14),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Trending'),
                Tab(text: 'Playlists'),
                Tab(text: 'Albums'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllTab(),
            _buildTrendingTab(),
            _buildPlaylistsTab(),
            _buildAlbumsTab(),
          ],
        ),
      ),
    );
  }

  // ─── Tab content ───────────────────────────────────────────────────────────

  Widget _buildAllTab() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)));
    }
    if (_hasError) {
      return _buildErrorState(onRetry: _fetchAll);
    }
    if (_tracks.isEmpty) {
      return const Center(
          child: Text('No tracks found',
              style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: _tracks.length,
      itemBuilder: (_, i) => _buildTrackTile(_tracks, i),
    );
  }

  Widget _buildTrendingTab() {
    if (_isTrendingLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)));
    }
    if (_trendingError) {
      return _buildErrorState(
        onRetry: () async {
          setState(() { _isTrendingLoading = true; _trendingError = false; });
          await _fetchTrendingTracks();
        },
      );
    }
    if (_trendingTracks.isEmpty) {
      return const Center(
          child: Text('No trending tracks found',
              style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: _trendingTracks.length,
      itemBuilder: (_, i) => _buildTrackTile(_trendingTracks, i),
    );
  }

  Widget _buildPlaylistsTab() {
    if (_isPlaylistsLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)));
    }
    if (_playlistsError) {
      return _buildErrorState(
        onRetry: () async {
          setState(() { _isPlaylistsLoading = true; _playlistsError = false; });
          await _fetchPlaylists();
        },
      );
    }
    if (_playlists.isEmpty) {
      return const Center(
          child: Text('No playlists available',
              style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: _playlists.length,
      itemBuilder: (_, i) => _buildPlaylistTile(_playlists[i]),
    );
  }

  Widget _buildAlbumsTab() {
    if (_isAlbumsLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)));
    }
    if (_albumsError) {
      return _buildErrorState(
        onRetry: () async {
          setState(() { _isAlbumsLoading = true; _albumsError = false; });
          await _fetchAlbums();
        },
      );
    }
    if (_albumPlaylists.isEmpty) {
      return const Center(
          child: Text('No albums available',
              style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: _albumPlaylists.length,
      itemBuilder: (_, i) => _buildPlaylistTile(_albumPlaylists[i]),
    );
  }

  // ─── Item builders ─────────────────────────────────────────────────────────

  Widget _buildTrackTile(List<_Track> tracks, int index) {
    final track = tracks[index];
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        !track.artworkUrl!.contains('default-artwork');
    return GestureDetector(
      onTap: () => _playFrom(tracks, index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: track.artworkUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _artworkFallback(),
                    )
                  : _artworkFallback(),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (track.artistName.isNotEmpty)
                    Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white38, size: 13),
                      Text(
                        ' ${track.playCount}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white38),
              onPressed: () {},
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(_PlaylistInfo playlist) {
    final hasArtwork =
        playlist.artworkUrl != null && playlist.artworkUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: hasArtwork
                ? CachedNetworkImage(
                    imageUrl: playlist.artworkUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _artworkFallback(),
                  )
                : _artworkFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'by ${playlist.ownerName} · ${playlist.trackCount} tracks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared error state ────────────────────────────────────────────────────

  Widget _buildErrorState({required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to load. Please try again.',
            style: TextStyle(color: Colors.grey[400], fontSize: 15),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500)),
            child:
                const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Fallbacks ─────────────────────────────────────────────────────────────

  Widget _artworkFallback() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.music_note, color: Colors.white38, size: 24),
      );
}
