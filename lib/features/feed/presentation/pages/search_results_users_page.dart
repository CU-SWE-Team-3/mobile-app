import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/profile_navigation.dart';
import '../../../search/data/search_repository.dart';
import '../../../search/domain/entities/search_result.dart';

class SearchResultsUsersPage extends StatefulWidget {
  const SearchResultsUsersPage({super.key});

  @override
  State<SearchResultsUsersPage> createState() => _SearchResultsUsersPageState();
}

class _SearchResultsUsersPageState extends State<SearchResultsUsersPage> {
  final _controller = TextEditingController();
  List<SearchResultUser> _results = [];
  String _lastQuery = '';
  bool _isLoading = false;
  bool _hasError = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Fetched in parallel with the main search; failure is silently swallowed so
  // a broken blocked-users endpoint never hides valid search results.
  Future<Set<String>> _fetchBlockedIds() async {
    try {
      final response = await dioClient.dio.get('/network/blocked-users');
      final raw = response.data['data'];
      if (raw is List) {
        return raw.map((u) => u['_id'] as String).toSet();
      }
    } on DioException {
      // proceed with empty set
    }
    return {};
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
      final repo = SearchRepository(dioClient.dio);
      // Run both in parallel; _fetchBlockedIds never throws.
      final rawResults = await Future.wait<Object?>([
        repo.globalSearch(q),
        _fetchBlockedIds(),
      ]);

      final searchResult = rawResults[0] as SearchResults;
      final blockedIds = rawResults[1] as Set<String>;

      setState(() {
        _results = searchResult.users
            .where((u) => !blockedIds.contains(u.id))
            .toList();
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
      key: const ValueKey('search_users_scaffold'),
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
              key: const ValueKey('search_field'),
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
                        key: const ValueKey('search_clear_button'),
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
                    key: ValueKey('search_users_loading'),
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF5500)))
                : _hasError
                    ? Center(
                        key: const ValueKey('search_users_error'),
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
                              key: const ValueKey('search_retry_button'),
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
                            key: const ValueKey('search_users_prompt'),
                            child: Text(
                              'Search for people',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16),
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                key: const ValueKey('search_users_no_results'),
                                child: Text(
                                  'No people found for "$_lastQuery"',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 15),
                                ),
                              )
                            : ListView.builder(
                                key: const ValueKey('search_users_list'),
                                itemCount: _results.length,
                                itemBuilder: (context, i) {
                                  final user = _results[i];
                                  final isDefaultAvatar =
                                      user.avatarUrl == null ||
                                          user.avatarUrl!.isEmpty ||
                                          user.avatarUrl!
                                              .contains('default-avatar');
                                  final initial =
                                      user.displayName.isNotEmpty
                                          ? user.displayName[0]
                                              .toUpperCase()
                                          : '?';

                                  return InkWell(
                                    key: ValueKey('search_users_tile_${user.id}'),
                                    onTap: () {
                                      if (user.permalink?.isNotEmpty ==
                                          true) {
                                        navigateToUserProfile(
                                          context,
                                          userId: user.id,
                                          permalink: user.permalink!,
                                          displayName: user.displayName,
                                        );
                                      }
                                    },
                                    child: Padding(
                                      key: const ValueKey('search_user_tile'),
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
                                                      imageUrl:
                                                          user.avatarUrl!,
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
                                                  user.displayName,
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
                                                      '${user.followerCount} Followers',
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
