import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/user_session.dart';
import '../../../../core/utils/profile_navigation.dart';

class FollowingListPage extends StatefulWidget {
  final String? targetUserId;
  const FollowingListPage({super.key, this.targetUserId});

  @override
  State<FollowingListPage> createState() => _FollowingListPageState();
}

class _FollowingListPageState extends State<FollowingListPage> {
  List<Map<String, dynamic>> _users = [];
  // All users in the following list are already followed by definition
  final Set<String> _followingIds = {};
  final Set<String> _loadingIds = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchFollowing();
  }

  Future<void> _fetchFollowing() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final userId = await UserSession.getUserId();
      if (userId == null) throw Exception('Not logged in');
      final fetchId = widget.targetUserId ?? userId;
      final response = await dioClient.dio
          .get('/network/$fetchId/following?page=1&limit=20');
      final data = response.data['data'] as List;
      final users = data.cast<Map<String, dynamic>>();
      setState(() {
        _users = users;
        _followingIds.addAll(users.map((u) => u['_id'] as String));
        _isLoading = false;
      });
    } on DioException {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _navigateToProfile(
    BuildContext context, {
    required String userId,
    required String permalink,
    required String displayName,
  }) async {
    final myId = await UserSession.getUserId() ?? '';
    if (!context.mounted) return;
    if (myId.isNotEmpty && myId == userId) {
      context.push('/profile');
    } else {
      context.push(
        '/user/$permalink',
        extra: {'displayName': displayName, 'userId': userId},
      );
    }
  }

  Future<void> _toggleFollow(String userId) async {
    if (_loadingIds.contains(userId)) return;
    final isFollowing = _followingIds.contains(userId);
    setState(() => _loadingIds.add(userId));
    try {
      if (isFollowing) {
        await dioClient.dio.delete('/network/$userId/follow');
        setState(() => _followingIds.remove(userId));
      } else {
        await dioClient.dio.post('/network/$userId/follow');
        setState(() => _followingIds.add(userId));
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
      if (mounted) setState(() => _loadingIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
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
        title: const Text(
          'Following',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Couldn't load following",
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchFollowing,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5500)),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 12),
                    if (widget.targetUserId == null)
                    // "True friends" banner
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const _TrueFriendsPage()),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 15),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white54, width: 1.5),
                              ),
                              child: const Icon(Icons.people_outline,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'People who follow you back',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'see your true friends',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    ),
                    if (widget.targetUserId == null)
                    const SizedBox(height: 12),
                    Expanded(
                      child: _users.isEmpty
                          ? Center(
                              child: Text(
                                "You're not following anyone yet",
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 15),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _users.length,
                              itemBuilder: (context, i) {
                                final user = _users[i];
                                final id = user['_id'] as String;
                                return _UserTile(
                                  user: user,
                                  isFollowing: _followingIds.contains(id),
                                  isLoading: _loadingIds.contains(id),
                                  onToggle: () => _toggleFollow(id),
                                  onTap: () => _navigateToProfile(
                                    context,
                                    userId: id,
                                    permalink: user['permalink'] as String? ?? id,
                                    displayName: user['displayName'] as String? ?? '',
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────
//  TRUE FRIENDS PAGE (mutual followers)
// ─────────────────────────────────────────────
class _TrueFriendsPage extends StatefulWidget {
  const _TrueFriendsPage();

  @override
  State<_TrueFriendsPage> createState() => _TrueFriendsPageState();
}

class _TrueFriendsPageState extends State<_TrueFriendsPage> {
  List<Map<String, dynamic>> _mutuals = [];
  final Set<String> _followingIds = {};
  final Set<String> _loadingIds = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchMutuals();
  }

  Future<void> _fetchMutuals() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final myId = await UserSession.getUserId();
      if (myId == null) throw Exception('Not logged in');

      final results = await Future.wait([
        dioClient.dio.get('/network/$myId/followers?page=1&limit=100'),
        dioClient.dio.get('/network/$myId/following?page=1&limit=100'),
      ]);

      final followersData = results[0].data['data'] as List;
      final followingData = results[1].data['data'] as List;

      final followingIds = followingData
          .map((u) => u['_id'] as String?)
          .whereType<String>()
          .toSet();

      final mutuals = followersData
          .cast<Map<String, dynamic>>()
          .where((u) => followingIds.contains(u['_id'] as String?))
          .toList();

      setState(() {
        _mutuals = mutuals;
        _followingIds.clear();
        _followingIds.addAll(mutuals.map((u) => u['_id'] as String));
        _isLoading = false;
      });
    } on DioException catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _navigateToProfile(
    BuildContext context, {
    required String userId,
    required String permalink,
    required String displayName,
  }) async {
    final myId = await UserSession.getUserId() ?? '';
    if (!context.mounted) return;
    if (myId.isNotEmpty && myId == userId) {
      context.push('/profile');
    } else {
      context.push(
        '/user/$permalink',
        extra: {'displayName': displayName, 'userId': userId},
      );
    }
  }

  Future<void> _toggleFollow(String userId) async {
    if (_loadingIds.contains(userId)) return;
    final isFollowing = _followingIds.contains(userId);
    setState(() => _loadingIds.add(userId));
    try {
      if (isFollowing) {
        await dioClient.dio.delete('/network/$userId/follow');
        setState(() => _followingIds.remove(userId));
      } else {
        await dioClient.dio.post('/network/$userId/follow');
        setState(() => _followingIds.add(userId));
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
      if (mounted) setState(() => _loadingIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.grey[900], shape: BoxShape.circle),
            child:
                const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Your true friends',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.cast, color: Colors.white),
              onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Couldn't load mutual followers",
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchMutuals,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5500)),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _mutuals.isEmpty
                  ? Center(
                      child: Text(
                        'No mutual followers yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _mutuals.length,
                      itemBuilder: (context, i) {
                        final user = _mutuals[i];
                        final id = user['_id'] as String;
                        return _UserTile(
                          user: user,
                          isFollowing: _followingIds.contains(id),
                          isLoading: _loadingIds.contains(id),
                          onToggle: () => _toggleFollow(id),
                          onTap: () => _navigateToProfile(
                            context,
                            userId: id,
                            permalink: user['permalink'] as String? ?? id,
                            displayName: user['displayName'] as String? ?? '',
                          ),
                        );
                      },
                    ),
    );
  }
}

// ─────────────────────────────────────────────
//  REUSABLE USER TILE
// ─────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.isFollowing,
    required this.isLoading,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = user['displayName'] as String? ?? '';
    final avatarUrl = user['avatarUrl'] as String?;
    final followerCount = user['followerCount'] as int? ?? 0;
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final isDefaultAvatar = avatarUrl == null ||
        avatarUrl.isEmpty ||
        avatarUrl.contains('default-avatar');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              child: isDefaultAvatar
                  ? Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18))
                  : ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Text(initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                    ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        '$followerCount Followers',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              width: 110,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFollowing ? Colors.grey[800] : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: isLoading ? null : onToggle,
                child: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isFollowing ? Colors.white : Colors.black,
                        ),
                      )
                    : Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: isFollowing ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
