import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
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
      final response = await dioClient.dio
          .get('/tracks/search', queryParameters: {'q': q, 'page': 1, 'limit': 20});
      final data = response.data['data'] as List;
      setState(() {
        _results = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on DioException {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: false,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white),
                cursorColor: const Color(0xFFFF5500),
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'Search tracks...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _controller.text.isNotEmpty
                      ? GestureDetector(
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

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (_hasSearched && _lastQuery.isNotEmpty) await _search(_lastQuery);
                },
                color: const Color(0xFFFF5500),
                backgroundColor: const Color(0xFF1A1A1A),
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
                                onPressed: () => _search(_lastQuery),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFFF5500)),
                                child: const Text('Retry',
                                    style:
                                        TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : !_hasSearched
                          ? Center(
                              child: Text(
                                'Search & Discover',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 16),
                              ),
                            )
                          : _results.isEmpty
                              ? Center(
                                  child: Text(
                                    'No tracks found for "$_lastQuery"',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 15),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _results.length,
                                  itemBuilder: (context, i) {
                                    final track = _results[i];
                                    final title =
                                        track['title'] as String? ??
                                            'Unknown';
                                    final artworkUrl =
                                        track['artworkUrl'] as String?;
                                    final duration =
                                        track['duration'] as int? ?? 0;
                                    final playCount =
                                        track['playCount'] as int? ?? 0;
                                    final artist =
                                        track['user'] as Map<String,
                                                dynamic>? ??
                                            track['artist'] as Map<String,
                                                dynamic>?;
                                    final artistName =
                                        artist?['displayName']
                                                as String? ??
                                            '';
                                    final hasArtwork = artworkUrl !=
                                            null &&
                                        artworkUrl.isNotEmpty &&
                                        !artworkUrl
                                            .contains('default-artwork');

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: Row(
                                        children: [
                                          // Artwork
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: hasArtwork
                                                ? CachedNetworkImage(
                                                    imageUrl: artworkUrl,
                                                    width: 56,
                                                    height: 56,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_,
                                                            __,
                                                            ___) =>
                                                        _artworkFallback(),
                                                  )
                                                : _artworkFallback(),
                                          ),
                                          const SizedBox(width: 12),
                                          // Title + artist
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                                if (artistName.isNotEmpty)
                                                  Text(
                                                    artistName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 13),
                                                  ),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        color: Colors.white38,
                                                        size: 13),
                                                    Text(
                                                      ' $playCount',
                                                      style: const TextStyle(
                                                          color: Colors.white38,
                                                          fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Duration
                                          Text(
                                            _formatDuration(duration),
                                            style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artworkFallback() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.music_note,
            color: Colors.white38, size: 24),
      );
}
