import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/utils/profile_navigation.dart';
import 'package:soundcloud_clone/features/engagement/presentation/widgets/track_options_sheet.dart';
import 'package:soundcloud_clone/features/followers/presentation/widgets/suggested_row.dart';
import 'package:soundcloud_clone/features/notifications/presentation/providers/notification_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

class _FeedTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
  final String? artworkUrl;
  final String hlsUrl;
  final int playCount;
  final int likeCount;
  final int repostCount;
  final bool isLiked;
  final bool isReposted;
  final List<int>? waveform;

  const _FeedTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artworkUrl,
    required this.hlsUrl,
    required this.playCount,
    this.artistId,
    this.artistPermalink,
    this.likeCount = 0,
    this.repostCount = 0,
    this.isLiked = false,
    this.isReposted = false,
    this.waveform,
  });

  factory _FeedTrack.fromJson(Map<String, dynamic> json) {
    final target = json['target'] as Map<String, dynamic>?;
    final track = target ?? json;
    final artist = track['artist'] as Map<String, dynamic>? ?? {};
    return _FeedTrack(
      id: track['_id'] as String? ?? '',
      title: track['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artistId: artist['_id'] as String?,
      artistPermalink: artist['permalink'] as String?,
      artworkUrl: track['artworkUrl'] as String?,
      hlsUrl: track['hlsUrl'] as String? ?? '',
      playCount: (track['playCount'] as num?)?.toInt() ?? 0,
      likeCount: (track['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (track['repostCount'] as num?)?.toInt() ?? 0,
      isLiked: track['isLiked'] as bool? ?? false,
      isReposted: track['isReposted'] as bool? ?? false,
      waveform: (track['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }

  _FeedTrack copyWith({
    bool? isLiked,
    bool? isReposted,
    int? likeCount,
    int? repostCount,
  }) {
    return _FeedTrack(
      id: id,
      title: title,
      artistName: artistName,
      artworkUrl: artworkUrl,
      hlsUrl: hlsUrl,
      playCount: playCount,
      artistId: artistId,
      artistPermalink: artistPermalink,
      likeCount: likeCount ?? this.likeCount,
      repostCount: repostCount ?? this.repostCount,
      isLiked: isLiked ?? this.isLiked,
      isReposted: isReposted ?? this.isReposted,
      waveform: waveform,
    );
  }
}

class _GenreTheme {
  final String label;
  final String query;
  final Color accent;
  final Color glow;
  final List<Color> surface;

  const _GenreTheme({
    required this.label,
    required this.query,
    required this.accent,
    required this.glow,
    required this.surface,
  });
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const List<_GenreTheme> _genres = [
    _GenreTheme(
      label: 'INDIE',
      query: 'Indie',
      accent: Color(0xFF6A89FF),
      glow: Color(0x333C5BFF),
      surface: [Color(0xFF182033), Color(0xFF13161F)],
    ),
    _GenreTheme(
      label: 'SOUNDCLOUD',
      query: 'SoundCloud',
      accent: Color(0xFFFF7A3C),
      glow: Color(0x33FF6428),
      surface: [Color(0xFF2A1F18), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'ELECTRONIC',
      query: 'Electronic',
      accent: Color(0xFFFF4AA2),
      glow: Color(0x33FF4AA2),
      surface: [Color(0xFF2B1B27), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'COUNTRY',
      query: 'Country',
      accent: Color(0xFFF1C36B),
      glow: Color(0x33F1C36B),
      surface: [Color(0xFF30261A), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'TECHNO',
      query: 'Techno',
      accent: Color(0xFFFF5AA7),
      glow: Color(0x33FF5AA7),
      surface: [Color(0xFF2E1B25), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'REGGAE',
      query: 'Reggae',
      accent: Color(0xFF53E6A4),
      glow: Color(0x3353E6A4),
      surface: [Color(0xFF18271E), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'JAZZ',
      query: 'Jazz',
      accent: Color(0xFFBBB2FF),
      glow: Color(0x33BBB2FF),
      surface: [Color(0xFF201D2A), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'POP',
      query: 'Pop',
      accent: Color(0xFFEED17A),
      glow: Color(0x33EED17A),
      surface: [Color(0xFF2A2418), Color(0xFF141414)],
    ),
    _GenreTheme(
      label: 'FOLK',
      query: 'Folk',
      accent: Color(0xFF9AD0A2),
      glow: Color(0x339AD0A2),
      surface: [Color(0xFF1C241C), Color(0xFF141414)],
    ),
  ];

  int _selectedGenreIndex = 2;
  List<_FeedTrack> _tracks = [];
  List<_FeedTrack> _likedTracks = [];
  List<_FeedTrack> _trendingTracks = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isTrendingLoading = false;
  bool _trendingError = false;
  String _displayName = 'you';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchFeed();
    _fetchTrending();
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

      final likedIds = <String>{};
      final repostedIds = <String>{};
      final likedTracks = <_FeedTrack>[];

      if (userId.isNotEmpty) {
        try {
          final likesResponse = await dioClient.dio.get('/profile/$userId/likes');
          final likesData = likesResponse.data['data'] as Map<String, dynamic>? ?? {};
          final likedItems = likesData['likedTracks'] as List<dynamic>? ?? [];
          for (final item in likedItems) {
            final trackMap =
                (item as Map<String, dynamic>)['track'] as Map<String, dynamic>?;
            if (trackMap == null) continue;
            final id = trackMap['_id'] as String? ?? '';
            if (id.isEmpty) continue;
            likedIds.add(id);
            if (likedTracks.length < 4) {
              likedTracks.add(_FeedTrack.fromJson(trackMap));
            }
          }
        } catch (_) {}

        try {
          final repostsResponse =
              await dioClient.dio.get('/profile/$userId/reposts');
          final repostData =
              repostsResponse.data['data'] as Map<String, dynamic>? ?? {};
          final repostItems = repostData['repostedTracks'] as List<dynamic>? ?? [];
          for (final item in repostItems) {
            final trackMap =
                (item as Map<String, dynamic>)['track'] as Map<String, dynamic>?;
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
    setState(() {
      _isTrendingLoading = true;
      _trendingError = false;
    });

    try {
      final response = await dioClient.dio.get(
        '/discovery/trending',
        queryParameters: {'genre': _genres[_selectedGenreIndex].query},
      );
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final rawTrending = data['trending'] as List<dynamic>? ?? [];
      var tracks = rawTrending
          .map((e) => _FeedTrack.fromJson(e as Map<String, dynamic>))
          .where((track) => track.id.isNotEmpty)
          .toList();

      if (tracks.isEmpty) {
        tracks = _poolTracks().take(5).toList();
      }

      if (mounted) {
        setState(() {
          _trendingTracks = tracks;
          _isTrendingLoading = false;
        });
      }
    } on DioException catch (error) {
      debugPrint('Trending error: ${error.response?.statusCode} ${error.message}');
      if (mounted) {
        setState(() {
          _trendingTracks = _poolTracks().take(5).toList();
          _isTrendingLoading = false;
          _trendingError = false;
        });
      }
    } catch (error) {
      debugPrint('Trending error: $error');
      if (mounted) {
        setState(() {
          _trendingTracks = _poolTracks().take(5).toList();
          _isTrendingLoading = false;
          _trendingError = false;
        });
      }
    }
  }

  List<_FeedTrack> _poolTracks() {
    final ordered = [..._likedTracks, ..._tracks, ..._trendingTracks];
    final seen = <String>{};
    final unique = <_FeedTrack>[];
    for (final track in ordered) {
      if (track.id.isEmpty || !seen.add(track.id)) continue;
      unique.add(track);
    }
    return unique;
  }

  List<_FeedTrack> _sectionTracks(int start, int count) {
    final pool = _poolTracks();
    if (pool.isEmpty) return const [];
    final result = <_FeedTrack>[];
    for (int i = 0; i < count; i++) {
      result.add(pool[(start + i) % pool.length]);
    }
    return result;
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
            waveform: item.waveform,
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

  Widget _buildSectionHeader(String title, {bool showSeeAll = false}) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        artistId: track.artistId,
        artistPermalink: track.artistPermalink,
      ),
    );
  }

  Widget _buildLikesBanner() {
    return GestureDetector(
      onTap: () => context.push('/likes'),
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
                Container(
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
              ],
            ),
            const SizedBox(height: 14),
            if (_likedTracks.isEmpty)
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
                      Expanded(child: _SmallTrackTile(track: _likedTracks[0])),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SmallTrackTile(
                          track: _likedTracks[_likedTracks.length > 1 ? 1 : 0],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallTrackTile(
                          track: _likedTracks[_likedTracks.length > 2 ? 2 : 0],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SmallTrackTile(
                          track: _likedTracks[_likedTracks.length > 3 ? 3 : 0],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareShelf(
    List<_FeedTrack> tracks, {
    bool showMixRibbon = false,
    bool compact = false,
  }) {
    return SizedBox(
      height: compact ? 216 : 232,
      child: ListView.separated(
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
                key: const ValueKey('home_genre_chip'),
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
              : SizedBox(
                  key: ValueKey(theme.label),
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final window = [
                        for (int i = 0; i < 3; i++)
                          tracks[(index + i) % tracks.length],
                      ];
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

  Widget _buildTrackRowsSection(List<_FeedTrack> tracks) {
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final window = [
            for (int i = 0; i < 3; i++) tracks[(index + i) % tracks.length],
          ];
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

  Widget _buildMadeForYou() {
    final tracks = _sectionTracks(6, 2);
    final colors = [
      (
        bg: const [Color(0xFF193D8F), Color(0xFF1F1F1F)],
        label: 'DAILY DROPS',
        description: 'New releases based on your taste. Updated every day',
      ),
      (
        bg: const [Color(0xFF7E3500), Color(0xFF1F1F1F)],
        label: 'WEEKLY WAVE',
        description: 'The best of SoundCloud just for you. Updated every Monday',
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

  @override
  Widget build(BuildContext context) {
    final recommendationTracks = _sectionTracks(0, 6);
    final mixedTracks = _sectionTracks(1, 3);
    final followLikedTracks = _sectionTracks(4, 3);
    final curatedTracks = _sectionTracks(7, 5);
    final likedByTracks = _sectionTracks(10, 4);
    final stationTracks = _sectionTracks(11, 4);
    final artistTracks = _sectionTracks(13, 5);

    return Scaffold(
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
            onPressed: () {},
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
            key: const ValueKey('home_cast_button'),
            onPressed: () {},
            icon: const Icon(Icons.cast_connected_outlined, size: 23),
          ),
          IconButton(
            key: const ValueKey('home_upload_button'),
            onPressed: () {},
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
          await Future.wait([_fetchFeed(), _fetchTrending()]);
        },
        color: const Color(0xFFFF5500),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          children: [
            _buildLikesBanner(),
            _buildSectionHeader('More of what you like', showSeeAll: true),
            _buildSquareShelf(recommendationTracks),
            const SizedBox(height: 28),
            _buildTrendingSection(),
            const SizedBox(height: 28),
            _buildSectionHeader('Mixed for $_displayName'),
            _buildSquareShelf(mixedTracks, showMixRibbon: true, compact: true),
            const SizedBox(height: 28),
            _buildSectionHeader('Liked by people you follow'),
            _buildTrackRowsSection(followLikedTracks),
            const SizedBox(height: 28),
            _buildSectionHeader('Made for you'),
            _buildMadeForYou(),
            const SizedBox(height: 28),
            _buildSectionHeader('Curated by SoundCloud'),
            _buildSquareShelf(curatedTracks, compact: true),
            const SizedBox(height: 28),
            _buildSectionHeader('Liked By'),
            _buildSquareShelf(likedByTracks, compact: true),
            const SizedBox(height: 28),
            _buildSectionHeader('Discover with Stations'),
            _buildStationShelf(stationTracks),
            const SizedBox(height: 28),
            _buildSectionHeader('New crew, suggested for you'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SuggestedRow(title: null, compact: true),
            ),
            const SizedBox(height: 28),
            _buildSectionHeader('Artists to watch out for'),
            _buildBuzzingShelf(artistTracks),
            if (_isLoading && _tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
              )
            else if (_hasError)
              const Padding(
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

  Widget _buildStationShelf(List<_FeedTrack> tracks) {
    return SizedBox(
      height: 192,
      child: ListView.separated(
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

  Widget _buildBuzzingShelf(List<_FeedTrack> tracks) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) => _BuzzingCard(
          track: tracks[index],
          accent: [
            const Color(0xFFE7D36E),
            const Color(0xFFA273F3),
            const Color(0xFFEA5B67),
          ][index % 3],
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
    return Container(
      width: 332,
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
              const SizedBox(width: 10),
              Column(
                children: [
                  for (final track in tracks.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: _NetworkArtwork(url: track.artworkUrl),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleTrackRow extends StatelessWidget {
  final _FeedTrack track;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _SimpleTrackRow({
    required this.track,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
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
                  GestureDetector(
                    onTap: () {
                      final id = track.artistId;
                      final permalink = track.artistPermalink;
                      if (id != null && permalink != null) {
                        navigateToUserProfile(
                          context,
                          userId: id,
                          permalink: permalink,
                          displayName: track.artistName,
                        );
                      }
                    },
                    child: Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9F9F9F),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onMore,
              child: const Icon(
                Icons.more_vert,
                color: Color(0xFFA1A1A1),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizontalTrackCard extends StatelessWidget {
  final _FeedTrack track;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _HorizontalTrackCard({
    required this.track,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 248,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2F2F2F)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 58,
                child: _NetworkArtwork(url: track.artworkUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFA9A9A9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onMore,
              child: const Icon(
                Icons.more_vert,
                color: Color(0xFFA1A1A1),
                size: 20,
              ),
            ),
          ],
        ),
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
    return Container(
      width: 332,
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
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2),
                  radius: 0.92,
                  colors: [
                    const Color(0x332F4FFF),
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
                                        Flexible(
                                          child: Text(
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
                                        const CircleAvatar(
                                          radius: 8,
                                          backgroundColor: Color(0xFF515151),
                                          child: Icon(
                                            Icons.person,
                                            size: 10,
                                            color: Colors.white70,
                                          ),
                                        ),
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
              const SizedBox(width: 10),
              Column(
                children: [
                  for (final track in tracks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: _NetworkArtwork(url: track.artworkUrl),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
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
  final _FeedTrack track;
  final Color accent;
  final VoidCallback onTap;

  const _BuzzingCard({
    required this.track,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BuzzingPainter(accent: accent),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Text(
                      'BUZZING',
                      style: TextStyle(
                        color: accent,
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
                        child: _NetworkArtwork(url: track.artworkUrl),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buzzing ${track.artistName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    if (url == null || url!.isEmpty) {
      return const _ArtworkPlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
    );
  }
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
      color: const Color(0xFF2D2D2D),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 28),
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
        Rect.fromLTWH((i.isEven ? 0 : 10), top, 12, 6),
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
