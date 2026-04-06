import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';

class OtherUserProfilePage extends StatefulWidget {
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
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
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
  List<Map<String, dynamic>> _topTracks = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _bioExpanded = false;
  bool _followLoading = false;
  bool _isBlocked = false;

  String get _permalink => widget.permalink;

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.initialUserId;
    _username = widget.initialDisplayName;
    _fetchProfile();
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final profileRes = await dioClient.dio.get('/profile/$_permalink');
      final data = profileRes.data['data']['user'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('userId') ?? '';

      try {
        final blockedRes = await dioClient.dio.get('/network/blocked-users');
        final blockedList = blockedRes.data['data'] as List? ?? [];
        _isBlocked = blockedList.any((u) => u['_id'] == _targetUserId);
      } catch (_) {
        final cached = prefs.getStringList('blockedUserIds') ?? [];
        _isBlocked = cached.contains(_targetUserId);
      }

      // Update _targetUserId from API response
      final fetchedId = data['_id'] as String? ?? '';
      if (fetchedId.isNotEmpty) _targetUserId = fetchedId;

      bool alreadyFollowing = false;
      if (myId.isNotEmpty && _targetUserId.isNotEmpty) {
        try {
          final followingRes = await dioClient.dio
              .get('/network/$myId/following?page=1&limit=999');
          final followingList = followingRes.data['data'] as List? ?? [];
          alreadyFollowing =
              followingList.any((u) => u['_id'] == _targetUserId);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _targetUserId   = fetchedId.isNotEmpty ? fetchedId : _targetUserId;
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
          _isBlocked      = _isBlocked;
          _topTracks      = (data['topTracks'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _toggleFollow() async {
    if (_followLoading || _targetUserId.isEmpty) return;
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await dioClient.dio.delete('/network/$_targetUserId/follow');
        setState(() {
          _isFollowing = false;
          if (_followerCount > 0) _followerCount--;
        });
      } else {
        await dioClient.dio.post('/network/$_targetUserId/follow');
        setState(() {
          _isFollowing = true;
          _followerCount++;
        });
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _toggleBlock(String userId) async {
    Navigator.of(context).pop(); // close bottom sheet first

    if (_isBlocked) {
      // ── UNBLOCK ──────────────────────────────────────────
      try {
        await dioClient.dio.delete('/network/$userId/block');

        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('blockedUserIds') ?? [];
        cached.remove(userId);
        await prefs.setStringList('blockedUserIds', cached);

        if (!mounted) return;
        setState(() => _isBlocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unblock user. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // ── BLOCK ─────────────────────────────────────────────
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Block user?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'They won\'t be able to see your profile or tracks. You won\'t see their content either.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Block', style: TextStyle(color: Color(0xFFFF5500))),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
        context.pop();
      } catch (e) {
        if (!mounted) return;
        // Check if already blocked on backend — treat as success
        final statusCode = (e is DioException) ? e.response?.statusCode : null;
        if (statusCode == 400) {
          setState(() => _isBlocked = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User is already blocked')),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to block user. Try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: Colors.white70),
            title: Text(
              _isBlocked ? 'Unblock user' : 'Block user',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: _targetUserId.isNotEmpty
                ? () => _toggleBlock(_targetUserId)
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
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: _showMoreSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)))
          : _hasError
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Couldn't load profile",
              style: TextStyle(color: Colors.grey[400], fontSize: 15)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchProfile,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500)),
            child:
                const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isPrivate) return _buildPrivateProfile();
    return _buildPublicProfile();
  }

  Widget _buildPrivateProfile() {
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : '?';
    final isDefaultAvatar =
        _avatarUrl.isEmpty || _avatarUrl.contains('default-avatar');

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildAvatarRing(
              initial: initial, isDefaultAvatar: isDefaultAvatar, radius: 50),
          const SizedBox(height: 16),
          Text(
            _username,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
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
        ],
      ),
    );
  }

  Widget _buildPublicProfile() {
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : '?';
    final isDefaultAvatar =
        _avatarUrl.isEmpty || _avatarUrl.contains('default-avatar');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover + Avatar Hero ────────────────────────────────
          SizedBox(
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover photo (full-width, 160px)
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
                // Avatar overlapping bottom-left (~radius 44)
                Positioned(
                  bottom: -44,
                  left: 16,
                  child: _buildAvatarRing(
                      initial: initial,
                      isDefaultAvatar: isDefaultAvatar,
                      radius: 44),
                ),
              ],
            ),
          ),
          const SizedBox(height: 56), // space for avatar overflow

          // ── Display name ──────────────────────────────────────
          Center(
            child: Text(
              _username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // ── Follower / Following counts ───────────────────────
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _targetUserId.isNotEmpty
                      ? () => context.push('/profile/followers',
                          extra: {'targetUserId': _targetUserId})
                      : null,
                  child: Text(
                    '${_formatCount(_followerCount)} Followers',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
                const Text(' · ',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                GestureDetector(
                 onTap: _targetUserId.isNotEmpty
                          ? () {
                            debugPrint('=== FOLLOWING TAP targetUserId: $_targetUserId');
                             context.push('/profile/following',
                              extra: {'targetUserId': _targetUserId});
                                      }
                                        : null,
                  child: Text(

                    
                    '${_formatCount(_followingCount)} Following',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Action row ────────────────────────────────────────
          if (_targetUserId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _followButton()),
                  const SizedBox(width: 10),
                  const _CircleIconBtn(icon: Icons.notifications_none),
                  const SizedBox(width: 10),
                  const _CircleIconBtn(icon: Icons.message_outlined),
                  const SizedBox(width: 10),
                  const _CircleIconBtn(icon: Icons.shuffle),
                  const SizedBox(width: 10),
                  const _CircleIconBtn(
                      icon: Icons.play_circle_outline, size: 34),
                ],
              ),
            ),

          // ── Bio ───────────────────────────────────────────────
          if (_bio.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bio,
                    maxLines: _bioExpanded ? null : 3,
                    overflow: _bioExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                  if (_bio.length > 120)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _bioExpanded = !_bioExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _bioExpanded ? 'Show less' : 'Show more',
                          style: const TextStyle(
                              color: Color(0xFFFF5500), fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Location ──────────────────────────────────────────
          if (_city.isNotEmpty || _country.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    [_city, _country]
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          // ── Top Tracks ────────────────────────────────────────
          if (_topTracks.isNotEmpty) ...[
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Top tracks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'See All',
                    style: TextStyle(
                        color: Color(0xFFFF5500), fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ..._topTracks.take(5).map((t) => _TrackRow(track: t)),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _followButton() {
    return ElevatedButton(
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
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(_isFollowing ? 'Following' : 'Follow'),
    );
  }

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
          BorderSide(color: Color(0xFFFF5500), width: 2.5),
        ),
      ),
      child: ClipOval(
        child: isDefaultAvatar
            ? Container(
                color: const Color(0xFF2A2A2A),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.6,
                    ),
                  ),
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
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: radius * 0.6,
                      ),
                    ),
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

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final double size;

  const _CircleIconBtn({required this.icon, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white70, size: size),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final Map<String, dynamic> track;
  const _TrackRow({required this.track});

  @override
  Widget build(BuildContext context) {
    final title = track['title'] as String? ?? '';
    final artistName = track['artistName'] as String? ??
        track['artist'] as String? ??
        track['displayName'] as String? ??
        '';
    final coverUrl =
        track['coverUrl'] as String? ?? track['thumbnailUrl'] as String?;
    final playCount =
        _safeInt(track['playCount'] ?? track['plays'] ?? track['playsCount']);
    final duration = _safeInt(track['duration']);
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    final durationStr = duration > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
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
                Row(
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.grey, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      '$playCount',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
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
        ],
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
