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
  final String? routeOverride;
  const _Genre(
    this.name,
    this.assetPath,
    this.color,
    this.imageWidth,
    this.imageHeight,
    [this.routeOverride]);
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _screenInset = 16.0;
  static const _sectionGap = 8.0;

  List<_Genre> get _genres => const [
        _Genre('At Home', 'assets/images/At_home.png', Color(0xFFFF8F00), 556, 274),
        _Genre(
          'Healing Era',
          'assets/images/Healing_era.png',
          Color(0xFF00897B),
          511,
          488,
        ),
        _Genre('Study', 'assets/images/Study.png', Color(0xFFFF5CA8), 501, 488),
        _Genre('Folk', 'assets/images/Folk.png', Color(0xFFFF8A5B), 501, 729),
        _Genre('Indie', 'assets/images/Indie.png', Color(0xFF5B8CFF), 501, 729),
        _Genre('Soul', 'assets/images/Soul.png', Color(0xFF23B7B3), 501, 488),
        _Genre('Country', 'assets/images/Country.png', Color(0xFFFF8A5B), 556, 274),
        _Genre('Latin', 'assets/images/Latin.png', Color(0xFFD66AC2), 501, 488),
        _Genre('Rock', 'assets/images/Rock.png', Color(0xFFFF5C7A), 556, 274),
        _Genre('Workout', 'assets/images/Workout.png', Color(0xFFE53935), 510, 489),
        _Genre('Hip Hop & Rap', 'assets/images/HipHop_&_Rap.png', Color(0xFFFF5500), 502, 443),
        _Genre('Electronic', 'assets/images/Electronic.png', Color(0xFF1A6EDD), 434, 575),
        _Genre('Pop', 'assets/images/Pop.png', Color(0xFFDD1A8C), 431, 579),
        _Genre('R&B', 'assets/images/R&B.png', Color(0xFF9B59B6), 495, 206),
        _Genre('Chill', 'assets/images/Chill.png', Color(0xFF1AAD6E), 501, 212),
        _Genre('Party', 'assets/images/Party.png', Color(0xFFDDAA1A), 500, 429),
        _Genre('Techno', 'assets/images/Techno.png', Color(0xFF5C6BC0), 416, 600),
        _Genre('House', 'assets/images/House.png', Color(0xFF7B1FA2), 416, 600),
        _Genre('Feel Good', 'assets/images/Feel_good.png', Color(0xFF43A047), 548, 264),
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
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _screenInset,
                _screenInset,
                _screenInset,
                _sectionGap,
              ),
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
                  fillColor: const Color(0xFF343434),
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
    const gap = 2.0;
    const leftTopGap = 0.0;

    final left  = [for (int i = 0; i < _genres.length; i += 2) _genres[i]];
    final right = [for (int i = 1; i < _genres.length; i += 2) _genres[i]];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        _screenInset,
        _sectionGap,
        _screenInset,
        _screenInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vibes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
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
                      if (i < left.length - 1)
                        SizedBox(height: i == 0 ? leftTopGap : gap),
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
    final route = genre.routeOverride ??
        (genre.name == 'Hip Hop & Rap'
        ? '/home/genre/hiphop'
        : genre.name == 'Folk'
            ? '/home/genre/folk'
        : genre.name == 'Indie'
            ? '/home/genre/indie'
        : genre.name == 'House'
            ? '/home/genre/house'
        : genre.name == 'Electronic'
            ? '/home/genre/electronic'
            : genre.name == 'Pop'
                ? '/home/genre/pop'
                : genre.name == 'R&B'
                    ? '/home/genre/rnb'
                    : genre.name == 'Chill'
                        ? '/home/genre/chill'
                        : '/search/genre/${Uri.encodeComponent(genre.name)}');

    return GestureDetector(
      onTap: () => context.push(route),
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
