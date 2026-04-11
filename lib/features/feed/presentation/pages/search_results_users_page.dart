import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/profile_navigation.dart';

class SearchResultsUsersPage extends StatefulWidget {
  const SearchResultsUsersPage({super.key});

  @override
  State<SearchResultsUsersPage> createState() => _SearchResultsUsersPageState();
}

class _SearchResultsUsersPageState extends State<SearchResultsUsersPage> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  String _lastQuery = '';
  bool _isLoading = false;
  bool _hasError = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _hasSearched = true;
      _lastQuery = q;
    });
    try {
      final results = await Future.wait([
        dioClient.dio.get('/users/search',
            queryParameters: {'q': q, 'page': 1, 'limit': 20}),
        dioClient.dio.get('/network/blocked-users'),
      ]);

      final usersRaw = results[0].data['data'] as List? ?? [];
      final users = usersRaw.cast<Map<String, dynamic>>();

      final blockedRaw = results[1].data['data'];
      final blockedIds = (blockedRaw is List)
          ? blockedRaw.map((u) => u['_id'] as String).toSet()
          : <String>{};

      setState(() {
        _results =
            users.where((u) => !blockedIds.contains(u['_id'])).toList();
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
        title: const Text('People', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const ValueKey('search_users_field'),
              controller: _controller,
              autofocus: false,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFFF5500),
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search people...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _controller.text.isNotEmpty
                    ? GestureDetector(
                        key: const ValueKey('search_users_clear_button'),
                        onTap: () {
                          _controller.clear();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                            _hasError = false;
                          });
                        },
                        child: const Icon(Icons.close, color: Colors.white38),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // ── Results ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF5500)))
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Search failed. Please try again.',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              key: const ValueKey('search_users_retry_button'),
                              onPressed: () => _search(_lastQuery),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFFF5500)),
                              child: const Text('Retry',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : !_hasSearched
                        ? Center(
                            child: Text(
                              'Search for people',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16),
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: Text(
                                  'No people found for "$_lastQuery"',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 15),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _results.length,
                                itemBuilder: (context, i) {
                                  final user = _results[i];
                                  final displayName =
                                      user['displayName'] as String? ?? '';
                                  final avatarUrl =
                                      user['avatarUrl'] as String?;
                                  final permalink =
                                      user['permalink'] as String? ?? '';
                                  final userId =
                                      user['_id'] as String? ?? '';
                                  final followerCount =
                                      _safeInt(user['followerCount']);
                                  final initial = displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?';
                                  final isDefaultAvatar =
                                      avatarUrl == null ||
                                          avatarUrl.isEmpty ||
                                          avatarUrl
                                              .contains('default-avatar');

                                  return InkWell(
                                    key: const ValueKey('search_users_tile'),
                                    onTap: () {
                                      if (permalink.isNotEmpty) {
                                        navigateToUserProfile(
                                          context,
                                          userId: userId,
                                          permalink: permalink,
                                          displayName: displayName,
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor:
                                                Colors.grey[800],
                                            child: isDefaultAvatar
                                                ? Text(
                                                    initial,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18),
                                                  )
                                                : ClipOval(
                                                    child:
                                                        CachedNetworkImage(
                                                      imageUrl: avatarUrl,
                                                      width: 56,
                                                      height: 56,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_,
                                                              __,
                                                              ___) =>
                                                          Text(
                                                        initial,
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold,
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
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person,
                                                        color: Colors.grey,
                                                        size: 14),
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
                                        ],
                                      ),
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

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}
