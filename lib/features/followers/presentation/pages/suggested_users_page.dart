import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';

class SuggestedUsersPage extends StatefulWidget {
  const SuggestedUsersPage({super.key});

  @override
  State<SuggestedUsersPage> createState() => _SuggestedUsersPageState();
}

class _SuggestedUsersPageState extends State<SuggestedUsersPage> {
  List<Map<String, dynamic>> _users = [];
  final Set<String> _followingIds = {};
  final Set<String> _loadingIds = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggested();
  }

  Future<void> _fetchSuggested() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('userId') ?? '';
      final response = await dioClient.dio
          .get('/network/suggested', queryParameters: {'page': 1, 'limit': 20});
      final raw = response.data['data'];
      final all = (raw is List) ? raw.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
      setState(() {
        _users = all.where((u) => u['_id'] != myId).toList();
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
        title: const Text(
          'Suggested Users',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                        "Couldn't load suggestions",
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchSuggested,
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
                        'No suggestions right now',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, i) {
                        final user = _users[i];
                        final id = user['_id'] as String;
                        final displayName =
                            user['displayName'] as String? ?? '';
                        final avatarUrl = user['avatarUrl'] as String?;
                        final followerCountRaw = user['followerCount'];
                        final followerCount = followerCountRaw is int
                            ? followerCountRaw
                            : int.tryParse(followerCountRaw?.toString() ?? '') ?? 0;
                        final initial = displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?';
                        final isDefaultAvatar = avatarUrl == null ||
                            avatarUrl.isEmpty ||
                            avatarUrl.contains('default-avatar');
                        final isFollowing = _followingIds.contains(id);
                        final isButtonLoading = _loadingIds.contains(id);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
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
                                          imageUrl: avatarUrl,
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.person,
                                            color: Colors.grey, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$followerCount Followers',
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12),
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
                                    backgroundColor: isFollowing
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                  ),
                                  onPressed:
                                      isButtonLoading ? null : () => _toggleFollow(id),
                                  child: isButtonLoading
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isFollowing
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        )
                                      : Text(
                                          isFollowing ? 'Following' : 'Follow',
                                          style: TextStyle(
                                            color: isFollowing
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
