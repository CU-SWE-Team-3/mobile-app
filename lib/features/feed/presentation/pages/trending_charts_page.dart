import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';

class TrendingChartsPage extends StatefulWidget {
  const TrendingChartsPage({super.key});

  @override
  State<TrendingChartsPage> createState() => _TrendingChartsPageState();
}

class _TrendingChartsPageState extends State<TrendingChartsPage> {
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchTrending();
  }

  Future<void> _fetchTrending() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response =
          await dioClient.dio.get('/tracks/trending?page=1&limit=20');
      final data = response.data['data'] as List;
      setState(() {
        _tracks = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on DioException {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _formatPlays(int plays) {
    if (plays >= 1000000) return '${(plays / 1000000).toStringAsFixed(1)}M';
    if (plays >= 1000) return '${(plays / 1000).toStringAsFixed(1)}K';
    return plays.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Trending Charts',
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
                        "Couldn't load trending tracks",
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchTrending,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5500)),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _tracks.isEmpty
                  ? Center(
                      child: Text(
                        'No trending tracks yet',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tracks.length,
                      itemBuilder: (context, i) {
                        final track = _tracks[i];
                        final title =
                            track['title'] as String? ?? 'Unknown';
                        final artworkUrl =
                            track['artworkUrl'] as String?;
                        final playCount =
                            track['playCount'] as int? ?? 0;
                        final genre =
                            track['genre'] as String? ?? '';
                        final artist =
                            track['user'] as Map<String, dynamic>?;
                        final artistName = artist?['displayName']
                                as String? ??
                            track['artist']?['displayName'] as String? ??
                            '';
                        final hasArtwork = artworkUrl != null &&
                            artworkUrl.isNotEmpty &&
                            !artworkUrl.contains('default-artwork');

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              // Rank number
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: i < 3
                                        ? const Color(0xFFFF5500)
                                        : Colors.white54,
                                    fontSize: i < 3 ? 18 : 15,
                                    fontWeight: i < 3
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Artwork
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
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
                              // Title + artist
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 13),
                                      ),
                                    if (genre.isNotEmpty)
                                      Text(
                                        genre,
                                        style: const TextStyle(
                                            color: Color(0xFFFF5500),
                                            fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              // Play count
                              Row(
                                children: [
                                  const Icon(Icons.play_arrow_rounded,
                                      color: Colors.white38, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    _formatPlays(playCount),
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
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
