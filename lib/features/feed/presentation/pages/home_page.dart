import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/utils/profile_navigation.dart';
import 'package:soundcloud_clone/features/followers/presentation/widgets/suggested_row.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/notifications/presentation/providers/notification_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

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

  _FeedTrack({
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
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    return _FeedTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artistId: artist['_id'] as String?,
      artistPermalink: artist['permalink'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String? ?? '',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isReposted: json['isReposted'] as bool? ?? false,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // ── Static placeholder data ────────────────────────────────────────────────

  static const List<String> _genres = [
    'Electronic', 'Folk', 'House', 'Techno', 'Pop',
    'Hip-Hop', 'Jazz', 'Classical', 'R&B', 'Metal',
  ];

  static const List<Map<String, String>> _moreOfWhatYouLike = [
    {'title': 'Chill Vibes Mix', 'artist': 'SoundCloud'},
    {'title': 'Electronic Essentials', 'artist': 'Various Artists'},
    {'title': 'Late Night Lo-Fi', 'artist': 'Lo-Fi Beats'},
    {'title': 'Hip-Hop Hits', 'artist': 'Top Artists'},
    {'title': 'Indie Gems', 'artist': 'Curated'},
  ];

  static const List<Map<String, String>> _mixedForYou = [
    {'title': 'Your Morning Mix', 'artist': 'Mixed for you'},
    {'title': 'Afternoon Grooves', 'artist': 'Mixed for you'},
    {'title': 'Evening Unwind', 'artist': 'Mixed for you'},
    {'title': 'Workout Boosters', 'artist': 'Mixed for you'},
  ];

  static const List<Map<String, String>> _curatedItems = [
    {'title': 'SoundCloud Weekly', 'subtitle': 'Fresh picks every week'},
    {'title': 'Rising Stars', 'subtitle': 'New artists to watch'},
    {'title': 'Throwback Classics', 'subtitle': 'Timeless tracks'},
    {'title': 'Trending Now', 'subtitle': "What everyone's listening to"},
  ];

  static const List<Map<String, String>> _stationItems = [
    {'artist': 'The Weeknd', 'subtitle': 'Based on The Weeknd'},
    {'artist': 'Drake', 'subtitle': 'Based on Drake'},
    {'artist': 'Billie Eilish', 'subtitle': 'Based on Billie Eilish'},
    {'artist': 'Kendrick Lamar', 'subtitle': 'Based on Kendrick Lamar'},
  ];

  // ── State ──────────────────────────────────────────────────────────────────

  int _selectedGenreIndex = 0;
  List<_FeedTrack> _tracks = [];
  List<_FeedTrack> _likedTracks = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _displayName = 'you';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSuggestedDialog();
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('displayName') ??
        prefs.getString('username') ??
        prefs.getString('name') ??
        'you';
    if (mounted) setState(() => _displayName = name);
  }

  Future<void> _maybeShowSuggestedDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('suggested_dialog_shown') ?? false;
    if (alreadyShown || !mounted) return;
    await prefs.setBool('suggested_dialog_shown', true);
    if (mounted) _showSuggestedDialog(context);
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final response = await dioClient.dio.get('/network/feed');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      var tracks = data
          .map((e) => _FeedTrack.fromJson(e as Map<String, dynamic>))
          .toList();

      Set<String> likedIds = {};
      Set<String> repostedIds = {};
      final List<_FeedTrack> tempLikedTracks = [];

      if (userId.isNotEmpty) {
        await Future.wait([
          dioClient.dio.get('/profile/$userId/likes').then((r) {
            final d = r.data['data'] as Map<String, dynamic>? ?? {};
            final raw = d['likedTracks'] as List<dynamic>? ?? [];
            for (final item in raw) {
              final trackMap =
                  (item as Map<String, dynamic>)['track'] as Map<String, dynamic>?;
              if (trackMap != null) {
                final trackId = trackMap['_id'] as String?;
                if (trackId != null && trackId.isNotEmpty) {
                  likedIds.add(trackId);
                  if (tempLikedTracks.length < 4) {
                    try {
                      tempLikedTracks.add(_FeedTrack.fromJson(trackMap));
                    } catch (_) {}
                  }
                }
              }
            }
          }).catchError((_) {}),
          dioClient.dio.get('/profile/$userId/reposts').then((r) {
            final d = r.data['data'] as Map<String, dynamic>? ?? {};
            final raw = d['repostedTracks'] as List<dynamic>? ?? [];
            for (final item in raw) {
              final trackId =
                  ((item as Map<String, dynamic>)['track']
                          as Map<String, dynamic>?)?['_id'] as String?;
              if (trackId != null && trackId.isNotEmpty) {
                repostedIds.add(trackId);
              }
            }
          }).catchError((_) {}),
        ]);
      }

      tracks = tracks
          .map((t) => _FeedTrack(
                id: t.id,
                title: t.title,
                artistName: t.artistName,
                artworkUrl: t.artworkUrl,
                hlsUrl: t.hlsUrl,
                playCount: t.playCount,
                artistId: t.artistId,
                artistPermalink: t.artistPermalink,
                isLiked: likedIds.contains(t.id),
                isReposted: repostedIds.contains(t.id),
                likeCount:
                    likedIds.contains(t.id) ? max(t.likeCount, 1) : t.likeCount,
                repostCount: repostedIds.contains(t.id)
                    ? max(t.repostCount, 1)
                    : t.repostCount,
                waveform: t.waveform,
              ))
          .toList();

      if (mounted) {
        for (final track in tracks) {
          if (track.id.isEmpty) continue;
          ref
              .read(engagementProvider(EngagementParams(trackId: track.id))
                  .notifier)
              .seed(
                isLiked: track.isLiked,
                isReposted: track.isReposted,
                likeCount: track.likeCount,
                repostCount: track.repostCount,
              );
        }
        setState(() {
          _tracks = tracks;
          _likedTracks = tempLikedTracks;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _showSuggestedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'People you might like',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('home_suggested_close_button'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF999999)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SuggestedRow(title: null),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section builders ───────────────────────────────────────────────────────

  // 1 — Your likes banner
  Widget _buildYourLikesBanner() {
    return GestureDetector(
      onTap: () => context.push('/likes'),
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C0A0A), Color(0xFFB31A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your likes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/likes'),
                  icon: const Icon(Icons.shuffle, color: Colors.white, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (_likedTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: _buildLikedTracksGrid(),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildLikedTracksGrid() {
    final items = _likedTracks.take(4).toList();
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(Row(
        children: [
          Expanded(child: _buildLikedTrackTile(items[i])),
          const SizedBox(width: 10),
          Expanded(
            child: i + 1 < items.length
                ? _buildLikedTrackTile(items[i + 1])
                : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _buildLikedTrackTile(_FeedTrack track) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 44,
            height: 44,
            child: track.artworkUrl != null && track.artworkUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: track.artworkUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
                  )
                : const _ArtworkPlaceholder(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                track.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Section header widget
  Widget _buildSectionHeader(String title, {bool showSeeAll = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (showSeeAll)
            const Text(
              'See all',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
        ],
      ),
    );
  }

  // 2+3 — Horizontal album card rows (shared for "More of what you like" and "Mixed for")
  Widget _buildHorizontalAlbumCards(List<Map<String, String>> items) {
    const gradients = <List<Color>>[
      [Color(0xFF1A3A5C), Color(0xFF1E90FF)],
      [Color(0xFF2D0F4F), Color(0xFF9333EA)],
      [Color(0xFF0A3826), Color(0xFF10B981)],
      [Color(0xFF5C1A00), Color(0xFFEA580C)],
      [Color(0xFF1E1B4B), Color(0xFF6366F1)],
    ];
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final colors = gradients[i % gradients.length];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note, color: Colors.white24, size: 48),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['title']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item['artist']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 4 — Trending by genre (real feed data, first 5 tracks)
  Widget _buildTrendingByGenre() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Trending by genre'),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _genres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final isSelected = _selectedGenreIndex == i;
              return GestureDetector(
                key: const ValueKey('home_genre_chip'),
                onTap: () => setState(() => _selectedGenreIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF5500)
                          : Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _genres[i],
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFFF5500) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            ),
          )
        else if (_hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  const Text(
                    "Couldn't load feed",
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    key: const ValueKey('home_retry_button'),
                    onPressed: _fetchFeed,
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Color(0xFFFF5500), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_tracks.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'Follow some artists to see their tracks here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
          )
        else
          ...(_tracks.take(5).toList().asMap().entries.map(
                (e) => _SimpleTrackRow(
                  track: e.value,
                  allTracks: _tracks,
                  index: e.key,
                ),
              )),
      ],
    );
  }

  // 5 — Made for you (two tall cards)
  Widget _buildMadeForYou() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildMadeForYouCard(
              'DAILY\nDROPS',
              'Fresh picks, every day',
              const [Color(0xFF0F2A5C), Color(0xFF1565C0), Color(0xFF1E90FF)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMadeForYouCard(
              'WEEKLY\nWAVE',
              'New music, every week',
              const [Color(0xFF3B0764), Color(0xFF7E22CE), Color(0xFFA855F7)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMadeForYouCard(
    String label,
    String description,
    List<Color> colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.equalizer_rounded,
                  color: Colors.white.withValues(alpha: 0.12),
                  size: 80,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
          maxLines: 2,
        ),
      ],
    );
  }

  // 6 — Liked by people you follow (real feed data, tracks 5+)
  Widget _buildLikedByFollowSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5500))),
      );
    }
    if (_hasError || _tracks.length <= 5) return const SizedBox.shrink();
    final tracks = _tracks.skip(5).toList();
    return Column(
      children: tracks.asMap().entries.map(
        (e) => _SimpleTrackRow(
          track: e.value,
          allTracks: _tracks,
          index: e.key + 5,
        ),
      ).toList(),
    );
  }

  // 7 — Curated by SoundCloud (placeholder)
  Widget _buildCuratedBySoundCloud() {
    const colors = <List<Color>>[
      [Color(0xFF0F4C81), Color(0xFF1E90FF)],
      [Color(0xFF2D1B69), Color(0xFF7B2FBE)],
      [Color(0xFF1A5F3F), Color(0xFF34D399)],
      [Color(0xFF7F1D1D), Color(0xFFEF4444)],
    ];
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _curatedItems.length,
        itemBuilder: (_, i) {
          final item = _curatedItems[i];
          final colorPair = colors[i % colors.length];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colorPair,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.headphones_rounded,
                      color: Colors.white24,
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['title']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item['subtitle']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 8 — Discover with Stations (placeholder)
  Widget _buildDiscoverWithStations() {
    const bgColors = <Color>[
      Color(0xFF1B4332),
      Color(0xFF1E3A5F),
      Color(0xFF3B1A4A),
      Color(0xFF4A1614),
    ];
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stationItems.length,
        itemBuilder: (_, i) {
          final station = _stationItems[i];
          final bgColor = bgColors[i % bgColors.length];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      // Vinyl ring
                      Center(
                        child: Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white10, width: 18),
                            color: Colors.black38,
                          ),
                        ),
                      ),
                      // Artist circle
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white12,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white38,
                            size: 34,
                          ),
                        ),
                      ),
                      // Label overlay
                      Positioned(
                        bottom: 8,
                        left: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STATION',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 9,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              station['artist']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  station['subtitle']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('home_get_pro_button'),
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'GET PRO',
              style: TextStyle(
                color: Color(0xFFFF5500),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('home_cast_button'),
            onPressed: () {},
            icon: const Icon(Icons.cast, color: Colors.white, size: 22),
          ),
          IconButton(
            key: const ValueKey('home_upload_button'),
            onPressed: () {},
            icon: const Icon(Icons.upload_rounded, color: Colors.white, size: 22),
          ),
          IconButton(
            key: const ValueKey('home_messages_button'),
            onPressed: () {},
            icon: const Icon(Icons.mail_outline, color: Colors.white, size: 22),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                key: const ValueKey('home_notifications_button'),
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_none, color: Colors.white, size: 22),
              ),
              Builder(builder: (ctx) {
                final unread = ref.watch(notificationProvider).unreadCount;
                if (unread == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 6,
                  right: 6,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5500),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFeed,
        color: const Color(0xFFFF5500),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.only(top: 24, bottom: 100),
          children: [
            // 1 — Your likes
            _buildYourLikesBanner(),

            // 2 — More of what you like
            _buildSectionHeader('More of what you like', showSeeAll: true),
            _buildHorizontalAlbumCards(_moreOfWhatYouLike),
            const SizedBox(height: 32),

            // 3 — Mixed for [username]
            _buildSectionHeader('Mixed for $_displayName'),
            _buildHorizontalAlbumCards(_mixedForYou),
            const SizedBox(height: 32),

            // 4 — Trending by genre
            _buildTrendingByGenre(),
            const SizedBox(height: 32),

            // 5 — Made for you
            _buildSectionHeader('Made for you'),
            _buildMadeForYou(),
            const SizedBox(height: 32),

            // 6 — Liked by people you follow
            _buildSectionHeader('Liked by people you follow'),
            _buildLikedByFollowSection(),
            const SizedBox(height: 32),

            // 7 — Curated by SoundCloud
            _buildSectionHeader('Curated by SoundCloud'),
            _buildCuratedBySoundCloud(),
            const SizedBox(height: 32),

            // 8 — Discover with Stations
            _buildSectionHeader('Discover with Stations'),
            _buildDiscoverWithStations(),
            const SizedBox(height: 32),

            // 9 — New crew, suggested for you
            _buildSectionHeader('New crew, suggested for you'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SuggestedRow(title: null),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Simple track row (artwork + title + artist + 3-dot) ───────────────────────

class _SimpleTrackRow extends ConsumerWidget {
  final _FeedTrack track;
  final List<_FeedTrack> allTracks;
  final int index;

  const _SimpleTrackRow({
    required this.track,
    required this.allTracks,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: const ValueKey('home_track_row'),
      onTap: () {
        if (track.hlsUrl.isEmpty) return;
        final queue = allTracks
            .where((t) => t.hlsUrl.isNotEmpty)
            .map((t) => PlayerTrack(
                  id: t.id,
                  title: t.title,
                  artist: t.artistName,
                  artistId: t.artistId,
                  artistPermalink: t.artistPermalink,
                  audioUrl: t.hlsUrl,
                  coverUrl: t.artworkUrl,
                  waveform: t.waveform,
                ))
            .toList();
        final startIndex = allTracks
            .where((t) => t.hlsUrl.isNotEmpty)
            .toList()
            .indexWhere((t) => t.id == track.id);
        ref.read(playerProvider.notifier).playQueue(
              queue,
              startIndex: startIndex < 0 ? 0 : startIndex,
            );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 0, 16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: track.artworkUrl != null && track.artworkUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: track.artworkUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
                      )
                    : const _ArtworkPlaceholder(),
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
                      fontWeight: FontWeight.bold,
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
                        color: Color(0xFF999999),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('home_track_more_button'),
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1A1A1A),
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => _TrackMenuSheet(track: track),
              ),
              icon: const Icon(
                Icons.more_vert,
                color: Color(0xFF999999),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Track menu sheet ──────────────────────────────────────────────────────────

class _TrackMenuSheet extends ConsumerWidget {
  final _FeedTrack track;

  const _TrackMenuSheet({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engagement = ref.watch(
      engagementProvider(EngagementParams(trackId: track.id)),
    );
    final isLiked = engagement.isLiked;
    final isReposted = engagement.isReposted;

    final playerTrack = PlayerTrack(
      id: track.id,
      title: track.title,
      artist: track.artistName,
      artistId: track.artistId,
      artistPermalink: track.artistPermalink,
      audioUrl: track.hlsUrl,
      coverUrl: track.artworkUrl,
      waveform: track.waveform,
    );

    void comingSoon() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coming soon'),
          backgroundColor: Color(0xFF333333),
          duration: Duration(seconds: 2),
        ),
      );
    }

    void copyLink() {
      final url = track.artistPermalink != null
          ? 'https://soundcloud.com/${track.artistPermalink}/${track.id}'
          : 'https://soundcloud.com/tracks/${track.id}';
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied'),
          backgroundColor: Color(0xFF333333),
          duration: Duration(seconds: 2),
        ),
      );
    }

    void playNext() {
      final state = ref.read(playerProvider);
      ref.read(playerProvider.notifier).addToQueue(playerTrack);
      if (state.queue.isNotEmpty) {
        final oldIndex = state.queue.length;
        final insertAt = (state.currentQueueIndex + 1).clamp(0, oldIndex);
        if (insertAt < oldIndex) {
          ref.read(playerProvider.notifier).reorderQueue(oldIndex, insertAt);
        }
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to play next'),
          backgroundColor: Color(0xFF333333),
          duration: Duration(seconds: 2),
        ),
      );
    }

    void playLast() {
      ref.read(playerProvider.notifier).addToQueue(playerTrack);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to end of queue'),
          backgroundColor: Color(0xFF333333),
          duration: Duration(seconds: 2),
        ),
      );
    }

    void goToArtist() {
      if (track.artistId == null || track.artistPermalink == null) {
        comingSoon();
        return;
      }
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push(
        '/user/${track.artistPermalink}',
        extra: {
          'displayName': track.artistName,
          'userId': track.artistId,
        },
      );
    }

    void viewComments() {
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push(
        '/comments',
        extra: {
          'trackId': track.id,
          'trackTitle': track.title,
          'trackArtist': track.artistName,
          'trackArtworkUrl': track.artworkUrl,
          'currentPositionSeconds': 0,
        },
      );
    }

    void viewLikers() {
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push('/likers', extra: {'trackId': track.id});
    }

    void viewReposters() {
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push('/reposters', extra: {'trackId': track.id});
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: track.artworkUrl != null &&
                            track.artworkUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: track.artworkUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const _ArtworkPlaceholder(),
                          )
                        : const _ArtworkPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _ShareIconButton(
                  icon: Icons.message,
                  label: 'Message',
                  onTap: comingSoon,
                ),
                _ShareIconButton(
                  icon: Icons.link,
                  label: 'Copy Link',
                  onTap: copyLink,
                ),
                _ShareIconButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'WhatsApp',
                  onTap: comingSoon,
                ),
                _ShareIconButton(
                  icon: Icons.radio_button_unchecked,
                  label: 'Status',
                  onTap: comingSoon,
                ),
                _ShareIconButton(
                  icon: Icons.sms,
                  label: 'SMS',
                  onTap: comingSoon,
                ),
                _ShareIconButton(
                  icon: Icons.auto_stories,
                  label: 'Stories',
                  onTap: comingSoon,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          _MenuTile(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            iconColor: isLiked ? const Color(0xFFFF5500) : Colors.white,
            label: isLiked ? 'Unlike' : 'Like',
            onTap: () => ref
                .read(
                    engagementProvider(EngagementParams(trackId: track.id))
                        .notifier)
                .toggleLike(),
          ),
          _MenuTile(
            icon: Icons.skip_next,
            label: 'Play Next',
            onTap: playNext,
          ),
          _MenuTile(
            icon: Icons.queue_music,
            label: 'Play Last',
            onTap: playLast,
          ),
          _MenuTile(
            icon: Icons.playlist_add,
            label: 'Add to playlist',
            onTap: comingSoon,
          ),
          _MenuTile(
            icon: Icons.radio,
            label: 'Start station',
            onTap: comingSoon,
          ),
          _MenuTile(
            icon: Icons.person_outline,
            label: 'Go to artist profile',
            onTap: goToArtist,
          ),
          _MenuTile(
            icon: Icons.chat_bubble_outline,
            label: 'View comments',
            onTap: viewComments,
          ),
          _MenuTile(
            icon: Icons.repeat,
            iconColor: isReposted ? const Color(0xFFFF5500) : Colors.white,
            label: 'Repost on SoundCloud',
            onTap: () => ref
                .read(
                    engagementProvider(EngagementParams(trackId: track.id))
                        .notifier)
                .toggleRepost(),
          ),
          _MenuTile(
            icon: Icons.favorite_border,
            label: 'Who liked this',
            onTap: viewLikers,
          ),
          _MenuTile(
            icon: Icons.repeat,
            label: 'Who reposted this',
            onTap: viewReposters,
          ),
          _MenuTile(
            icon: Icons.info_outline,
            label: 'Behind this track',
            onTap: comingSoon,
          ),
          _MenuTile(
            icon: Icons.flag,
            label: 'Report',
            onTap: comingSoon,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 78),
        ],
      ),
    );
  }
}

class _ShareIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A2A),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Artwork placeholder ───────────────────────────────────────────────────────

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2A2A2A),
      child: Center(
        child: Icon(Icons.music_note, color: Color(0xFF666666), size: 28),
      ),
    );
  }
}
