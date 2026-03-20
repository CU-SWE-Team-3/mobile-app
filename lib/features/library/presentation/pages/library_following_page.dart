import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/user_session.dart';

// ─────────────────────────────────────────────
//  LIBRARY FOLLOWING PAGE
// ─────────────────────────────────────────────
class LibraryFollowingPage extends ConsumerStatefulWidget {
  const LibraryFollowingPage({super.key});

  @override
  ConsumerState<LibraryFollowingPage> createState() =>
      _LibraryFollowingPageState();
}

class _LibraryFollowingPageState extends ConsumerState<LibraryFollowingPage> {
  List<Map<String, dynamic>> _users = [];
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
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }
      final response = await dioClient.dio.get(
        '/network/$userId/following',
        queryParameters: {'page': 1, 'limit': 20},
      );
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
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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

                    // ── "People who follow you back" banner ──────────────
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrueFriendsPage(),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 15),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                      BorderSide(color: Colors.white54, width: 1.5)),
                                ),
                                child: Icon(Icons.people_outline,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
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
                                    'See your true friends',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Following list ───────────────────────────────────
                    Expanded(
                      child: _users.isEmpty
                          ? Center(
                              child: Text(
                                'Not following anyone yet',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 15),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _users.length,
                              itemBuilder: (context, i) {
                                final user = _users[i];
                                final id = user['_id'] as String;
                                final displayName =
                                    user['displayName'] as String? ?? '';
                                final avatarUrl =
                                    user['avatarUrl'] as String?;
                                final followerCount =
                                    user['followerCount'] as int? ?? 0;
                                final isFollowing =
                                    _followingIds.contains(id);
                                final isButtonLoading =
                                    _loadingIds.contains(id);
                                final initial = displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?';
                                final isDefaultAvatar = avatarUrl == null ||
                                    avatarUrl.isEmpty ||
                                    avatarUrl.contains('default-avatar');

                                return _UserTile(
                                  displayName: displayName,
                                  avatarUrl: avatarUrl,
                                  isDefaultAvatar: isDefaultAvatar,
                                  initial: initial,
                                  followerCount: followerCount,
                                  isFollowing: isFollowing,
                                  isButtonLoading: isButtonLoading,
                                  onToggle: () => _toggleFollow(id),
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
//  TRUE FRIENDS PAGE (placeholder — API doesn't return followsYouBack)
// ─────────────────────────────────────────────
class TrueFriendsPage extends StatelessWidget {
  const TrueFriendsPage({super.key});

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
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Your true friends',
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
      body: Center(
        child: Text(
          'No mutual followers yet',
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REUSABLE USER TILE
// ─────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final bool isDefaultAvatar;
  final String initial;
  final int followerCount;
  final bool isFollowing;
  final bool isButtonLoading;
  final VoidCallback onToggle;

  const _UserTile({
    required this.displayName,
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.initial,
    required this.followerCount,
    required this.isFollowing,
    required this.isButtonLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[800],
            child: isDefaultAvatar
                ? Text(
                    initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  )
                : ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Text(
                        initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              onPressed: isButtonLoading ? null : onToggle,
              child: isButtonLoading
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
    );
  }
}
