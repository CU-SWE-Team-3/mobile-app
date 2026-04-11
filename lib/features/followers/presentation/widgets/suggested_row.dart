import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/profile_navigation.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _SuggestedUser {
  final String id;
  final String displayName;
  final String permalink;
  final String? avatarUrl;
  final int followerCount;

  _SuggestedUser({
    required this.id,
    required this.displayName,
    required this.permalink,
    required this.avatarUrl,
    required this.followerCount,
  });

  factory _SuggestedUser.fromJson(Map<String, dynamic> json) {
    final fc = json['followerCount'];
    return _SuggestedUser(
      id: json['_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      permalink: json['permalink'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      followerCount: fc is int ? fc : int.tryParse(fc?.toString() ?? '') ?? 0,
    );
  }
}

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M followers';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K followers';
  return '$count followers';
}

// ── Widget ────────────────────────────────────────────────────────────────────

class SuggestedRow extends ConsumerStatefulWidget {
  final String? title;

  const SuggestedRow({super.key, this.title});

  @override
  ConsumerState<SuggestedRow> createState() => _SuggestedRowState();
}

class _SuggestedRowState extends ConsumerState<SuggestedRow> {
  List<_SuggestedUser> _users = [];
  final Map<String, bool> _followingMap = {};
  final Map<String, bool> _loadingMap = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggested();
  }

  Future<void> _fetchSuggested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('userId') ?? '';
      final response = await dioClient.dio
          .get('/network/suggested', queryParameters: {'page': 1, 'limit': 20});
      final raw = response.data['data'];
      final List<dynamic> data = (raw is List) ? raw : [];
      if (mounted) {
        setState(() {
          _users = data
              .map((e) => _SuggestedUser.fromJson(e as Map<String, dynamic>))
              .where((u) => u.id != myId)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('=== SUGGESTED FETCH ERROR: $e\n$st');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _toggleFollow(String userId) async {
    if (_loadingMap[userId] == true) return;
    final isFollowing = _followingMap[userId] ?? false;

    setState(() => _loadingMap[userId] = true);
    try {
      if (isFollowing) {
        await dioClient.dio.delete('/network/$userId/follow');
      } else {
        await dioClient.dio.post('/network/$userId/follow');
      }
      if (mounted) {
        setState(() => _followingMap[userId] = !isFollowing);
      }
    } on DioException {
      // silently ignore — button reverts to previous state
    } finally {
      if (mounted) setState(() => _loadingMap[userId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 210,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                )
              : _hasError
                  ? const Center(
                      child: Text(
                        "Couldn't load suggestions",
                        style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final isFollowing = _followingMap[user.id] ?? false;
                        final isButtonLoading = _loadingMap[user.id] ?? false;
                        return _UserCard(
                          user: user,
                          isFollowing: isFollowing,
                          isButtonLoading: isButtonLoading,
                          onToggle: () => _toggleFollow(user.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final _SuggestedUser user;
  final bool isFollowing;
  final bool isButtonLoading;
  final VoidCallback onToggle;

  const _UserCard({
    required this.user,
    required this.isFollowing,
    required this.isButtonLoading,
    required this.onToggle,
  });

  // Deterministic color from the user's display name initial
  Color get _fallbackColor {
    const colors = [
      Color(0xFF6C63FF), Color(0xFFE53935), Color(0xFF37474F),
      Color(0xFF00897B), Color(0xFF1E88E5), Color(0xFF8E24AA),
      Color(0xFF43A047), Color(0xFFFF5500),
    ];
    return colors[user.displayName.codeUnitAt(0) % colors.length];
  }

  bool _isDefaultAvatar(String? url) =>
      url == null || url.isEmpty || url.contains('default-avatar');

  @override
  Widget build(BuildContext context) {
    final showImage = !_isDefaultAvatar(user.avatarUrl);

    return GestureDetector(
      onTap: () => navigateToUserProfile(
        context,
        userId: user.id,
        permalink: user.permalink,
        displayName: user.displayName,
      ),
      child: Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 25,
            backgroundColor: _fallbackColor,
            child: showImage
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.avatarUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 10),

          // Display name
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),

          // Permalink
          Text(
            '@${user.permalink}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
          ),
          const SizedBox(height: 2),

          // Follower count
          Text(
            _formatCount(user.followerCount),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Follow / Following button
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              onPressed: isButtonLoading ? null : onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFollowing ? const Color(0xFFFF5500) : Colors.white,
                disabledBackgroundColor:
                    isFollowing ? const Color(0xFFFF5500) : Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: isButtonLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isFollowing ? Colors.white : Colors.black,
                      ),
                    )
                  : Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: isFollowing ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
