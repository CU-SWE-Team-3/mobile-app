import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../followers/presentation/widgets/follow_unfollow_button.dart';

class PublicProfilePage extends StatefulWidget {
  final String permalink;

  const PublicProfilePage({super.key, required this.permalink});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response =
          await dioClient.dio.get('/profile/${widget.permalink}');
      final user =
          response.data['data']['user'] as Map<String, dynamic>;
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } on DioException {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
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
          key: const ValueKey('profile_public_back_button'),
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
                        "Couldn't load profile",
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const ValueKey('profile_public_retry_button'),
                        onPressed: _fetchProfile,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5500)),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final user = _user!;
    final isPrivate = user['isPrivate'] == true;
    final displayName = user['displayName'] as String? ?? '';
    final permalink = user['permalink'] as String? ?? '';
    final avatarUrl = user['avatarUrl'] as String?;
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final isDefaultAvatar = avatarUrl == null ||
        avatarUrl.isEmpty ||
        avatarUrl.contains('default-avatar');

    if (isPrivate) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildAvatarSection(
                avatarUrl, initial, isDefaultAvatar, displayName, permalink),
            const SizedBox(height: 32),
            const Icon(Icons.lock_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              'This profile is private',
              style: TextStyle(color: Colors.grey[400], fontSize: 15),
            ),
          ],
        ),
      );
    }

    final coverUrl = user['coverUrl'] as String?;
    final bio = user['bio'] as String?;
    final city = user['city'] as String?;
    final country = user['country'] as String?;
    final followerCount = _safeInt(user['followerCount']);
    final followingCount = _safeInt(user['followingCount']);
    final genres = (user['genres'] as List?)?.cast<String>() ?? [];
    final userId = user['_id'] as String? ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover photo
          if (coverUrl != null)
            SizedBox(
              width: double.infinity,
              height: 160,
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[900],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[800],
                      child: isDefaultAvatar
                          ? Text(
                              initial,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28),
                            )
                          : ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: avatarUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Text(
                                  initial,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28),
                                ),
                              ),
                            ),
                    ),
                    const Spacer(),
                    if (userId.isNotEmpty)
                      FollowUnfollowButton(
                        userId: userId,
                        isFollowing: false,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Display name
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Permalink
                Text(
                  permalink,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),

                // Bio
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],

                // City + Country
                if ((city != null && city.isNotEmpty) ||
                    (country != null && country.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        [city, country]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(', '),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Follower / Following counts
                Row(
                  children: [
                    _StatChip(count: followerCount, label: 'Followers'),
                    const SizedBox(width: 24),
                    _StatChip(count: followingCount, label: 'Following'),
                  ],
                ),

                // Genres
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres
                        .map(
                          (g) => Chip(
                            label: Text(g,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            backgroundColor: const Color(0xFF1F1F1F),
                            side: const BorderSide(
                                color: Color(0xFFFF5500), width: 1),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(String? avatarUrl, String initial,
      bool isDefaultAvatar, String displayName, String permalink) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[800],
            child: isDefaultAvatar
                ? Text(
                    initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28),
                  )
                : ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Text(
                        initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          Text(
            permalink,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int count;
  final String label;

  const _StatChip({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      ],
    );
  }
}

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}
