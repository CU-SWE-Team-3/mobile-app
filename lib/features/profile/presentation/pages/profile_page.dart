import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/library/presentation/pages/your_insights_page.dart';
import 'package:soundcloud_clone/features/player/domain/entities/player_track.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

// ── API track model ───────────────────────────────────────────────────────────

class _ApiTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final String hlsUrl;
  final List<int>? waveform;
  final int? durationSeconds;

  const _ApiTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artworkUrl,
    required this.hlsUrl,
    this.waveform,
    this.durationSeconds,
  });

  factory _ApiTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final dur = json['duration'];
    return _ApiTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String? ?? '',
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      durationSeconds: dur != null ? (dur as num).toInt() : null,
    );
  }

  String get durationLabel {
    if (durationSeconds == null) return '';
    final m = durationSeconds! ~/ 60;
    final s = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: id,
        title: title,
        artist: artistName,
        audioUrl: hlsUrl,
        coverUrl: artworkUrl,
        waveform: waveform,
        duration:
            durationSeconds != null ? Duration(seconds: durationSeconds!) : null,
      );
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // ── profile data ─────────────────────────────────────────────────────
  String _username = '';
  String _bio = '';
  String _city = '';
  String _country = '';
  String _avatarUrl = '';
  int _followerCount = 5;
  int _followingCount = 0;
  bool _bioExpanded = false;
  bool _isLoading = true;
  bool _hasError = false;

  List<_ApiTrack> _apiTracks = [];
  bool _tracksLoading = false;

  final _likes = const [
    _Track('🕊♡without a trace @@2rel', 'Alis', '2:12',
        likeColor: Colors.purple),
    _Track('Girls Like You - Maroon 5 ft. ...', 'Hiderway', '4:57',
        likeColor: Colors.red),
  ];

  final _playlists = const [_Playlist('my songs', 'SUNDER')];

  final _reposts = const [
    _Repost('Nasser _ ناصر', 'wigexpress', '1M', '2:52', Color(0xFF1A1A2E)),
    _Repost('ZIAD ZAZA - SAM3 AKHINA | ... زياد', 'Abouelhassan', '1.7M',
        '2:13', Color(0xFFB03A2E)),
    _Repost('ZIAD ZAZA - EMSHI | زياد ظاظا - إمشي', 'Maro mafia', '2.3M',
        '3:40', Color(0xFF1F618D)),
  ];

  // ── colors ───────────────────────────────────────────────────────────
  static const _bg = Color(0xFF111111);
  static const _surface = Color(0xFF1E1E1E);
  static const _orange = Color(0xFFFF5500);
  static final _sub = Colors.white.withOpacity(0.55);

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchTracks();
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final String userId = prefs.getString('userId') ?? '';
      final String permalink = prefs.getString('permalink') ?? '';

      if (userId.isEmpty) {
        if (mounted) setState(() { _username = prefs.getString('displayName') ?? ''; _isLoading = false; });
        return;
      }

      // If we have a permalink, fetch full profile (includes followerCount + followingCount)
      if (permalink.isNotEmpty) {
        try {
          final profileResponse = await dioClient.dio.get('/profile/$permalink');
          final data = profileResponse.data['data']['user'] as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _username       = data['displayName']   as String? ?? prefs.getString('displayName') ?? '';
              _bio            = data['bio']           as String? ?? '';
              _city           = data['city']          as String? ?? '';
              _country        = data['country']       as String? ?? '';
              _avatarUrl      = data['avatarUrl']     as String? ?? '';
              _followerCount  = _parseInt(data['followerCount']);
              _followingCount = _parseInt(data['followingCount']);
              _isLoading = false;
            });
          }
          return;
        } catch (e) {
          // ignore: avoid_print
          print('=== PROFILE PERMALINK FETCH ERROR: $e');
        }
      }

      // No permalink yet — fetch counts separately
      final results = await Future.wait([
        dioClient.dio.get('/network/$userId/followers'),
        dioClient.dio.get('/network/$userId/following'),
      ]);
      if (mounted) {
        setState(() {
          _username       = prefs.getString('displayName') ?? '';
          _bio            = prefs.getString('bio') ?? '';
          _country        = prefs.getString('country') ?? '';
          _city           = prefs.getString('city') ?? '';
          _followerCount  = _parseInt(results[0].data['count']);
          _followingCount = _parseInt(results[1].data['count']);
          _isLoading = false;
        });
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('=== PROFILE FETCH ERROR: $e\n$st');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _fetchTracks() async {
    setState(() => _tracksLoading = true);
    try {
      final response = await dioClient.dio.get('/tracks/my-tracks');
      final data = response.data['data'] as List<dynamic>;
      final tracks = data
          .cast<Map<String, dynamic>>()
          .map(_ApiTrack.fromJson)
          .where((t) => t.hlsUrl.isNotEmpty)
          .toList();
      if (mounted) setState(() { _apiTracks = tracks; _tracksLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _tracksLoading = false);
    }
  }

  void _playFrom(int index) {
    if (_apiTracks.isEmpty) return;
    final queue = _apiTracks.map((t) => t.toPlayerTrack()).toList();
    ref.read(playerProvider.notifier).playQueue(queue, startIndex: index);
  }

  // ── navigate to edit, then re-fetch to show latest data ─────────────
  Future<void> _openEdit() async {
    final result = await context.push<Map<String, String>>('/profile/edit', extra: {
      'displayName': _username,
      'bio': _bio,
      'country': _country,
      'city': _city,
      'avatarUrl': _avatarUrl,
      'coverUrl': '',
    });
    if (!mounted) return;
    // Optimistically update UI with saved values before the re-fetch completes
    if (result != null) {
      setState(() {
        _username = result['displayName'] ?? _username;
        _bio      = result['bio']         ?? _bio;
        _city     = result['city']        ?? _city;
        _country  = result['country']     ?? _country;
      });
    }
    if (mounted) _fetchProfile();
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
              )
            else if (_hasError)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Couldn\'t load profile',
                          style: TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _fetchProfile,
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFFFF5500))),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchProfile,
                  color: const Color(0xFFFF5500),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heroSection(context),
                        _bioSection(),
                        _insightsRow(context),
                        _spotlight(),
                        _sectionHeader('Tracks',
                            onSeeAll: () => context.push('/profile/tracks')),
                        if (_tracksLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFFFF5500))),
                          )
                        else
                          ..._apiTracks.take(2).toList().asMap().entries.map(
                                (e) => _TrackTile(
                                  track: _Track(e.value.title,
                                      e.value.artistName, e.value.durationLabel),
                                  artworkUrl: e.value.artworkUrl,
                                  onTap: () => _playFrom(e.key),
                                  onMore: () {},
                                ),
                              ),
                        _sectionHeader('Reposts',
                            onSeeAll: () => context.push('/profile/reposts')),
                        _repostsList(),
                        _sectionHeader('Playlists'),
                        _playlistRow(context),
                        _sectionHeader('Likes', onSeeAll: () {}),
                        ..._likes.map((t) => _TrackTile(
                              track: t,
                              onTap: () {},
                              onMore: () {},
                              showHeart: true,
                            )),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── top bar ──────────────────────────────────────────────────────────
  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _iconBtn(Icons.arrow_back_ios_new_rounded,
                () => context.canPop() ? context.pop() : null),
            const Spacer(),
            _iconBtn(Icons.cast_rounded, () {}),
            const SizedBox(width: 8),
            _iconBtn(Icons.more_vert_rounded, () {}),
          ],
        ),
      );

  // ── hero ─────────────────────────────────────────────────────────────
  Widget _heroSection(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar — tap to view fullscreen
            GestureDetector(
              onTap: () => context.push('/profile/avatar-view'),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _orange, width: 2.5),
                ),
                child: ClipOval(
                  child: _avatarUrl.isNotEmpty &&
                          !_avatarUrl.contains('default-avatar')
                      ? CachedNetworkImage(
                          imageUrl: _avatarUrl,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const _AvatarFallback(),
                        )
                      : const _AvatarFallback(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Username
            Text(
              _username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            // City / Country subtitle
            if (_city.isNotEmpty || _country.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  [_city, _country].where((s) => s.isNotEmpty).join(', '),
                  style: TextStyle(color: _sub, fontSize: 13),
                ),
              ),
            // Follower / Following
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/followers'),
                  child: Text(
                      '$_followerCount ${_followerCount == 1 ? 'Follower' : 'Followers'}',
                      style: TextStyle(color: _sub, fontSize: 13)),
                ),
                Text('  ·  ', style: TextStyle(color: _sub, fontSize: 13)),
                GestureDetector(
                  onTap: () => context.push('/profile/following'),
                  child: Text('$_followingCount Following',
                      style: TextStyle(color: _sub, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action row
            Row(
              children: [
                // Edit button → pushes EditProfilePage, awaits result
                GestureDetector(
                  onTap: _openEdit,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Edit',
                            style:
                                TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _iconCircle(Icons.shuffle_rounded, () {
                  if (_apiTracks.isEmpty) return;
                  _playFrom(Random().nextInt(_apiTracks.length));
                }),
                const SizedBox(width: 12),
                _playCircle(context),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      );

  // ── bio ──────────────────────────────────────────────────────────────
  Widget _bioSection() {
    if (_bio.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Text('No bio yet',
            style: TextStyle(
                color: _sub.withValues(alpha: 0.5),
                fontSize: 14,
                fontStyle: FontStyle.italic)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bio,
            maxLines: _bioExpanded ? null : 2,
            overflow: _bioExpanded ? null : TextOverflow.ellipsis,
            style: TextStyle(color: _sub, fontSize: 14, height: 1.5),
          ),
          if (_bio.length > 60)
            GestureDetector(
              onTap: () => setState(() => _bioExpanded = !_bioExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_bioExpanded ? 'Show less' : 'Show more',
                    style: TextStyle(
                        color: Colors.blue[400],
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
  }

  // ── insights → navigates to YourInsightsPage ────────────────────────
  Widget _insightsRow(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const YourInsightsPage())),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Text('Your insights',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: _sub, size: 20),
            ],
          ),
        ),
      );

  // ── spotlight ────────────────────────────────────────────────────────
  Widget _spotlight() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Pinned to Spotlight',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Edit',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Pin items to your Spotlight',
                style: TextStyle(color: _sub, fontSize: 13)),
          ],
        ),
      );

  // ── section header ───────────────────────────────────────────────────
  Widget _sectionHeader(String title, {VoidCallback? onSeeAll}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: _surface, borderRadius: BorderRadius.circular(20)),
                  child: const Text('See All',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
          ],
        ),
      );

  // ── reposts list ─────────────────────────────────────────────────────
  Widget _repostsList() => Column(
        children: _reposts.take(3).map((r) {
          final sub = Colors.white.withOpacity(0.55);
          return GestureDetector(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: r.imageColor,
                      child: const Icon(Icons.music_note,
                          color: Colors.white38, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(r.artist,
                            style: TextStyle(color: sub, fontSize: 13)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                size: 13, color: sub),
                            Text('  ${r.plays} · ${r.duration}',
                                style: TextStyle(color: sub, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Icon(Icons.more_vert_rounded, color: sub, size: 20),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );

  // ── playlist row ─────────────────────────────────────────────────────
  Widget _playlistRow(BuildContext context) => SizedBox(
        height: 215,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _playlists.length,
          itemBuilder: (_, i) {
            final p = _playlists[i];
            return GestureDetector(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 150,
                          height: 150,
                          color: Colors.grey[850],
                          child: const Icon(Icons.queue_music,
                              size: 52, color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.owner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

  // ── helpers ──────────────────────────────────────────────────────────
  Widget _iconBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Widget _iconCircle(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  Widget _playCircle(BuildContext context) => GestureDetector(
        onTap: () => _playFrom(0),
        child: Container(
          width: 52,
          height: 52,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.black, size: 28),
        ),
      );
}

// ── avatar fallback ───────────────────────────────────────────────────────
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.person, size: 48, color: Colors.white38),
    );
  }
}

// ── data models ──────────────────────────────────────────────────────────
class _Track {
  final String title;
  final String artist;
  final String duration;
  final Color? likeColor;
  const _Track(this.title, this.artist, this.duration, {this.likeColor});
}

class _Playlist {
  final String name;
  final String owner;
  const _Playlist(this.name, this.owner);
}

class _Repost {
  final String title;
  final String artist;
  final String plays;
  final String duration;
  final Color imageColor;
  const _Repost(
      this.title, this.artist, this.plays, this.duration, this.imageColor);
}

// ── track tile ───────────────────────────────────────────────────────────
class _TrackTile extends StatelessWidget {
  final _Track track;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final bool showHeart;
  final String? artworkUrl;

  const _TrackTile({
    required this.track,
    required this.onTap,
    required this.onMore,
    this.showHeart = false,
    this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withOpacity(0.55);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (artworkUrl != null && artworkUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: artworkUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: track.likeColor ?? const Color(0xFF2A2A2A),
                        child: const Icon(Icons.music_note,
                            color: Colors.white38, size: 24),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: track.likeColor ?? const Color(0xFF2A2A2A),
                      child: const Icon(Icons.music_note,
                          color: Colors.white38, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(track.artist,
                      style: TextStyle(color: sub, fontSize: 12)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 13, color: sub),
                      Text('  ${track.duration}',
                          style: TextStyle(color: sub, fontSize: 11)),
                      if (showHeart) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.favorite,
                            size: 13, color: Colors.redAccent),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onMore,
              child: Icon(Icons.more_vert_rounded, color: sub, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
