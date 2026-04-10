import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/user_session.dart';

class FollowersListPage extends StatefulWidget {
  final String? targetUserId;
  const FollowersListPage({super.key, this.targetUserId});

  @override
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage> {
  List<Map<String, dynamic>> _users = [];
  final Set<String> _followingIds = {};
  final Set<String> _loadingIds = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchFollowers();
  }

  Future<void> _fetchFollowers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final myId = await UserSession.getUserId();
      if (myId == null) throw Exception('Not logged in');
      final fetchId = widget.targetUserId ?? myId;

      // Fetch followers list
      final followersResponse =
          await dioClient.dio.get('/network/$fetchId/followers?page=1&limit=20');
      final followersData = followersResponse.data['data'] as List;

      // Fetch current user's following list to determine which followers are already followed back
      final followingResponse = await dioClient.dio
          .get('/network/$myId/following?page=1&limit=999');
      final followingData = followingResponse.data['data'] as List;

      // make a set of following user IDs to easily check if a follower is already followed back
      final followingIds = followingData
          .map((user) => user['_id'] as String?)
          .whereType<String>()
          .toSet();

      setState(() {
        _users = followersData.cast<Map<String, dynamic>>();
        _followingIds.clear();
        _followingIds.addAll(followingIds);
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
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Followers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Icon(Icons.cast, color: Colors.white),
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
                        "Couldn't load followers",
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchFollowers,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5500)),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? Center(
                      child: Text(
                        'No followers yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, i) {
                        final user = _users[i];
                        final id = user['_id'] as String;
                        return _FollowerTile(
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

class _FollowerTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _FollowerTile({
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
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
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
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
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
