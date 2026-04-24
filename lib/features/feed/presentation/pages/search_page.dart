import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';

class _Genre {
  final String name;
  final String assetPath;
  final Color color;
  final int imageWidth;
  final int imageHeight;
  const _Genre(this.name, this.assetPath, this.color, this.imageWidth, this.imageHeight);
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const List<_Genre> _genres = [
    _Genre('Hip Hop & Rap', 'assets/images/HipHop_&_Rap.png', Color(0xFFFF5500), 502, 443),
    _Genre('Electronic',    'assets/images/Electronic.png',   Color(0xFF1A6EDD), 434, 575),
    _Genre('Pop',           'assets/images/Pop.png',          Color(0xFFDD1A8C), 431, 579),
    _Genre('R&B',           'assets/images/R&B.png',          Color(0xFF9B59B6), 495, 206),
    _Genre('Chill',         'assets/images/Chill.png',        Color(0xFF1AAD6E), 501, 212),
    _Genre('Party',         'assets/images/Party.png',        Color(0xFFDDAA1A), 500, 429),
  ];

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
                key: const ValueKey('search_field'),
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
                        child: CircularProgressIndicator(color: Color(0xFFFF5500)))
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
                                  key: const ValueKey('search_retry_button'),
                                  onPressed: () => _search(_lastQuery),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF5500)),
                                  child: const Text('Retry',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : !_hasSearched
                            ? _buildVibesGrid()
                            : _results.isEmpty
                                ? Center(
                                    child: Text(
                                      'No tracks found for "$_lastQuery"',
                                      style: TextStyle(
                                          color: Colors.grey[600], fontSize: 15),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _results.length,
                                    itemBuilder: (context, i) {
                                      final track = _results[i];
                                      final title =
                                          track['title'] as String? ?? 'Unknown';
                                      final artworkUrl =
                                          track['artworkUrl'] as String?;
                                      final duration =
                                          track['duration'] as int? ?? 0;
                                      final playCount =
                                          track['playCount'] as int? ?? 0;
                                      final artist =
                                          track['user'] as Map<String, dynamic>? ??
                                              track['artist']
                                                  as Map<String, dynamic>?;
                                      final artistName =
                                          artist?['displayName'] as String? ?? '';
                                      final hasArtwork = artworkUrl != null &&
                                          artworkUrl.isNotEmpty &&
                                          !artworkUrl.contains('default-artwork');

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: hasArtwork
                                                  ? CachedNetworkImage(
                                                      imageUrl: artworkUrl,
                                                      width: 56,
                                                      height: 56,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) =>
                                                          _artworkFallback(),
                                                    )
                                                  : _artworkFallback(),
                                            ),
                                            const SizedBox(width: 12),
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
                                                      fontWeight: FontWeight.w600,
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
                                                          Icons.play_arrow_rounded,
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

  Widget _buildVibesGrid() {
    const gap = 6.0;

    // left column:  Hip Hop & Rap, Pop, Chill
    // right column: Electronic, R&B, Party
    final left  = [_genres[0], _genres[2], _genres[4]];
    final right = [_genres[1], _genres[3], _genres[5]];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vibes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < left.length; i++) ...[
                      _buildGenreCard(left[i]),
                      if (i < left.length - 1) const SizedBox(height: gap),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < right.length; i++) ...[
                      _buildGenreCard(right[i]),
                      if (i < right.length - 1) const SizedBox(height: gap),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenreCard(_Genre genre) {
    return GestureDetector(
      onTap: () => context.push(
          '/search/genre/${Uri.encodeComponent(genre.name)}'),
      child: AspectRatio(
        aspectRatio: genre.imageWidth / genre.imageHeight,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              genre.assetPath,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _artworkFallback() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.music_note, color: Colors.white38, size: 24),
      );
}
