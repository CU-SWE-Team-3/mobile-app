import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/library/domain/entities/upload_track.dart';
import 'package:soundcloud_clone/features/playlist/presentation/providers/playlists_provider.dart';
import 'package:soundcloud_clone/features/library/presentation/pages/your_insights_page.dart';
import 'package:soundcloud_clone/features/library/presentation/providers/my_tracks_provider.dart';
import 'package:soundcloud_clone/features/playlist/domain/entities/playlist.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/widgets/mini_player_widget.dart';
import 'package:soundcloud_clone/features/premium/presentation/providers/subscription_provider.dart';
import 'package:soundcloud_clone/injection_container.dart';

// ── API track model ───────────────────────────────────────────────────────────

class _ApiTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
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
    this.artistId,
    this.artistPermalink,
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
      artistId: artist['_id'] as String?,
      artistPermalink: artist['permalink'] as String?,
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
        duration: durationSeconds != null
            ? Duration(seconds: durationSeconds!)
            : null,
        artistId: artistId,
        artistPermalink: artistPermalink,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

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
  int _followerCount = 0;
  int _followingCount = 0;
  bool _bioExpanded = false;
  bool _isLoading = true;
  bool _hasError = false;

  List<UploadTrack> _cachedTracks = [];
  List<String> _pinnedTrackIds = [];

  List<_ProfilePlaylist> _playlists = [];
  bool _playlistsLoading = false;

  List<TrackSummary> _reposts = [];
  List<TrackSummary> _likes = [];

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
    _loadAll();
  }

  // Runs all profile fetches sequentially to avoid hammering the API
  Future<void> _loadAll() async {
    await _fetchProfile();
    _loadPinnedTracks();
    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchReposts();
    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchLikes();
    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchPlaylists();
  }

  Future<void> _loadPinnedTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('spotlight_pinned_ids') ?? [];
    if (mounted) setState(() => _pinnedTrackIds = ids);
  }

  Future<void> _savePinnedTracks(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('spotlight_pinned_ids', ids);
    if (mounted) setState(() => _pinnedTrackIds = ids);
  }

  void _playFrom(int index) {
    final playable = _cachedTracks
        .where((t) => t.hlsUrl != null && t.hlsUrl!.isNotEmpty)
        .toList();
    if (playable.isEmpty) return;
    final queue = playable
        .map((t) => PlayerTrack(
              id: t.id ?? t.hlsUrl!,
              title: t.title,
              artist: t.artist,
              audioUrl: t.hlsUrl!,
              coverUrl: t.artworkUrl,
              waveform: t.waveform,
            ))
        .toList();
    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: index.clamp(0, queue.length - 1),
        );
  }

  void _playFromReposts(int index) {
    final playable = _reposts
        .where((t) => t.audioUrl != null && t.audioUrl!.isNotEmpty)
        .toList();
    if (playable.isEmpty) return;
    final queue = playable
        .map((t) => PlayerTrack(
              id: t.id,
              title: t.title,
              artist: t.artistName,
              artistId: t.artistId,
              artistPermalink: t.artistPermalink,
              audioUrl: t.audioUrl!,
              coverUrl: t.artworkUrl,
              waveform: t.waveform,
            ))
        .toList();
    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: index.clamp(0, queue.length - 1),
        );
  }

  void _playFromLikes(int index) {
    final mergedLikes = ref
        .read(mergedUserLikesProvider)
        .maybeWhen(data: (tracks) => tracks, orElse: () => _likes);
    final playable = mergedLikes
        .where((t) => t.audioUrl != null && t.audioUrl!.isNotEmpty)
        .toList();
    if (playable.isEmpty) return;
    final queue = playable
        .map((t) => PlayerTrack(
              id: t.id,
              title: t.title,
              artist: t.artistName,
              artistId: t.artistId,
              artistPermalink: t.artistPermalink,
              audioUrl: t.audioUrl!,
              coverUrl: t.artworkUrl,
              waveform: t.waveform,
            ))
        .toList();
    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: index.clamp(0, queue.length - 1),
        );
  }

  static String _fmtDuration(int? seconds) {
    if (seconds == null) return '';
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Retries up to 3 times with exponential backoff on 429
  Future<T> _withRetry<T>(Future<T> Function() call) async {
    int attempts = 0;
    while (true) {
      try {
        return await call();
      } on DioException catch (e) {
        if (e.response?.statusCode == 429 && attempts < 2) {
          await Future.delayed(Duration(seconds: (attempts + 1) * 2));
          attempts++;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _fetchLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      if (userId.isEmpty) return;
      final results = await _withRetry(
          () => sl<EngagementRemoteDataSource>().getUserLikes(userId));
      if (mounted) setState(() => _likes = results);
    } catch (_) {}
  }

  Future<void> _fetchPlaylists() async {
    if (mounted) setState(() => _playlistsLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      if (userId.isEmpty) {
        if (mounted) setState(() => _playlistsLoading = false);
        return;
      }
      final response = await _withRetry(() => dioClient.dio
          .get('/playlists', queryParameters: {'creator': userId}));
      final raw = response.data;
      List<dynamic> items = [];
      if (raw is Map) {
        final d = raw['data'];
        if (d is Map) {
          final p = d['playlists'];
          items = p is List ? p : [];
        }
      }
      final playlists = items
          .whereType<Map<String, dynamic>>()
          .where((json) {
            final isPrivate = json['isPrivate'] as bool?;
            return json['isPublic'] as bool? ?? !(isPrivate ?? false);
          })
          .map(_ProfilePlaylist.fromJson)
          .toList();
      for (var i = 0; i < playlists.length; i++) {
        final p = playlists[i];
        if (_ProfilePlaylist.isUsableArtworkUrl(p.artworkUrl) ||
            _ProfilePlaylist.isUsableArtworkUrl(p.firstTrackArtworkUrl)) {
          continue;
        }
        final detailedArtwork = await _fetchPlaylistFirstArtwork(p.id);
        if (detailedArtwork == null) continue;
        playlists[i] = _ProfilePlaylist(
          id: p.id,
          title: p.title,
          artworkUrl: p.artworkUrl,
          firstTrackArtworkUrl: detailedArtwork,
          ownerName: p.ownerName,
        );
      }
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _playlistsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _playlistsLoading = false);
    }
  }

  Future<String?> _fetchPlaylistFirstArtwork(String playlistId) async {
    try {
      final response =
          await _withRetry(() => dioClient.dio.get('/playlists/$playlistId'));
      final raw = response.data;
      final data = raw is Map ? raw['data'] : null;
      final playlist = data is Map ? data['playlist'] : null;
      final tracks = playlist is Map ? playlist['tracks'] as List? : null;
      if (tracks == null) return null;
      for (final item in tracks) {
        if (item is! Map) continue;
        final track = item['track'];
        final rawTrack = track is Map ? track : item;
        final artworkUrl = rawTrack['artworkUrl']?.toString();
        if (_ProfilePlaylist.isUsableArtworkUrl(artworkUrl)) {
          return artworkUrl;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchReposts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      if (userId.isEmpty) return;
      final results = await _withRetry(
          () => sl<EngagementRemoteDataSource>().getUserReposts(userId));
      if (mounted) setState(() => _reposts = results);
    } catch (_) {}
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final String userId = prefs.getString('userId') ?? '';

      if (userId.isEmpty) {
        if (mounted) {
          setState(() {
            _username = prefs.getString('displayName') ?? '';
            _isLoading = false;
          });
        }
        return;
      }

      // ── attempt 1: GET /profile/me (auth-required, always full data) ──
      // Owner-only endpoint — isPrivate never hides bio/city/country here.
      bool fetchedFromNetwork = false;
      Map<String, dynamic>? profileData;

      try {
        final profileResponse =
            await _withRetry(() => dioClient.dio.get('/profile/me'));

        // Null-safe extraction — avoids hard-cast TypeErrors on unexpected shapes.
        final respBody = profileResponse.data;
        final dataNode = (respBody is Map) ? respBody['data'] : null;
        final userNode = (dataNode is Map) ? dataNode['user'] : null;
        profileData =
            (userNode is Map) ? Map<String, dynamic>.from(userNode) : null;

        if (profileData == null) {
          throw Exception('Unexpected /profile/me response: $respBody');
        }
        fetchedFromNetwork = true;
      } on DioException catch (e) {
        // Log status code + body so the exact failure layer is identifiable.
        final statusCode = e.response?.statusCode;
        final responseBody = e.response?.data;
        // ignore: avoid_print
        print(
            '=== /profile/me FAILED: status=$statusCode body=$responseBody\n$e');

        // ── attempt 2: fallback to GET /profile/:permalink (no auth needed) ──
        final permalink = prefs.getString('permalink') ?? '';
        if (permalink.isNotEmpty) {
          try {
            final fallbackResponse = await _withRetry(
                () => dioClient.dio.get('/profile/$permalink'));
            final fb = fallbackResponse.data;
            final fbData = (fb is Map) ? fb['data'] : null;
            final fbUser = (fbData is Map) ? fbData['user'] : null;
            if (fbUser is Map) {
              profileData = Map<String, dynamic>.from(fbUser);
              fetchedFromNetwork = true;
            }
          } catch (fallbackErr) {
            // ignore: avoid_print
            print('=== /profile/$permalink ALSO FAILED: $fallbackErr');
          }
        }
      } catch (e, st) {
        // ignore: avoid_print
        print('=== PROFILE ME FETCH ERROR (non-Dio): $e\n$st');
      }

      // ── attempt 3: use SharedPreferences cached data ──
      if (!fetchedFromNetwork) {
        final cachedName = prefs.getString('displayName') ?? '';
        if (cachedName.isNotEmpty) {
          if (mounted) {
            setState(() {
              _username = cachedName;
              _bio = prefs.getString('bio') ?? '';
              _city = prefs.getString('city') ?? '';
              _country = prefs.getString('country') ?? '';
              _isLoading = false;
              // Show stale data rather than an error screen — retry is still
              // available via pull-to-refresh.
            });
          }
          return;
        }
        // No cached data at all — surface the error so the retry button appears.
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        return;
      }

      // ── parse whichever network response succeeded ────────────────────
      final data = profileData!;

      // Cache to prefs so edit-page re-fetches and network-error fallbacks
      // have fresh values.
      final bio = data['bio'] as String? ?? '';
      final city = data['city'] as String? ?? '';
      final country = data['country'] as String? ?? '';
      await prefs.setString('bio', bio);
      await prefs.setString('city', city);
      await prefs.setString('country', country);
      final avatarUrl = data['avatarUrl'] as String? ?? '';
      await prefs.setString('avatarUrl', avatarUrl);
      debugPrint('[Profile] avatarUrl persisted: $avatarUrl');

      // Always fetch counts from the network endpoints — they are authoritative.
      int followerCount = 0;
      int followingCount = 0;
      try {
        final followersResp = await _withRetry(
            () => dioClient.dio.get('/network/$userId/followers'));
        await Future.delayed(const Duration(milliseconds: 200));
        final followingResp = await _withRetry(
            () => dioClient.dio.get('/network/$userId/following'));
        followerCount = _parseInt(
            followersResp.data['total'] ?? followersResp.data['count']);
        followingCount = _parseInt(
            followingResp.data['total'] ?? followingResp.data['count']);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _username = data['displayName'] as String? ??
              prefs.getString('displayName') ??
              '';
          _bio = bio;
          _city = city;
          _country = country;
          _avatarUrl = data['avatarUrl'] as String? ?? '';
          _followerCount = followerCount;
          _followingCount = followingCount;
          _isLoading = false;
        });
      }
      return;
    } catch (e, st) {
      // ignore: avoid_print
      print('=== PROFILE FETCH ERROR: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  // ── navigate to edit, then re-fetch to show latest data ─────────────
  Future<void> _openEdit() async {
    final result =
        await context.push<Map<String, String>>('/profile/edit', extra: {
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
        _bio = result['bio'] ?? _bio;
        _city = result['city'] ?? _city;
        _country = result['country'] ?? _country;
      });
    }
    if (mounted) _fetchProfile();
  }

  // ─────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final myTracksAsync = ref.watch(myTracksProvider);
    // Keep _cachedTracks in sync so hero-section shuffle/play buttons work.
    ref.listen<AsyncValue<List<UploadTrack>>>(myTracksProvider, (_, next) {
      next.whenData((tracks) => _cachedTracks = tracks);
    });

    // When a playlist is deleted via playlistsProvider (library or details page),
    // mirror the removal into _playlists so the profile section updates immediately.
    ref.listen<List<Playlist>>(playlistsProvider, (previous, current) {
      if (previous == null || previous.length <= current.length) return;
      final removedIds = previous
          .map((p) => p.id)
          .toSet()
          .difference(current.map((p) => p.id).toSet());
      if (removedIds.isNotEmpty && mounted) {
        setState(() {
          _playlists =
              _playlists.where((p) => !removedIds.contains(p.id)).toList();
        });
      }
    });

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: _ProfileBottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          const routes = ['/home', '/feed', '/search', '/library', '/upgrade'];
          context.go(routes[index]);
        },
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _topBar(context),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF5500)),
                    ),
                  )
                else if (_hasError)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Couldn\'t load profile',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 15)),
                          const SizedBox(height: 12),
                          TextButton(
                            key: const ValueKey('profile_retry_button'),
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
                                fontSize: 24,
                                onSeeAll: () =>
                                    context.push('/profile/tracks')),
                            _tracksSection(myTracksAsync),
                            _sectionHeader('Reposts', onSeeAll: () {
                              _playFromReposts(0);
                              context.push('/profile/reposts');
                            }),
                            _repostsList(),
                            _sectionHeader('Playlists'),
                            _playlistRow(context),
                            _sectionHeader('Likes', onSeeAll: () {
                              _playFromLikes(0);
                              context.push('/profile/likes');
                            }),
                            _likesList(),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerWidget(),
          ),
        ],
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
              key: const ValueKey('profile_avatar_view_button'),
              onTap: () => context.push('/profile/avatar-view'),
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _orange, width: 2.5),
                ),
                child: ClipOval(
                  child: _avatarUrl.isNotEmpty &&
                          !_avatarUrl.contains('default-avatar')
                      ? CachedNetworkImage(
                          imageUrl: _avatarUrl,
                          width: 108,
                          height: 108,
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
            // Plan badge
            Builder(builder: (_) {
              final sub = ref.watch(subscriptionProvider);
              if (!sub.isPremium) return const SizedBox.shrink();
              final isArtistPro = sub.planType == 'Pro';
              return Padding(
                key: const ValueKey('profile_plan_badge'),
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isArtistPro
                          ? const [Color(0xFF6B1DC8), Color(0xFFE0188A)]
                          : const [Color(0xFF1A6FFF), Color(0xFF0A4DBF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sub.displayPlanName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              );
            }),
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
                  key: const ValueKey('profile_followers_button'),
                  onTap: () => context.push('/profile/followers'),
                  child: Text(
                      '$_followerCount ${_followerCount == 1 ? 'Follower' : 'Followers'}',
                      style: TextStyle(color: _sub, fontSize: 13)),
                ),
                Text('  ·  ', style: TextStyle(color: _sub, fontSize: 13)),
                GestureDetector(
                  key: const ValueKey('profile_following_button'),
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
                  key: const ValueKey('profile_edit_button'),
                  onTap: _openEdit,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.edit_outlined,
                        color: Colors.white70, size: 22),
                  ),
                ),
                const Spacer(),
                _iconCircle(Icons.shuffle_rounded, () {
                  if (_cachedTracks.isEmpty) return;
                  _playFrom(_cachedTracks.length == 1
                      ? 0
                      : (DateTime.now().millisecondsSinceEpoch %
                              _cachedTracks.length)
                          .toInt());
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
              key: const ValueKey('profile_bio_toggle_button'),
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
        key: const ValueKey('profile_insights_button'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const YourInsightsPage())),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
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
  Widget _spotlight() {
    final pinnedTracks = _cachedTracks
        .where((t) => t.id != null && _pinnedTrackIds.contains(t.id))
        .toList();

    return KeyedSubtree(
      key: const ValueKey('spotlight_section'),
      child: Padding(
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
                  key: const ValueKey('spotlight_edit_button'),
                  onTap: _onSpotlightEdit,
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
            if (pinnedTracks.isEmpty)
              Text('Pin items to your Spotlight',
                  style: TextStyle(color: _sub, fontSize: 13))
            else
              Column(
                children: pinnedTracks.map((t) {
                  return Container(
                    key: ValueKey('spotlight_track_tile_${t.id}'),
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: t.artworkUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: t.artworkUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: const Color(0xFF2C2C2E),
                                    child: const Icon(Icons.music_note,
                                        color: Colors.white54, size: 20),
                                  ),
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: const Color(0xFF2C2C2E),
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white54, size: 20),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                t.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: _sub, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.push_pin, color: _orange, size: 16),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _onSpotlightEdit() {
    final sub = ref.read(subscriptionProvider);
    if (!sub.isPremium) {
      context.push('/upgrade');
      return;
    }
    _showSpotlightPinDialog();
  }

  void _showSpotlightPinDialog() {
    final tracks = _cachedTracks;
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload some tracks first to pin them to Spotlight.'),
          backgroundColor: Color(0xFF333333),
        ),
      );
      return;
    }

    final selected = Set<String>.from(_pinnedTrackIds);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Pin to Spotlight',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  itemBuilder: (_, i) {
                    final t = tracks[i];
                    final isPinned = t.id != null && selected.contains(t.id);
                    return ListTile(
                      key: ValueKey('spotlight_pin_option_${t.id}'),
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: t.artworkUrl != null
                            ? CachedNetworkImage(
                                imageUrl: t.artworkUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 36,
                                  height: 36,
                                  color: const Color(0xFF2C2C2E),
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white54, size: 16),
                                ),
                              )
                            : Container(
                                width: 36,
                                height: 36,
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(Icons.music_note,
                                    color: Colors.white54, size: 16),
                              ),
                      ),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      trailing: isPinned
                          ? const Icon(Icons.push_pin,
                              color: Color(0xFFFF5500), size: 20)
                          : Icon(Icons.push_pin_outlined,
                              color: Colors.white38, size: 20),
                      onTap: () {
                        if (t.id == null) return;
                        setDialogState(() {
                          if (isPinned) {
                            selected.remove(t.id);
                          } else if (selected.length < 3) {
                            selected.add(t.id!);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Max 3 tracks in Spotlight.'),
                                backgroundColor: Color(0xFF333333),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  key: const ValueKey('spotlight_save_button'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _savePinnedTracks(selected.toList());
                  },
                  child: const Text('Save',
                      style: TextStyle(color: Color(0xFFFF5500))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── tracks section (inline preview, up to 3) ─────────────────────────
  Widget _tracksSection(AsyncValue<List<UploadTrack>> myTracksAsync) {
    return myTracksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)),
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child:
            Text('No tracks yet', style: TextStyle(color: _sub, fontSize: 14)),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('No tracks yet',
                style: TextStyle(color: _sub, fontSize: 14)),
          );
        }
        final preview = tracks.take(3).toList();
        return Column(
          children: preview.asMap().entries.map((e) {
            final t = e.value;
            // Find this track's index in the full cached list so playback
            // starts from the right position in the complete queue.
            final fullIdx = _cachedTracks.indexWhere((c) => c.id == t.id);
            return _TrackTile(
              track: _Track(t.title, t.artist, _fmtDuration(t.duration)),
              artworkUrl: t.artworkUrl,
              onTap: () => _playFrom(fullIdx < 0 ? e.key : fullIdx),
              onMore: () {},
            );
          }).toList(),
        );
      },
    );
  }

  // ── section header ───────────────────────────────────────────────────
  Widget _sectionHeader(String title,
          {VoidCallback? onSeeAll, double fontSize = 20}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            Text(title,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
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
  Widget _repostsList() {
    if (_reposts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child:
            Text('No reposts yet', style: TextStyle(color: _sub, fontSize: 14)),
      );
    }
    // Watch each repost's engagement state. Pass isReposted:true in params so
    // freshly-created providers start visible; existing provider state wins.
    final visible = _reposts.take(3).where((r) {
      return ref
          .watch(engagementProvider(EngagementParams(
            trackId: r.id,
            isReposted: true,
            repostCount: r.repostCount,
            likeCount: r.likeCount,
          )))
          .isReposted;
    }).toList();

    return Column(
      children: visible.asMap().entries.map((e) {
        final r = e.value;
        final sub = Colors.white.withOpacity(0.55);
        final hasArtwork = r.artworkUrl != null &&
            r.artworkUrl!.isNotEmpty &&
            r.artworkUrl!.startsWith('http');
        return GestureDetector(
          onTap: () => _playFromReposts(e.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: hasArtwork
                        ? Image.network(r.artworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _artworkPlaceholder())
                        : _artworkPlaceholder(),
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
                      Text(r.artistName,
                          style: TextStyle(color: sub, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 13, color: sub),
                          Text('  ${_fmtCount(r.playCount)}',
                              style: TextStyle(color: sub, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_vert_rounded, color: sub, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── likes list ───────────────────────────────────────────────────────
  Widget _likesList() {
    final mergedLikesAsync = ref.watch(mergedUserLikesProvider);
    final visibleLikes = mergedLikesAsync.maybeWhen(
      data: (tracks) => tracks,
      orElse: () => _likes,
    );
    if (visibleLikes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text('No liked tracks yet',
            style: TextStyle(color: _sub, fontSize: 14)),
      );
    }
    return Column(
      children: visibleLikes.take(3).toList().asMap().entries.map((e) {
        final r = e.value;
        final sub = Colors.white.withOpacity(0.55);
        final hasArtwork = r.artworkUrl != null &&
            r.artworkUrl!.isNotEmpty &&
            r.artworkUrl!.startsWith('http');
        return GestureDetector(
          onTap: () => _playFromLikes(e.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: hasArtwork
                        ? Image.network(r.artworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _artworkPlaceholder())
                        : _artworkPlaceholder(),
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
                      Text(r.artistName,
                          style: TextStyle(color: sub, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 13, color: sub),
                          Text('  ${_fmtCount(r.playCount)}',
                              style: TextStyle(color: sub, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_vert_rounded, color: sub, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _artworkPlaceholder() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
            child: Icon(Icons.music_note, color: Colors.white38, size: 24)),
      );

  String _fmtCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  // ── playlist row ─────────────────────────────────────────────────────
  Widget _playlistRow(BuildContext context) {
    final visiblePlaylists = _playlists;

    if (_playlistsLoading && visiblePlaylists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFFF5500)),
          ),
        ),
      );
    }
    if (visiblePlaylists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text('No playlists yet',
            style: TextStyle(color: _sub, fontSize: 14)),
      );
    }
    return SizedBox(
      height: 215,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: visiblePlaylists.length,
        itemBuilder: (_, i) {
          final p = visiblePlaylists[i];
          // Artwork chain: own HTTPS artwork → first track HTTPS artwork → placeholder
          final cardArtwork = () {
            final own = p.artworkUrl;
            if (_ProfilePlaylist.isUsableArtworkUrl(own)) {
              return own;
            }
            return p.firstTrackArtworkUrl;
          }();
          return GestureDetector(
            key: ValueKey('profile_playlist_tile_$i'),
            onTap: () async {
              await context.push('/playlist', extra: {'playlistId': p.id});
              if (mounted) _fetchPlaylists();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: cardArtwork != null
                            ? CachedNetworkImage(
                                imageUrl: cardArtwork,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.grey[850],
                                  child: const Icon(Icons.queue_music,
                                      size: 52, color: Colors.white38),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey[850],
                                  child: const Icon(Icons.queue_music,
                                      size: 52, color: Colors.white38),
                                ),
                              )
                            : Container(
                                color: Colors.grey[850],
                                child: const Icon(Icons.queue_music,
                                    size: 52, color: Colors.white38),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.ownerName,
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
  }

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

  Widget _playCircle(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final currentId = playerState.currentTrack?.id;
    final isFromHere =
        currentId != null && _cachedTracks.any((t) => t.id == currentId);
    final showPause = isFromHere && playerState.isPlaying;

    return GestureDetector(
      onTap: () {
        if (isFromHere) {
          ref.read(playerProvider.notifier).togglePlayPause();
        } else if (_cachedTracks.isNotEmpty) {
          _playFrom(0);
        }
      },
      child: Container(
        width: 52,
        height: 52,
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(
          showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }
}

// ── avatar fallback ───────────────────────────────────────────────────────
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.person, size: 64, color: Colors.white38),
    );
  }
}

// ── data models ──────────────────────────────────────────────────────────
class _ProfileBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _ProfileBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  static const _navColor = Color(0xFF2C2C2C);

  static const _items = <({String label, IconData active, IconData inactive})>[
    (label: 'Home', active: Icons.home, inactive: Icons.home_outlined),
    (
      label: 'Feed',
      active: Icons.web_asset,
      inactive: Icons.web_asset_outlined
    ),
    (label: 'Search', active: Icons.search, inactive: Icons.search),
    (
      label: 'Library',
      active: Icons.library_music,
      inactive: Icons.library_music_outlined,
    ),
    (label: 'Upgrade', active: Icons.graphic_eq, inactive: Icons.graphic_eq),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _navColor,
      child: SafeArea(
        top: false,
        child: Container(
          height: 55,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF3B3B3B))),
          ),
          child: Row(
            children: [
              for (int index = 0; index < _items.length; index++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            currentIndex == index
                                ? _items[index].active
                                : _items[index].inactive,
                            color: currentIndex == index
                                ? Colors.white
                                : const Color(0xFFB4B4B4),
                            size: 30,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _items[index].label,
                            style: TextStyle(
                              color: currentIndex == index
                                  ? Colors.white
                                  : const Color(0xFFB4B4B4),
                              fontSize: 8,
                              fontWeight: currentIndex == index
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Track {
  final String title;
  final String artist;
  final String duration;
  const _Track(this.title, this.artist, this.duration);
}

class _ProfilePlaylist {
  final String id;
  final String title;
  final String? artworkUrl;
  final String? firstTrackArtworkUrl;
  final String ownerName;

  const _ProfilePlaylist({
    required this.id,
    required this.title,
    this.artworkUrl,
    this.firstTrackArtworkUrl,
    required this.ownerName,
  });

  static bool isUsableArtworkUrl(String? url) =>
      url != null &&
      url.isNotEmpty &&
      url.startsWith('http') &&
      !url.contains('default');

  factory _ProfilePlaylist.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;

    // If the list response includes a populated tracks array, extract the first
    // track's artwork URL as a fallback for playlists without an explicit artwork.
    String? firstTrackArtwork;
    final tracks = json['tracks'] as List?;
    if (tracks != null && tracks.isNotEmpty) {
      final first = tracks.first;
      if (first is Map) {
        final track = first['track'];
        final rawTrack = track is Map ? track : first;
        final url = rawTrack['artworkUrl']?.toString();
        if (isUsableArtworkUrl(url)) {
          firstTrackArtwork = url;
        }
      }
    }

    return _ProfilePlaylist(
      id: (json['_id'] as String?) ?? (json['id'] as String?) ?? '',
      title: json['title'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      firstTrackArtworkUrl: firstTrackArtwork,
      ownerName: (json['ownerName'] as String?) ??
          (creator?['displayName'] as String?) ??
          '',
    );
  }
}

// ── track tile ───────────────────────────────────────────────────────────
class _TrackTile extends StatelessWidget {
  final _Track track;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final String? artworkUrl;

  const _TrackTile({
    required this.track,
    required this.onTap,
    required this.onMore,
    this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withOpacity(0.55);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              key: const ValueKey('profile_track_tile'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
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
                              color: const Color(0xFF2A2A2A),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white38, size: 24),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFF2A2A2A),
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
                            Icon(Icons.play_arrow_rounded,
                                size: 13, color: sub),
                            Text('  ${track.duration}',
                                style: TextStyle(color: sub, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('profile_track_more_button'),
            behavior: HitTestBehavior.opaque,
            onTap: onMore,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(Icons.more_vert_rounded, color: sub, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
