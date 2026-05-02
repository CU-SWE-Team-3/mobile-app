import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/profile_navigation.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/providers/follow_provider.dart';
import '../../../engagement/presentation/widgets/track_options_sheet.dart';
class RnbGenrePage extends ConsumerStatefulWidget {
  const RnbGenrePage({super.key});

  @override
  ConsumerState<RnbGenrePage> createState() => _RnbGenrePageState();
}

class _RnbGenrePageState extends ConsumerState<RnbGenrePage>
    with TickerProviderStateMixin {
  static const _pageBackground = Color(0xFF111111);
  static const _panelBackground = Color(0xFF1A1A1A);
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
  _SessionIdentity? _currentUserIdentity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentUserIdentity();
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
      final currentUser = await _loadCurrentUserIdentity();
      final discoveryResponses = await Future.wait(
        _rnbGenreQueries.map(
          (genre) => dioClient.dio
              .get('/discovery/genre/${Uri.encodeComponent(genre)}')
              .then<dynamic>((resp) => resp.data)
              .catchError((_) => null),
        ),
      );

      final mergedTracks = <_Track>[];
      for (final body in discoveryResponses) {
        mergedTracks.addAll(_extractTracks(body));
      }

      var dedupedTracks = _dedupeTracks(mergedTracks);

      if (dedupedTracks.isEmpty) {
        final fallbackResponses = await Future.wait(
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

        final fallbackTracks = <_Track>[];
        for (final body in fallbackResponses) {
          fallbackTracks.addAll(_extractSearchTracks(body));
        }
        dedupedTracks = _dedupeTracks(fallbackTracks);
      }

      if (dedupedTracks.isEmpty) {
        final myTracksBody = await dioClient.dio
            .get('/tracks/my-tracks')
            .then<dynamic>((resp) => resp.data)
            .catchError((_) => null);
        final myTracks = _extractMyTracks(myTracksBody);
        dedupedTracks = _dedupeTracks(
          myTracks
              .where((track) => _matchesRnbGenre(track.genre))
              .map((track) => _applyCurrentUserIdentity(track, currentUser))
              .toList(),
        );
      }

      if (!mounted) return;
      setState(() {
        _tracks = dedupedTracks
            .map((track) => _applyCurrentUserIdentity(track, currentUser))
            .toList();
        _hasError = false;
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
      final currentUser = await _loadCurrentUserIdentity();
      final resp = await dioClient.dio.get(
        '/discovery/trending',
        queryParameters: {'genre': _rnbQuery},
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
            .map((track) => _applyCurrentUserIdentity(track, currentUser))
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
      final responses = await Future.wait(
        _rnbGenreQueries.map(
          (genre) => dioClient.dio
              .get(
                '/playlists',
                queryParameters: {'genre': genre, 'limit': 10},
              )
              .then<dynamic>((resp) => resp.data)
              .catchError((_) => null),
        ),
      );

      final merged = <_PlaylistInfo>[];
      for (final body in responses) {
        merged.addAll(_extractPlaylists(body));
      }

      final byId = <String, _PlaylistInfo>{};
      for (final playlist in merged) {
        if (playlist.id.isEmpty) continue;
        byId.putIfAbsent(playlist.id, () => playlist);
      }

      if (!mounted) return;
      setState(() {
        _playlists = byId.values.toList();
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
      final responses = await Future.wait(
        _rnbGenreQueries.map(
          (genre) => dioClient.dio
              .get(
                '/playlists',
                queryParameters: {
                  'genre': genre,
                  'releaseType': 'album',
                  'limit': 10,
                },
              )
              .then<dynamic>((resp) => resp.data)
              .catchError((_) => null),
        ),
      );

      final merged = <_PlaylistInfo>[];
      for (final body in responses) {
        merged.addAll(_extractPlaylists(body));
      }

      final byId = <String, _PlaylistInfo>{};
      for (final playlist in merged) {
        if (playlist.id.isEmpty) continue;
        byId.putIfAbsent(playlist.id, () => playlist);
      }

      if (!mounted) return;
      setState(() {
        _albumPlaylists = byId.values.toList();
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
    final raw = _coerceList(
      data,
      candidateKeys: const ['tracks', 'trending', 'items', 'results'],
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_Track.fromJson)
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  List<_Track> _extractSearchTracks(dynamic body) {
    if (body is! Map<String, dynamic>) return [];
    final raw = _coerceList(
      body['data'],
      candidateKeys: const ['tracks', 'items', 'results'],
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_Track.fromJson)
        .where((track) => track.id.isNotEmpty)
        .toList();
  }

  List<_Track> _extractMyTracks(dynamic body) {
    if (body is! Map<String, dynamic>) return [];
    final raw = _coerceList(
      body['data'],
      candidateKeys: const ['tracks', 'items', 'results'],
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_Track.fromJson)
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

  _Track _applyCurrentUserIdentity(
    _Track track,
    _SessionIdentity? currentUser,
  ) {
    if (currentUser == null) return track;
    return _Track(
      id: track.id,
      title: track.title,
      genre: track.genre,
      artistName: currentUser.displayName.isNotEmpty
          ? currentUser.displayName
          : track.artistName,
      artistId:
          currentUser.userId.isNotEmpty ? currentUser.userId : track.artistId,
      artistPermalink: currentUser.permalink.isNotEmpty
          ? currentUser.permalink
          : track.artistPermalink,
      artistAvatarUrl: currentUser.avatarUrl.isNotEmpty
          ? currentUser.avatarUrl
          : track.artistAvatarUrl,
      artworkUrl: track.artworkUrl,
      hlsUrl: track.hlsUrl,
      permalink: track.permalink,
      waveform: track.waveform,
      playCount: track.playCount,
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

  List<_Track> _dedupeTracks(List<_Track> tracks) {
    final byId = <String, _Track>{};
    for (final track in tracks) {
      if (track.id.isEmpty) continue;
      byId.putIfAbsent(track.id, () => track);
    }
    return byId.values.toList();
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

  List<_Track> get _effectiveTrendingTracks =>
      _trendingTracks.isNotEmpty ? _trendingTracks : _tracks;

  List<_Track> get _previewTrendingTracks =>
      _effectiveTrendingTracks.take(3).toList();

  List<_Track> get _recentGenreTracks {
    final tracks = List<_Track>.from(_tracks);
    tracks.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return tracks;
  }

  List<_ArtistProfile> get _artistProfiles {
    final byKey = <String, _ArtistProfile>{};
    for (final track in _tracks) {
      final artist = _ArtistProfile.fromTrack(track);
      if (artist == null) continue;
      final key = artist.permalink.isNotEmpty ? artist.permalink : artist.name;
      byKey.putIfAbsent(key.toLowerCase(), () => artist);
    }
    return byKey.values.take(8).toList();
  }

  List<_Track> get _discoverMoreTracks {
    final recentTracks = _recentGenreTracks;
    if (recentTracks.length <= 2) return recentTracks;
    return recentTracks.skip(2).take(6).toList();
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

  List<PlayerTrack> _buzzingQueue() => _tracks
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
                    'assets/images/R&B_bg.png',
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
                      'R&B',
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
    final trendingSlides = _chunkTracks(_effectiveTrendingTracks, 3);
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
          const SizedBox(height: 20),
          _buildHomePlaylistsSection(),
          const SizedBox(height: 20),
          _buildHomeAlbumsSection(),
          if (_isLoading || _hasError || _artistProfiles.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildProfilesSection(),
          ],
          if (recentTracks.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildDiscoverMoreTracksSection(),
          ],
          if (previewTracks.isEmpty &&
              recentTracks.isEmpty &&
              _playlists.isEmpty &&
              _albumPlaylists.isEmpty &&
              _artistProfiles.isEmpty &&
              !_isPlaylistsLoading &&
              !_isAlbumsLoading &&
              !_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Text(
                'No R&B content available right now.',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingTab() {
    final trendingTracks = _effectiveTrendingTracks;
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
    if (trendingTracks.isEmpty) {
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
        itemCount: trendingTracks.length,
        itemBuilder: (_, i) => _buildTrackListTile(trendingTracks, i),
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
    final hasArtwork = track.artworkUrl.isNotEmpty &&
        !track.artworkUrl.contains('default-artwork');

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
                      imageUrl: track.artworkUrl,
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
              onPressed: () => _showTrackOptionsSheet(track),
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

  void _showTrackOptionsSheet(_Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TrackOptionsSheet(
        trackId: track.id,
        title: track.title,
        artistName: track.artistName,
        artworkUrl: track.artworkUrl.isEmpty ? null : track.artworkUrl,
        audioUrl: track.hlsUrl.isEmpty ? null : track.hlsUrl,
        waveform: track.waveform,
        artistId: track.artistId.isEmpty ? null : track.artistId,
        artistPermalink: track.artistPermalink.isEmpty ? null : track.artistPermalink,
        trackPermalink: track.permalink.isEmpty ? null : track.permalink,
      ),
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
      _pushIntroducingPlaylist('/search/rnb/introducing');
      return;
    }

    final selectedPlaylist = _playlists.firstWhere(
      (playlist) {
        final title = playlist.title.toLowerCase();
        return title.contains('buzzing r&b') ||
            title.contains('buzzing rnb') ||
            title.contains('buzzing');
      },
      orElse: () => _playlists.first,
    );

    if (selectedPlaylist.id.isEmpty) {
      _pushIntroducingPlaylist('/search/rnb/introducing');
      return;
    }

    final playlistId = Uri.encodeComponent(selectedPlaylist.id);
    _pushIntroducingPlaylist('/search/rnb/introducing?playlistId=$playlistId');
  }

  Widget _buildRecentTracksCard(List<_Track> recentTracks) {
    if (recentTracks.isEmpty) {
      return const SizedBox.shrink();
    }
    final playerState = ref.watch(playerProvider);
    final previewTracks = recentTracks.take(2).toList();
    final heroTrack = recentTracks.firstWhere(
      (track) =>
          track.artworkUrl.isNotEmpty &&
          !track.artworkUrl.contains('default-artwork'),
      orElse: () => recentTracks.first,
    );
    const heroArtworkSize = 152.0;
    final hasArtwork = heroTrack.artworkUrl.isNotEmpty &&
        !heroTrack.artworkUrl.contains('default-artwork');
    final buzzingQueue = _buzzingQueue();
    final hasPlayablePlaylistTrack = buzzingQueue.isNotEmpty;
    final currentTrackId = playerState.currentTrack?.id;
    final isBuzzingActive = currentTrackId != null &&
        _sameQueue(playerState.queue, buzzingQueue) &&
        buzzingQueue.any((track) => track.id == currentTrackId);
    final showPause = isBuzzingActive && playerState.isPlaying;

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
                      const Color(0xFFB8F2EE).withValues(alpha: 0.96),
                      const Color(0xFF72D6CF).withValues(alpha: 0.88),
                      const Color(0xFF2FA7A3).withValues(alpha: 0.68),
                      const Color(0xFF156768).withValues(alpha: 0.46),
                      const Color(0xFF0B2426).withValues(alpha: 0.24),
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
                              imageUrl: heroTrack.artworkUrl,
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
                            'Buzzing R&B',
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
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _toggleBuzzingLike,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xCC111111),
                                    shape: BoxShape.circle,
                                  ),
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
                                behavior: HitTestBehavior.opaque,
                                onTap: hasPlayablePlaylistTrack
                                    ? () {
                                        if (isBuzzingActive) {
                                          ref
                                              .read(playerProvider.notifier)
                                              .togglePlayPause();
                                        } else {
                                          _playBuzzingPlaylist();
                                        }
                                      }
                                    : null,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    showPause
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: showPause ? 26 : 30,
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
    final hasArtwork = track.artworkUrl.isNotEmpty &&
        !track.artworkUrl.contains('default-artwork');
    return GestureDetector(
      onTap: () => _playFrom(tracks, index),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasArtwork
                ? CachedNetworkImage(
                    imageUrl: track.artworkUrl,
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
            onPressed: () => _showTrackOptionsSheet(track),
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
    final hasArtwork = track.artworkUrl.isNotEmpty &&
        !track.artworkUrl.contains('default-artwork');

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
                      imageUrl: track.artworkUrl,
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
              onPressed: () => _showTrackOptionsSheet(track),
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
        playlist.artworkUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push(
                '/search/rnb/introducing?playlistId=${Uri.encodeComponent(playlist.id)}',
              ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panelBackground,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.push(
                '/search/rnb/introducing?playlistId=${Uri.encodeComponent(playlist.id)}',
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasArtwork
                    ? CachedNetworkImage(
                        imageUrl: playlist.artworkUrl,
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

  Widget _buildPlaylistsGrid() {
    final gridPlaylists = _playlists.take(4).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: gridPlaylists.length,
        itemBuilder: (_, i) => _buildPlaylistGridCard(gridPlaylists[i]),
      ),
    );
  }

  Widget _buildAlbumsGrid() {
    final gridAlbums = _albumPlaylists.take(4).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: gridAlbums.length,
        itemBuilder: (_, i) => _buildPlaylistGridCard(gridAlbums[i]),
      ),
    );
  }

  Widget _buildHomePlaylistsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Playlists',
          actionLabel: 'See all',
          onAction: () => _tabController.animateTo(2),
        ),
        const SizedBox(height: 12),
        if (_isPlaylistsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            ),
          )
        else if (_playlistsError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildInlineRetryCard(onRetry: _fetchPlaylists),
          )
        else if (_playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No R&B playlists available right now.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          )
        else
          _buildPlaylistsGrid(),
      ],
    );
  }

  Widget _buildHomeAlbumsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Albums',
          actionLabel: 'See all',
          onAction: () => _tabController.animateTo(3),
        ),
        const SizedBox(height: 12),
        if (_isAlbumsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            ),
          )
        else if (_albumsError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildInlineRetryCard(
              message: 'Failed to load R&B albums.',
              onRetry: _fetchAlbums,
            ),
          )
        else if (_albumPlaylists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No R&B albums available right now.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          )
        else
          _buildAlbumsGrid(),
      ],
    );
  }

  Widget _buildProfilesSection() {
    final artists = _artistProfiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title: 'Profiles'),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            ),
          )
        else if (_hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildInlineRetryCard(
              message: 'Failed to load R&B artist profiles.',
              onRetry: _fetchGenreTracks,
            ),
          )
        else if (artists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No R&B artist profiles available right now.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          )
        else
          SizedBox(
            height: 176,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildArtistProfileCard(artists[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildDiscoverMoreTracksSection() {
    final tracks = _discoverMoreTracks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title: 'Discover more tracks'),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            ),
          )
        else if (_hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildInlineRetryCard(
              message: 'Failed to load more R&B tracks.',
              onRetry: _fetchGenreTracks,
            ),
          )
        else if (tracks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No more R&B tracks available right now.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildTrackListTile(tracks, i),
          ),
      ],
    );
  }

  Widget _buildArtistProfileCard(_ArtistProfile artist) {
    final followState =
        artist.id.isNotEmpty ? ref.watch(followProvider(artist.id)) : null;
    final hasAvatar = artist.avatarUrl.isNotEmpty &&
        !artist.avatarUrl.contains('default-avatar');
    final initial = artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: artist.permalink.isEmpty
          ? null
          : () => navigateToUserProfile(
                context,
                userId: artist.id,
                permalink: artist.permalink,
                displayName: artist.name,
              ),
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFF262626),
              child: hasAvatar
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: artist.avatarUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 68,
              height: 22,
              child: ElevatedButton(
                onPressed: artist.id.isEmpty ||
                        followState == null ||
                        followState.isLoading ||
                        followState.isChecking
                    ? null
                    : () => ref
                        .read(followProvider(artist.id).notifier)
                        .toggle(artist.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: followState?.isFollowing == true
                      ? const Color(0xFF2A2A2A)
                      : Colors.white,
                  foregroundColor: followState?.isFollowing == true
                      ? Colors.white
                      : Colors.black,
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: followState?.isLoading == true ||
                        followState?.isChecking == true
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: followState?.isFollowing == true
                              ? Colors.white
                              : Colors.black,
                        ),
                      )
                    : Text(
                        followState?.isFollowing == true
                            ? 'Following'
                            : 'Follow',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistGridCard(_PlaylistInfo playlist) {
    final hasArtwork = playlist.artworkUrl.isNotEmpty &&
        !playlist.artworkUrl.contains('default-artwork');
    return GestureDetector(
      onTap: () => context.push(
        '/search/rnb/introducing?playlistId=${Uri.encodeComponent(playlist.id)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: playlist.artworkUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white38,
                          size: 36,
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF2A2A2A),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white38,
                        size: 36,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            playlist.ownerName.isEmpty ? 'Playlist' : playlist.ownerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
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

  Widget _buildInlineRetryCard({
    required Future<void> Function() onRetry,
    String message = 'Failed to load R&B playlists.',
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: Colors.grey[300], fontSize: 14),
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
class _Track {
  final String id;
  final String title;
  final String genre;
  final String artistName;
  final String artistId;
  final String artistPermalink;
  final String artistAvatarUrl;
  final String artworkUrl;
  final String hlsUrl;
  final String permalink;
  final List<int>? waveform;
  final int playCount;
  final DateTime? createdAt;

  const _Track({
    required this.id,
    required this.title,
    required this.genre,
    required this.artistName,
    required this.artistId,
    required this.artistPermalink,
    required this.artistAvatarUrl,
    required this.artworkUrl,
    required this.hlsUrl,
    required this.permalink,
    this.waveform,
    required this.playCount,
    this.createdAt,
  });

  _Track copyWith({
    String? artistName,
  }) => _Track(
        id: id,
        title: title,
        genre: genre,
        artistName: artistName ?? this.artistName,
        artistId: artistId,
        artistPermalink: artistPermalink,
        artistAvatarUrl: artistAvatarUrl,
        artworkUrl: artworkUrl,
        hlsUrl: hlsUrl,
        permalink: permalink,
        waveform: waveform,
        playCount: playCount,
        createdAt: createdAt,
      );

  factory _Track.fromJson(dynamic json) {
    final root = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final target = root['target'];
    final nestedTrack = root['track'];
    final track = target is Map<String, dynamic>
        ? target
        : nestedTrack is Map<String, dynamic>
            ? nestedTrack
            : root;
    final user = _pickEntityMap(
          [track, root],
          const [
            'user',
            'artist',
            'creator',
            'owner',
            'uploadedBy',
            'uploader',
          ],
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
    final artworkValue =
        (track['artworkUrl'] ?? track['artwork_url'] ?? '').toString();
    final trackId =
        track['_id']?.toString() ?? track['id']?.toString() ?? '';

    final rawWaveform = track['waveform'];
    final waveform = rawWaveform is List
        ? rawWaveform.whereType<num>().map((e) => e.toInt()).toList()
        : null;

    final permalinkValue = track['permalink'];
    final uploaderName = _pickDisplayName(
      [user, track, root],
      const [
        'displayName',
        'username',
        'name',
        'fullName',
        'userName',
        'artist',
        'ownerName',
        'artistName',
        'uploadedByName',
        'uploaderName',
        'creatorName',
      ],
    );
    return _Track(
      id: trackId,
      title: (track['title'] ?? '').toString(),
      genre: (track['genre'] ?? genres).toString(),
      artistName: uploaderName,
      artistId: user['_id']?.toString() ?? user['id']?.toString() ?? '',
      artistPermalink: (user['permalink'] ?? '').toString(),
      artistAvatarUrl: (user['avatarUrl'] ?? '').toString(),
      artworkUrl: artworkValue
          .replaceAll('large', 't500x500'),
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
      permalink: permalinkValue?.toString() ?? '',
      waveform: waveform,
      playCount: (track['playback_count'] as num?)?.toInt() ??
          (track['playCount'] as num?)?.toInt() ??
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
      artistId: artistId.isEmpty ? null : artistId,
      artistPermalink: artistPermalink.isEmpty ? null : artistPermalink,
      audioUrl: hlsUrl,
      coverUrl: artworkUrl.isEmpty ? null : artworkUrl,
      waveform: waveform,
      trackPermalink: permalink.isEmpty ? null : permalink,
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

class _ArtistProfile {
  final String id;
  final String name;
  final String permalink;
  final String avatarUrl;

  const _ArtistProfile({
    required this.id,
    required this.name,
    required this.permalink,
    required this.avatarUrl,
  });

  static _ArtistProfile? fromTrack(_Track track) {
    if (track.artistName.isEmpty) return null;
    return _ArtistProfile(
      id: track.artistId,
      name: track.artistName,
      permalink: track.artistPermalink,
      avatarUrl: track.artistAvatarUrl,
    );
  }
}

class _PlaylistInfo {
  final String id;
  final String title;
  final String artworkUrl;
  final String ownerName;
  final int trackCount;

  const _PlaylistInfo({
    required this.id,
    required this.title,
    required this.artworkUrl,
    required this.ownerName,
    required this.trackCount,
  });

  factory _PlaylistInfo.fromJson(dynamic json) => _PlaylistInfo(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        title: (json['title'] ?? '').toString(),
        artworkUrl: (json['artwork_url'] ?? json['artworkUrl'] ?? '')
            .toString()
            .replaceAll('large', 't500x500'),
        ownerName: ((json['user'] is Map<String, dynamic>
                        ? json['user']['username']
                        : null) ??
                    (json['creator'] is Map<String, dynamic>
                        ? json['creator']['displayName']
                        : null) ??
                    '')
                .toString(),
        trackCount: (json['track_count'] as num?)?.toInt() ??
            (json['trackCount'] as num?)?.toInt() ??
            0,
      );
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
