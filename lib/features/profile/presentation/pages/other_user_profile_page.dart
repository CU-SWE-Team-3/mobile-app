import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/widgets/mini_player_widget.dart';

class OtherUserProfilePage extends ConsumerStatefulWidget {
  final String permalink;
  final String initialDisplayName;
  final String initialUserId;

  const OtherUserProfilePage({
    super.key,
    required this.permalink,
    this.initialDisplayName = '',
    this.initialUserId = '',
  });

  @override
  ConsumerState<OtherUserProfilePage> createState() =>
      _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends ConsumerState<OtherUserProfilePage> {
  String _username = '';
  String _bio = '';
  String _city = '';
  String _country = '';
  String _avatarUrl = '';
  String _coverUrl = '';
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isPrivate = false;
  bool _isFollowing = false;
  String _targetUserId = '';
  bool _isLoading = true;
  bool _hasError = false;
  bool _bioExpanded = false;
  bool _followLoading = false;
  bool _isBlocked = false;
  int _selectedTabIndex = 0;
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoadingTracks = false;
  bool _hasTracksError = false;
  List<Map<String, dynamic>>? _repostedTracks;
  bool _isLoadingReposts = false;
  bool _hasRepostsError = false;
  List<Map<String, dynamic>>? _likedTracks;
  bool _isLoadingLikes = false;
  bool _hasLikesError = false;

  String get _permalink => widget.permalink;

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.initialUserId;
    _username = widget.initialDisplayName;
    _fetchProfile();
  }

  Future<void> _fetchLikes() async {
    if (!mounted || _isLoadingLikes || _targetUserId.isEmpty) return;
    setState(() {
      _isLoadingLikes = true;
      _hasLikesError = false;
    });
    try {
      final response = await dioClient.dio.get('/profile/$_targetUserId/likes');
      final tracks = _extractTracksFromResponse(
        response.data,
        listKeys: const ['likedTracks', 'tracks'],
      );
      if (mounted) {
        setState(() {
          _likedTracks = tracks;
          _isLoadingLikes = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingLikes = false;
          _hasLikesError = true;
        });
      }
    }
  }

  Future<void> _fetchReposts() async {
    if (!mounted || _isLoadingReposts || _targetUserId.isEmpty) return;
    setState(() {
      _isLoadingReposts = true;
      _hasRepostsError = false;
    });
    try {
      final response =
          await dioClient.dio.get('/profile/$_targetUserId/reposts');
      final tracks = _extractTracksFromResponse(
        response.data,
        listKeys: const ['repostedTracks', 'tracks'],
      );
      if (mounted) {
        setState(() {
          _repostedTracks = tracks;
          _isLoadingReposts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingReposts = false;
          _hasRepostsError = true;
        });
      }
    }
  }

  Future<void> _fetchUploadedTracks() async {
    if (!mounted || _isLoadingTracks || _targetUserId.isEmpty) return;
    setState(() {
      _isLoadingTracks = _tracks.isEmpty;
      _hasTracksError = false;
    });

    final endpoints = <String>[
      '/profile/$_targetUserId/tracks',
      '/users/$_targetUserId/tracks',
    ];

    try {
      for (final endpoint in endpoints) {
        try {
          final response = await dioClient.dio.get(
            endpoint,
            queryParameters: const {'page': 1, 'limit': 50},
          );
          final tracks = _extractTracksFromResponse(
            response.data,
            listKeys: const ['uploadedTracks', 'tracks', 'topTracks'],
          );
          if (tracks.isNotEmpty) {
            if (mounted) {
              setState(() {
                _tracks = _dedupeTracks(tracks);
                _isLoadingTracks = false;
              });
            }
            return;
          }
        } on DioException catch (e) {
          if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
            continue;
          }
          rethrow;
        }
      }

      if (mounted) setState(() => _isLoadingTracks = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingTracks = false;
          _hasTracksError = _tracks.isEmpty;
        });
      }
    }
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  List<dynamic> _extractBlockedList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return const [];
    final data = raw['data'];
    if (data is List) return data;
    if (data is Map) {
      for (final key in const ['blockedUsers', 'users', 'blocked']) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    for (final key in const ['blockedUsers', 'users', 'blocked']) {
      final value = raw[key];
      if (value is List) return value;
    }
    return const [];
  }

  String _blockedUserId(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is! Map) return raw.toString();
    final map = Map<String, dynamic>.from(raw);
    for (final key in const ['_id', 'id', 'userId', 'blockedUserId']) {
      final value = map[key]?.toString() ?? '';
      if (value.isNotEmpty) return value;
    }
    for (final key in const ['blockedUser', 'user', 'target']) {
      final value = map[key];
      if (value is Map) {
        final id = _blockedUserId(value);
        if (id.isNotEmpty) return id;
      } else {
        final id = value?.toString() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    return '';
  }

  /// Tries multiple strategies to determine follow status.
  Future<bool> _checkIsFollowing(String myId, String targetId) async {
    // ── Strategy 1: dedicated endpoint ──────────────────────────────
    try {
      final res = await dioClient.dio.get('/network/$myId/following/$targetId');
      final d = res.data;
      if (d is Map) {
        if (d.containsKey('isFollowing')) return d['isFollowing'] as bool? ?? false;
        if (d.containsKey('following'))   return d['following']   as bool? ?? false;
      }
    } catch (_) {}

    // ── Strategy 2: check if myId appears in target's followers ─────
    try {
      final res = await dioClient.dio
          .get('/network/$targetId/followers?page=1&limit=500');
      final list = res.data['data'] as List? ?? [];
      if (list.any((u) => u['_id'] == myId || u['id'] == myId)) return true;
    } catch (_) {}

    // ── Strategy 3: paginated following list (up to 10 pages) ───────
    try {
      for (int page = 1; page <= 10; page++) {
        final res = await dioClient.dio
            .get('/network/$myId/following?page=$page&limit=100');
        final list = res.data['data'] as List? ?? [];
        if (list.any((u) => u['_id'] == targetId || u['id'] == targetId)) {
          return true;
        }
        if (list.length < 100) break; // reached end
      }
    } catch (_) {}

    return false;
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final profileRes = await dioClient.dio.get('/profile/$_permalink');
      final data = profileRes.data['data']['user'] as Map<String, dynamic>;

      // ── Assign _targetUserId from API FIRST (before any checks) ───
      final fetchedId = data['_id'] as String? ?? '';
      if (fetchedId.isNotEmpty) _targetUserId = fetchedId;
      final hasEmbeddedUploads = _hasProfileUploadedTracks(data);

      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('userId') ?? '';

      // ── Blocked status ─────────────────────────────────────────────
      try {
        final blockedRes = await dioClient.dio.get('/network/blocked-users');
        final blockedList = _extractBlockedList(blockedRes.data);
        _isBlocked = blockedList.any((u) => _blockedUserId(u) == _targetUserId);
      } catch (_) {
        final cached = prefs.getStringList('blockedUserIds') ?? [];
        _isBlocked = cached.contains(_targetUserId);
      }

      // ── Follow status ──────────────────────────────────────────────
      bool alreadyFollowing = false;
      if (myId.isNotEmpty && _targetUserId.isNotEmpty && myId != _targetUserId) {
        // Best case: backend already returns isFollowing in profile data
        if (data.containsKey('isFollowing')) {
          alreadyFollowing = data['isFollowing'] as bool? ?? false;
          debugPrint('=== follow from profile field: $alreadyFollowing');
        } else {
          alreadyFollowing = await _checkIsFollowing(myId, _targetUserId);
          debugPrint('=== follow from check strategies: $alreadyFollowing');
        }
      }

      if (mounted) {
        setState(() {
          _username       = data['displayName'] as String? ?? '';
          _bio            = data['bio']         as String? ?? '';
          _city           = data['city']        as String? ?? '';
          _country        = data['country']     as String? ?? '';
          _avatarUrl      = data['avatarUrl']   as String? ?? '';
          _coverUrl       = data['coverUrl']    as String? ?? '';
          _followerCount  = _parseInt(data['followerCount']);
          _followingCount = _parseInt(data['followingCount']);
          _isPrivate      = data['isPrivate']   as bool? ?? false;
          _isFollowing    = alreadyFollowing;
          _tracks = _dedupeTracks(_extractTracksFromProfile(data));
          _isLoading = false;
        });
      }
      if (mounted && !hasEmbeddedUploads) {
        _fetchUploadedTracks();
      }
    } catch (e) {
      debugPrint('=== PROFILE FETCH ERROR: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // ── Playback ──────────────────────────────────────────────────────
  void _playFrom(List<Map<String, dynamic>> tracks, int index) {
    final queue = tracks.map((t) {
      final artist = _readArtist(t);
      final artistId = artist['_id']?.toString() ??
          artist['id']?.toString() ??
          t['artistId']?.toString();
      final artistPermalink =
          artist['permalink']?.toString() ?? t['artistPermalink']?.toString();
      final artistName = _readArtistName(t);
      return PlayerTrack(
        id: (t['_id'] ?? t['id'] ?? '').toString(),
        title: (t['title'] ?? '').toString(),
        artist: artistName,
        artistId: artistId,
        artistPermalink: artistPermalink,
        audioUrl: (t['hlsUrl'] ?? t['audioUrl'] ?? '').toString(),
        coverUrl: t['artworkUrl'] as String? ?? t['coverUrl'] as String?,
        waveform: (t['waveform'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList(),
      );
    }).where((t) => t.audioUrl.isNotEmpty).toList();
    if (queue.isEmpty) return;
    final clampedIndex = index.clamp(0, queue.length - 1);
    ref.read(playerProvider.notifier).playQueue(queue, startIndex: clampedIndex);
  }

  // ── Optimistic toggle with revert on failure ───────────────────────
  Future<void> _toggleFollow() async {
    if (_followLoading || _targetUserId.isEmpty) return;

    final wasFollowing = _isFollowing;
    setState(() {
      _followLoading = true;
      _isFollowing = !wasFollowing;
      _followerCount += wasFollowing ? -1 : 1;
    });

    try {
      if (wasFollowing) {
        await dioClient.dio.delete('/network/$_targetUserId/follow');
      } else {
        await dioClient.dio.post('/network/$_targetUserId/follow');
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _followerCount += wasFollowing ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.response?.statusCode == 401
                  ? 'Please log in to follow users.'
                  : 'Action failed. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _toggleBlock(String userId) async {
    if (_isBlocked) {
      try {
        await dioClient.dio.delete('/network/$userId/block');
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('blockedUserIds') ?? [];
        cached.remove(userId);
        await prefs.setStringList('blockedUserIds', cached);
        if (!mounted) return;
        setState(() => _isBlocked = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('User unblocked')));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to unblock user. Try again.'),
          backgroundColor: Colors.red,
        ));
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Block user?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'They won\'t be able to see your profile or tracks. You won\'t see their content either.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              key: const ValueKey('other_profile_block_cancel_button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              key: const ValueKey('other_profile_block_confirm_button'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Block',
                  style: TextStyle(color: Color(0xFFFF5500))),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      try {
        await dioClient.dio.post('/network/$userId/block');
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('blockedUserIds') ?? [];
        if (!cached.contains(userId)) {
          cached.add(userId);
          await prefs.setStringList('blockedUserIds', cached);
        }
        if (!mounted) return;
        setState(() => _isBlocked = true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('User blocked')));
      } catch (e) {
        if (!mounted) return;
        final statusCode = (e is DioException) ? e.response?.statusCode : null;
        if (statusCode == 400) {
          setState(() => _isBlocked = true);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User is already blocked')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to block user. Try again.'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('other_profile_block_tile'),
            leading: const Icon(Icons.block, color: Colors.white70),
            title: Text(_isBlocked ? 'Unblock user' : 'Block user',
                style: const TextStyle(color: Colors.white)),
            onTap: _targetUserId.isNotEmpty
                ? () {
                    Navigator.of(context).pop();
                    _toggleBlock(_targetUserId);
                  }
                : null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: GestureDetector(
          key: const ValueKey('other_profile_back_button'),
          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration:
                BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle),
            child:
                const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('other_profile_more_button'),
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: _showMoreSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5500)))
                : _hasError
                    ? _buildError()
                    : _buildBody(),
          ),
          const MiniPlayerWidget(),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Couldn't load profile",
                style: TextStyle(color: Colors.grey[400], fontSize: 15)),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey('other_profile_retry_button'),
              onPressed: _fetchProfile,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5500)),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

  Widget _buildBody() =>
      _isBlocked
          ? _buildBlockedProfile()
          : _isPrivate && !_isFollowing
              ? _buildPrivateProfile()
              : _buildPublicProfile();

  Widget _buildBlockedProfile() {
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : '?';
    final isDefault =
        _avatarUrl.isEmpty || _avatarUrl.contains('default-avatar');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatarRing(
              initial: initial,
              isDefaultAvatar: isDefault,
              radius: 44,
            ),
            const SizedBox(height: 18),
            Text(
              _username.isEmpty ? 'Blocked user' : _username,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You blocked this user. Their profile and tracks are hidden.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              key: const ValueKey('other_profile_unblock_button'),
              onPressed: _targetUserId.isEmpty
                  ? null
                  : () => _toggleBlock(_targetUserId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Unblock user'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateProfile() {
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : '?';
    final isDefault =
        _avatarUrl.isEmpty || _avatarUrl.contains('default-avatar');
    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 24),
        _buildAvatarRing(initial: initial, isDefaultAvatar: isDefault, radius: 50),
        const SizedBox(height: 16),
        Text(_username,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(widget.permalink,
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 20),
        if (_targetUserId.isNotEmpty) _followButton(),
        const SizedBox(height: 52),
        const Icon(Icons.lock_outline, color: Colors.white54, size: 52),
        const SizedBox(height: 12),
        Text('This account is private',
            style: TextStyle(color: Colors.grey[400], fontSize: 15)),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildPublicProfile() {
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : '?';
    final isDefault =
        _avatarUrl.isEmpty || _avatarUrl.contains('default-avatar');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover + Avatar
          SizedBox(
            height: 160,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: _coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _coverUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFF2A2A2A)),
                      )
                    : Container(color: const Color(0xFF2A2A2A)),
              ),
              Positioned(
                bottom: -44,
                left: 16,
                child: _buildAvatarRing(
                    initial: initial, isDefaultAvatar: isDefault, radius: 44),
              ),
            ]),
          ),
          const SizedBox(height: 56),

          // Name
          Center(
            child: Text(_username,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ),

          // Counts
          const SizedBox(height: 8),
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                key: const ValueKey('other_profile_followers_button'),
                onTap: _targetUserId.isNotEmpty
                    ? () => context.push('/profile/followers',
                        extra: {'targetUserId': _targetUserId})
                    : null,
                child: Text('${_formatCount(_followerCount)} Followers',
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ),
              const Text(' · ',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
              GestureDetector(
                key: const ValueKey('other_profile_following_button'),
                onTap: _targetUserId.isNotEmpty
                    ? () => context.push('/profile/following',
                        extra: {'targetUserId': _targetUserId})
                    : null,
                child: Text('${_formatCount(_followingCount)} Following',
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Action row
          if (_targetUserId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _followButton()),
                const SizedBox(width: 10),
                const _CircleIconBtn(icon: Icons.notifications_none),
                const SizedBox(width: 10),
                const _CircleIconBtn(icon: Icons.message_outlined),
                const SizedBox(width: 10),
                const _CircleIconBtn(icon: Icons.shuffle),
                const SizedBox(width: 10),
                const _CircleIconBtn(icon: Icons.play_circle_outline, size: 34),
              ]),
            ),

          // Bio
          if (_bio.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_bio,
                    maxLines: _bioExpanded ? null : 3,
                    overflow: _bioExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                if (_bio.length > 120)
                  GestureDetector(
                    key: const ValueKey('other_profile_bio_toggle_button'),
                    onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_bioExpanded ? 'Show less' : 'Show more',
                          style: const TextStyle(
                              color: Color(0xFFFF5500), fontSize: 13)),
                    ),
                  ),
              ]),
            ),
          ],

          // Location
          if (_city.isNotEmpty || _country.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text([_city, _country].where((s) => s.isNotEmpty).join(', '),
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            ),
          ],

          // ── Tracks / Reposts tabs ──────────────────────────────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _TabChip(
                  label: 'Tracks',
                  selected: _selectedTabIndex == 0,
                  onTap: () => setState(() => _selectedTabIndex = 0),
                ),
                const SizedBox(width: 10),
                _TabChip(
                  label: 'Reposts',
                  selected: _selectedTabIndex == 1,
                  onTap: () {
                    setState(() => _selectedTabIndex = 1);
                    if (_repostedTracks == null) _fetchReposts();
                  },
                ),
                const SizedBox(width: 10),
                _TabChip(
                  label: 'Likes',
                  selected: _selectedTabIndex == 2,
                  onTap: () {
                    setState(() => _selectedTabIndex = 2);
                    if (_likedTracks == null) _fetchLikes();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedTabIndex == 0) ...[
            if (_isLoadingTracks)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
              )
            else if (_hasTracksError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load tracks',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _fetchUploadedTracks,
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFFFF5500))),
                      ),
                    ],
                  ),
                ),
              )
            else if (_tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No tracks yet',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              )
            else
              ..._tracks.asMap().entries.map((e) => _TrackRow(
                    track: e.value,
                    onTap: () => _playFrom(_tracks, e.key),
                  )),
          ],
          if (_selectedTabIndex == 1) ...[
            if (_isLoadingReposts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
              )
            else if (_hasRepostsError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load reposts',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _fetchReposts,
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFFFF5500))),
                      ),
                    ],
                  ),
                ),
              )
            else if (_repostedTracks == null || _repostedTracks!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No reposts yet',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              )
            else
              ..._repostedTracks!.take(10).toList().asMap().entries.map((e) =>
                  _TrackRow(
                    track: e.value,
                    onTap: () => _playFrom(_repostedTracks!.take(10).toList(), e.key),
                  )),
          ],
          if (_selectedTabIndex == 2) ...[
            if (_isLoadingLikes)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
              )
            else if (_hasLikesError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load likes',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _fetchLikes,
                        child: const Text('Retry',
                            style: TextStyle(color: Color(0xFFFF5500))),
                      ),
                    ],
                  ),
                ),
              )
            else if (_likedTracks == null || _likedTracks!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No likes yet',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              )
            else
              ..._likedTracks!.take(10).toList().asMap().entries.map((e) =>
                  _TrackRow(
                    track: e.value,
                    onTap: () => _playFrom(_likedTracks!.take(10).toList(), e.key),
                  )),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _followButton() => ElevatedButton(
        key: const ValueKey('other_profile_follow_button'),
        onPressed: _followLoading ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isFollowing ? const Color(0xFF1F1F1F) : const Color(0xFFFF5500),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: _followLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(_isFollowing ? 'Following' : 'Follow'),
      );

  Widget _buildAvatarRing({
    required String initial,
    required bool isDefaultAvatar,
    double radius = 44,
  }) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFFF5500), width: 2.5)),
      ),
      child: ClipOval(
        child: isDefaultAvatar
            ? Container(
                color: const Color(0xFF2A2A2A),
                child: Center(
                  child: Text(initial,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: radius * 0.6)),
                ),
              )
            : CachedNetworkImage(
                imageUrl: _avatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF2A2A2A),
                  child: Center(
                    child: Text(initial,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: radius * 0.6)),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF5500) : Colors.transparent,
          border: Border.all(
            color: selected ? const Color(0xFFFF5500) : Colors.white38,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  const _CircleIconBtn({required this.icon, this.size = 24});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white70, size: size),
      );
}

class _TrackRow extends StatelessWidget {
  final Map<String, dynamic> track;
  final VoidCallback? onTap;
  const _TrackRow({required this.track, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = track['title'] as String? ?? '';
    final artistName = _readArtistName(track);
    final coverUrl = track['artworkUrl'] as String? ??
        track['coverUrl'] as String? ??
        track['thumbnailUrl'] as String?;
    final playCount =
        _safeInt(track['playCount'] ?? track['plays'] ?? track['playsCount']);
    final duration = _safeInt(track['duration']);
    final durationStr = duration > 0
        ? '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}'
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: coverUrl != null && coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: coverUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[800],
                    ),
                  )
                : Container(width: 48, height: 48, color: Colors.grey[800]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (artistName.isNotEmpty)
                  Text(
                    artistName,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Row(children: [
                  const Icon(Icons.play_arrow, color: Colors.grey, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '$playCount',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ]),
              ],
            ),
          ),
          if (durationStr.isNotEmpty) ...[
            Text(
              durationStr,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.more_vert, color: Colors.grey, size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '$count';
}

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

Map<String, dynamic>? _asTrackMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

Map<String, dynamic> _readArtist(Map<String, dynamic> track) {
  return _asTrackMap(track['artist'] ?? track['creator'] ?? track['user']) ??
      const {};
}

String _readArtistName(Map<String, dynamic> track) {
  final artist = _readArtist(track);
  return (artist['displayName'] ??
          artist['username'] ??
          artist['name'] ??
          track['artistName'] ??
          track['creatorName'] ??
          track['displayName'] ??
          '')
      .toString();
}

Map<String, dynamic>? _extractTrackFromItem(dynamic item) {
  final map = _asTrackMap(item);
  if (map == null) return null;

  for (final key in const ['target', 'track', 'item']) {
    final nested = _asTrackMap(map[key]);
    if (nested != null) return nested;
  }

  for (final key in const ['target', 'track', 'item']) {
    final id = map[key];
    if (id is String && id.isNotEmpty) {
      return Map<String, dynamic>.from(map)..['_id'] = id;
    }
  }

  final targetModel = map['targetModel']?.toString().toLowerCase();
  if (targetModel != null && targetModel != 'track') return null;

  return map;
}

List<Map<String, dynamic>> _dedupeTracks(List<Map<String, dynamic>> tracks) {
  final seen = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final track in tracks) {
    final id = (track['_id'] ?? track['id'] ?? track['permalink'] ?? '')
        .toString();
    if (id.isEmpty || seen.add(id)) {
      result.add(track);
    }
  }
  return result;
}

List<Map<String, dynamic>> _extractTracksFromProfile(Map<String, dynamic> user) {
  final tracks = <Map<String, dynamic>>[];
  for (final key in const ['uploadedTracks', 'tracks', 'topTracks']) {
    final raw = user[key];
    if (raw is List) {
      for (final item in raw) {
        final track = _extractTrackFromItem(item);
        if (track != null) tracks.add(track);
      }
    }
  }
  return tracks;
}

bool _hasProfileUploadedTracks(Map<String, dynamic> user) {
  return user['uploadedTracks'] is List || user['tracks'] is List;
}

List<Map<String, dynamic>> _extractTracksFromResponse(
  dynamic responseData, {
  required List<String> listKeys,
}) {
  final root = _asTrackMap(responseData);
  final data = _asTrackMap(root?['data']);
  final candidates = <dynamic>[
    if (data != null) ...listKeys.map((key) => data[key]),
    if (root != null) ...listKeys.map((key) => root[key]),
    data,
    root?['data'],
  ];

  final tracks = <Map<String, dynamic>>[];
  for (final candidate in candidates) {
    if (candidate is! List) continue;
    for (final item in candidate) {
      final track = _extractTrackFromItem(item);
      if (track != null) tracks.add(track);
    }
    if (tracks.isNotEmpty) break;
  }
  return _dedupeTracks(tracks);
}
