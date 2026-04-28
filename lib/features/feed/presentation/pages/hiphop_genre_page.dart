import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HiphopGenrePage extends ConsumerWidget {
  const HiphopGenrePage({super.key});

  @override
  ConsumerState<HiphopGenrePage> createState() => _HiphopGenrePageState();
}

class _HiphopGenrePageState extends ConsumerState<HiphopGenrePage>
    with TickerProviderStateMixin {
  static const _pageBackground = Color(0xFF111111);
  static const _panelBackground = Color(0xFF1A1A1A);
  static const _hiphopQuery = 'Hiphop & rap';
  static const _buzzingLikeKey = 'buzzing_hiphop_rap_liked';

  late final TabController _tabController;

  List<_Track> _tracks = [];
  bool _isLoading = true;
  bool _hasError = false;

  List<_Track> _trendingTracks = [];
  bool _isTrendingLoading = true;
  bool _trendingError = false;

  List<_PlaylistInfo> _playlists = [];
  bool _isPlaylistsLoading = true;
  bool _playlistsError = false;

  List<_PlaylistInfo> _albumPlaylists = [];
  bool _isAlbumsLoading = true;
  bool _albumsError = false;
  bool _isRecentCollectionLiked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBuzzingLikeState();
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
        '/discovery/genre/${Uri.encodeComponent(_hiphopQuery)}',
      );
      if (!mounted) return;
      setState(() {
        _tracks = _extractTracks(resp.data);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _fetchTrendingTracks() async {
    try {
      final resp = await dioClient.dio.get(
        '/discovery/trending',
        queryParameters: {'genre': _hiphopQuery},
      );
      final data = resp.data as Map<String, dynamic>;
      final raw = ((data['data'] as Map<String, dynamic>?) ?? {})['trending']
              as List<dynamic>? ??
          [];
      if (!mounted) return;
      setState(() {
        _trendingTracks = raw
            .whereType<Map<String, dynamic>>()
            .map(_Track.fromJson)
            .where((t) => t.id.isNotEmpty)
            .toList();
        _isTrendingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTrendingLoading = false;
        _trendingError = true;
      });
    }
  }

  Future<void> _fetchPlaylists() async {
    try {
      final resp = await dioClient.dio.get(
        '/playlists',
        queryParameters: {'genre': _hiphopQuery, 'limit': 10},
      );
      if (!mounted) return;
      setState(() {
        _playlists = _extractPlaylists(resp.data);
        _isPlaylistsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPlaylistsLoading = false;
        _playlistsError = true;
      });
    }
  }

  Future<void> _fetchAlbums() async {
    try {
      final resp = await dioClient.dio.get(
        '/playlists',
        queryParameters: {
          'genre': _hiphopQuery,
          'releaseType': 'album',
          'limit': 10,
        },
      );
      if (!mounted) return;
      setState(() {
        _albumPlaylists = _extractPlaylists(resp.data);
        _isAlbumsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAlbumsLoading = false;
        _albumsError = true;
      });
    }
  }

  List<_Track> _extractTracks(dynamic body) {
    if (body is! Map<String, dynamic>) return [];
    final data = body['data'];
    final raw = data is List
        ? data
        : data is Map<String, dynamic>
            ? (data['tracks'] ?? data['trending'] ?? data['items'] ?? [])
                as List<dynamic>
            : <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_Track.fromJson)
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  List<_PlaylistInfo> _extractPlaylists(dynamic body) {
    if (body is! Map<String, dynamic>) return [];
    final data = body['data'];
    final raw = data is List
        ? data
        : data is Map<String, dynamic>
            ? (data['playlists'] ?? data['items'] ?? []) as List<dynamic>
            : <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_PlaylistInfo.fromJson)
        .where((p) => p.id.isNotEmpty)
        .toList();
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

  List<_Track> get _previewTrendingTracks => _trendingTracks.isNotEmpty
      ? _trendingTracks.take(3).toList()
      : _tracks.take(3).toList();

  List<_Track> get _recentGenreTracks {
    final tracks = List<_Track>.from(_tracks);
    tracks.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return tracks;
  }

  List<List<_Track>> _chunkTracks(List<_Track> tracks, int size) {
    final chunks = <List<_Track>>[];
    for (int i = 0; i < tracks.length; i += size) {
      final end = (i + size < tracks.length) ? i + size : tracks.length;
      chunks.add(tracks.sublist(i, end));
    }
    return chunks;
  }

  void _playBuzzingPlaylist() {
    if (_tracks.isEmpty) return;
    _playFrom(_tracks, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: const ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(Colors.white54),
          trackColor: WidgetStatePropertyAll(Color(0x33262626)),
          trackBorderColor: WidgetStatePropertyAll(Colors.transparent),
          thickness: WidgetStatePropertyAll(6),
          radius: Radius.circular(8),
          thumbVisibility: WidgetStatePropertyAll(true),
          trackVisibility: WidgetStatePropertyAll(true),
        ),
      ),
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
            expandedHeight: 205,
            pinned: true,
            backgroundColor: _pageBackground,
            surfaceTintColor: _pageBackground,
            elevation: 0,
            scrolledUnderElevation: 0,
            shadowColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leadingWidth: 68,
            leading: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: GestureDetector(
                  onTap: context.pop,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D2D2D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/Hiphop_&_Rap_bg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x33000000),
                          Color(0xFF111111),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 28,
                    right: 24,
                    bottom: 54,
                    child: Text(
                      'Hip Hop & Rap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        height: 0.98,
                        letterSpacing: -1.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  dividerColor: Colors.transparent,
                  indicatorColor: Colors.white,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: EdgeInsets.zero,
                  labelPadding: EdgeInsets.zero,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Trending'),
                    Tab(text: 'Playlists'),
                    Tab(text: 'Albums'),
                  ],
                ),
              ),
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
      ),
    );
  }

  Widget _buildAllTab() {
    final previewTracks = _previewTrendingTracks;
    final trendingSlides = _chunkTracks(
      _trendingTracks.isNotEmpty ? _trendingTracks : _tracks,
      3,
    );
    final recentTracks = _recentGenreTracks;
    final isLoading =
        (_isLoading || _isTrendingLoading) &&
            previewTracks.isEmpty &&
            recentTracks.isEmpty;
    final hasBlockingError = _hasError && _trendingError;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    }
    if (hasBlockingError) {
      return _buildErrorState(onRetry: _fetchAll);
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: const Color(0xFFFF5500),
      backgroundColor: _panelBackground,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 32),
        children: [
          if (previewTracks.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'Trending',
              actionLabel: 'See all',
              onAction: () => _tabController.animateTo(1),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.94),
                itemCount: trendingSlides.length,
                padEnds: false,
                itemBuilder: (context, pageIndex) {
                  final slideTracks = trendingSlides[pageIndex];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: pageIndex == trendingSlides.length - 1 ? 16 : 8,
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < slideTracks.length; i++)
                          _buildTrendingPreviewTile(slideTracks, i),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (recentTracks.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Introducing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildRecentTracksCard(recentTracks),
          ],
          if (previewTracks.isEmpty && recentTracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Text(
                'No Hip Hop content available right now.',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingTab() {
    if (_isTrendingLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    }
    if (_trendingError) {
      return _buildErrorState(
        onRetry: () async {
          setState(() {
            _isTrendingLoading = true;
            _trendingError = false;
          });
          await _fetchTrendingTracks();
        },
      );
    }
    if (_trendingTracks.isEmpty) {
      return const Center(
        child: Text(
          'No trending tracks found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTrendingTracks,
      color: const Color(0xFFFF5500),
      backgroundColor: _panelBackground,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        itemCount: _trendingTracks.length,
        itemBuilder: (_, i) => _buildTrackListTile(_trendingTracks, i),
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    if (_isPlaylistsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    }
    if (_playlistsError) {
      return _buildErrorState(
        onRetry: () async {
          setState(() {
            _isPlaylistsLoading = true;
            _playlistsError = false;
          });
          await _fetchPlaylists();
        },
      );
    }
    if (_playlists.isEmpty) {
      return const Center(
        child: Text(
          'No playlists available',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPlaylists,
      color: const Color(0xFFFF5500),
      backgroundColor: _panelBackground,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _playlists.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildPlaylistListCard(_playlists[i]),
      ),
    );
  }

  Widget _buildAlbumsTab() {
    if (_isAlbumsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    }
    if (_albumsError) {
      return _buildErrorState(
        onRetry: () async {
          setState(() {
            _isAlbumsLoading = true;
            _albumsError = false;
          });
          await _fetchAlbums();
        },
      );
    }
    if (_albumPlaylists.isEmpty) {
      return const Center(
        child: Text(
          'No albums available',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAlbums,
      color: const Color(0xFFFF5500),
      backgroundColor: _panelBackground,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _albumPlaylists.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildPlaylistListCard(_albumPlaylists[i]),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingPreviewTile(List<_Track> tracks, int index) {
    final track = tracks[index];
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        !track.artworkUrl!.contains('default-artwork');

    return GestureDetector(
      onTap: () => _playFrom(tracks, index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: track.artworkUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _artworkFallback(52),
                    )
                  : _artworkFallback(52),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName.isEmpty ? 'Unknown artist' : track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showTrackOptionsSheet(track.id),
              icon: const Icon(Icons.more_horiz, color: Colors.white54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 18,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
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

  Future<void> _loadBuzzingLikeState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isRecentCollectionLiked = prefs.getBool(_buzzingLikeKey) ?? false;
    });
  }

  Future<void> _toggleBuzzingLike() async {
    final nextValue = !_isRecentCollectionLiked;
    setState(() {
      _isRecentCollectionLiked = nextValue;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_buzzingLikeKey, nextValue);
  }

  void _pushIntroducingPlaylist(String location) {
    context.push(location).then((_) {
      if (mounted) _loadBuzzingLikeState();
    });
  }

  void _openIntroducingPlaylist() {
    if (_playlists.isEmpty) {
      _pushIntroducingPlaylist('/search/hiphop/introducing');
      return;
    }

    final selectedPlaylist = _playlists.firstWhere(
      (playlist) {
        final title = playlist.title.toLowerCase();
        return title.contains('buzzing') || title.contains('introducing');
      },
      orElse: () => _playlists.first,
    );

    if (selectedPlaylist.id.isEmpty) {
      _pushIntroducingPlaylist('/search/hiphop/introducing');
      return;
    }

    final playlistId = Uri.encodeComponent(selectedPlaylist.id);
    _pushIntroducingPlaylist('/search/hiphop/introducing?playlistId=$playlistId');
  }

  Widget _buildRecentTracksCard(List<_Track> recentTracks) {
    final previewTracks = recentTracks.take(2).toList();
    final heroTrack = previewTracks.isNotEmpty ? previewTracks.first : recentTracks.first;
    const heroArtworkSize = 152.0;
    final hasArtwork = heroTrack.artworkUrl != null &&
        heroTrack.artworkUrl!.isNotEmpty &&
        !heroTrack.artworkUrl!.contains('default-artwork');
    final hasPlayablePlaylistTrack = _tracks.any((track) => track.hlsUrl.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openIntroducingPlaylist,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 1.22,
                    colors: [
                      const Color(0xFFD6B8FF).withValues(alpha: 0.96),
                      const Color(0xFFB58CFF).withValues(alpha: 0.88),
                      const Color(0xFF8D68D8).withValues(alpha: 0.68),
                      const Color(0xFF5E4686).withValues(alpha: 0.46),
                      const Color(0xFF352744).withValues(alpha: 0.24),
                    ],
                    stops: const [0.0, 0.22, 0.48, 0.76, 1.0],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: hasArtwork
                          ? CachedNetworkImage(
                              imageUrl: heroTrack.artworkUrl!,
                              width: heroArtworkSize,
                              height: heroArtworkSize,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _artworkFallback(heroArtworkSize),
                            )
                          : _artworkFallback(heroArtworkSize),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 18),
                          const Text(
                            'Buzzing Hip Hop & Rap',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'New!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xCC111111),
                                  shape: BoxShape.circle,
                                ),
                                child: GestureDetector(
                                  onTap: _toggleBuzzingLike,
                                  child: Icon(
                                    _isRecentCollectionLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: hasPlayablePlaylistTrack
                                    ? _playBuzzingPlaylist
                                    : null,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 30,
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
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF262626),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < previewTracks.length; i++) ...[
                    _buildFeaturedTrackRow(
                      previewTracks,
                      i,
                    ),
                    if (i < previewTracks.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedTrackRow(List<_Track> tracks, int index) {
    final track = tracks[index];
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        !track.artworkUrl!.contains('default-artwork');
    return GestureDetector(
      onTap: () => _playFrom(tracks, index),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasArtwork
                ? CachedNetworkImage(
                    imageUrl: track.artworkUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _artworkFallback(52),
                  )
                : _artworkFallback(52),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistName.isEmpty ? 'Unknown artist' : track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showTrackOptionsSheet(track.id),
            icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 18,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackListTile(List<_Track> tracks, int index) {
    final track = tracks[index];
    final hasArtwork = track.artworkUrl != null &&
        track.artworkUrl!.isNotEmpty &&
        !track.artworkUrl!.contains('default-artwork');

    return GestureDetector(
      onTap: () => _playFrom(tracks, index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: track.artworkUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _artworkFallback(50),
                    )
                  : _artworkFallback(50),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName.isEmpty ? 'Unknown artist' : track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (track.playCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _formatPlays(track.playCount),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ),
            IconButton(
              onPressed: () => _showTrackOptionsSheet(track.id),
              icon: const Icon(Icons.more_horiz, color: Colors.white54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 18,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistListCard(_PlaylistInfo playlist) {
    final hasArtwork =
        playlist.artworkUrl != null && playlist.artworkUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/search/playlist/${playlist.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panelBackground,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.push('/search/playlist/${playlist.id}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasArtwork
                    ? CachedNetworkImage(
                        imageUrl: playlist.artworkUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _artworkFallback(72),
                      )
                    : _artworkFallback(72),
              ),
            ),
            const SizedBox(width: 14),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    playlist.ownerName.isEmpty ? 'Playlist' : playlist.ownerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  if (playlist.trackCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.trackCount} tracks',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({required Future<void> Function() onRetry}) {
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
              backgroundColor: const Color(0xFFFF5500),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPlays(int plays) {
    if (plays >= 1000000) return '${(plays / 1000000).toStringAsFixed(1)}M';
    if (plays >= 1000) return '${(plays / 1000).toStringAsFixed(1)}K';
    return plays.toString();
  }

  Widget _artworkFallback(double size) => Container(
        width: size,
        height: size,
        color: const Color(0xFF2A2A2A),
        child: Icon(
          Icons.music_note,
          color: Colors.white38,
          size: size * 0.4,
        ),
      );
}
