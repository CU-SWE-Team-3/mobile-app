import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';

class GenreResultsPage extends StatefulWidget {
  final String genreName;
  const GenreResultsPage({super.key, required this.genreName});

  @override
  State<GenreResultsPage> createState() => _GenreResultsPageState();
}

class _GenreResultsPageState extends State<GenreResultsPage> {
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response = await dioClient.dio.get(
        '/tracks/search',
        queryParameters: {'q': widget.genreName, 'page': 1, 'limit': 20},
      );
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.genreName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
                        'Failed to load tracks. Please try again.',
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetch,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5500)),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        'No tracks found for "${widget.genreName}"',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      color: const Color(0xFFFF5500),
                      backgroundColor: const Color(0xFF1A1A1A),
                      child: ListView.builder(
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
                                  track['artist'] as Map<String, dynamic>?;
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
                                      color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        },
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
