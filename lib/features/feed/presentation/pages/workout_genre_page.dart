import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_client.dart';
import '../../../engagement/presentation/widgets/like_button.dart';
import '../../../playlist/domain/entities/playlist.dart';

class WorkoutGenrePage extends ConsumerStatefulWidget {
  const WorkoutGenrePage({super.key});

  @override
  ConsumerState<WorkoutGenrePage> createState() => _WorkoutGenrePageState();
}

class _WorkoutGenrePageState extends ConsumerState<WorkoutGenrePage>
    with TickerProviderStateMixin {
  static const _pageBackground = Color(0xFF111111);
  static const _panelBackground = Color(0xFF1A1A1A);
  static const _workoutGenreQueries = [
    'Workout',
    'workout',
  ];

  late final TabController _tabController;

  List<_PlaylistInfo> _playlists = [];
  bool _isPlaylistsLoading = true;
  bool _playlistsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPlaylists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaylists() async {
    if (mounted) {
      setState(() {
        _isPlaylistsLoading = true;
        _playlistsError = false;
      });
    }

    try {
      final responses = await Future.wait(
        _workoutGenreQueries.map(
          (genre) => dioClient.dio
              .get(
                '/playlists',
                queryParameters: {'genre': genre, 'limit': 24},
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
        .where((playlist) => playlist.id.isNotEmpty)
        .toList();
  }

  void _openPlaylist(_PlaylistInfo playlist) {
    context.push(
      '/playlist',
      extra: {'playlistId': playlist.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              backgroundColor: _pageBackground,
              surfaceTintColor: _pageBackground,
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.transparent,
              automaticallyImplyLeading: false,
              pinned: true,
              expandedHeight: 195,
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
                      'assets/images/Workout_bg.png',
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
                            Color(0x26000000),
                            Color(0xFF111111),
                          ],
                          stops: [0.0, 0.58, 1.0],
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 28,
                      right: 24,
                      bottom: 54,
                      child: Text(
                        'Workout',
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
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorColor: Colors.white,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.tab,
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
                    Tab(text: 'Playlists'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPlaylistTab(),
              _buildPlaylistTab(showSeeAllAction: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTab({bool showSeeAllAction = true}) {
    if (_isPlaylistsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    }

    if (_playlistsError) {
      return _buildErrorState();
    }

    if (_playlists.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchPlaylists,
        color: const Color(0xFFFF5500),
        backgroundColor: _panelBackground,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          children: const [
            Text(
              'No Workout playlists available right now.',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPlaylists,
      color: const Color(0xFFFF5500),
      backgroundColor: _panelBackground,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        children: [
          _buildSectionHeader(
            title: 'Playlists',
            actionLabel: showSeeAllAction ? 'See all' : null,
            onAction:
                showSeeAllAction ? () => _tabController.animateTo(1) : null,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 18,
                childAspectRatio: 0.78,
              ),
              itemCount: _playlists.length,
              itemBuilder: (_, index) => _buildPlaylistCard(_playlists[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(_PlaylistInfo playlist) {
    final hasArtwork = playlist.artworkUrl.isNotEmpty &&
        !playlist.artworkUrl.contains('default-artwork');

    return GestureDetector(
      onTap: () => _openPlaylist(playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasArtwork
                        ? CachedNetworkImage(
                            imageUrl: playlist.artworkUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _artworkFallback(),
                          )
                        : _artworkFallback(),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: PlaylistLikeButton(playlist: playlist.toPlaylist()),
                ),
              ],
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
            playlist.ownerName.isEmpty
                ? 'Discovery Playlists'
                : playlist.ownerName,
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

  Widget _buildSectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to load Workout playlists.',
            style: TextStyle(color: Colors.grey[400], fontSize: 15),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchPlaylists,
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

  Widget _artworkFallback() => Container(
        color: const Color(0xFF2A2A2A),
        child: const Icon(
          Icons.queue_music_rounded,
          color: Colors.white38,
          size: 36,
        ),
      );
}

class _PlaylistInfo {
  final String id;
  final String title;
  final String artworkUrl;
  final String ownerName;

  const _PlaylistInfo({
    required this.id,
    required this.title,
    required this.artworkUrl,
    required this.ownerName,
  });

  factory _PlaylistInfo.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>? ??
        json['user'] as Map<String, dynamic>?;
    return _PlaylistInfo(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      artworkUrl: (json['artworkUrl'] ?? json['artwork_url'] ?? '').toString(),
      ownerName: (json['ownerName'] ??
              creator?['displayName'] ??
              creator?['username'] ??
              'Discovery Playlists')
          .toString(),
    );
  }

  Playlist toPlaylist() => Playlist(
        id: id,
        title: title,
        artworkUrl: artworkUrl,
        ownerName: ownerName.isEmpty ? 'Discovery Playlists' : ownerName,
      );
}
