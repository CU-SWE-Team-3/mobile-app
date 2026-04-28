import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_provider.dart';

class GenreResultsPage extends ConsumerStatefulWidget {
  final String genreName;
  const GenreResultsPage({super.key, required this.genreName});

  @override
  ConsumerState<GenreResultsPage> createState() => _GenreResultsPageState();
}

class _GenreResultsPageState extends ConsumerState<GenreResultsPage> {
  List<_GenreTrack> _results = [];
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
        _results = data
            .whereType<Map<String, dynamic>>()
            .map(_GenreTrack.fromJson)
            .where((track) => track.id.isNotEmpty)
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

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _playFrom(int index) {
    final playable = _results.where((track) => track.hlsUrl.isNotEmpty).toList();
    if (playable.isEmpty) return;

    final tapped = _results[index];
    final startIndex = playable.indexWhere((track) => track.id == tapped.id);
    ref.read(playerProvider.notifier).playQueue(
          playable.map((track) => track.toPlayerTrack()).toList(),
          startIndex: startIndex < 0 ? 0 : startIndex,
        );
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
                          final hasArtwork = track.artworkUrl.isNotEmpty &&
                              !track.artworkUrl.contains('default-artwork');

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: GestureDetector(
                              onTap: track.hlsUrl.isEmpty ? null : () => _playFrom(i),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: hasArtwork
                                        ? CachedNetworkImage(
                                            imageUrl: track.artworkUrl,
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
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (track.artistName.isNotEmpty)
                                          Text(
                                            track.artistName,
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
                                              ' ${track.playCount}',
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
                                    _formatDuration(track.duration),
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 13),
                                  ),
                                ],
                              ),
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

class _GenreTrack {
  final String id;
  final String permalink;
  final String title;
  final String artistName;
  final String hlsUrl;
  final String artworkUrl;
  final int duration;
  final int playCount;
  final List<int>? waveform;

  const _GenreTrack({
    required this.id,
    required this.permalink,
    required this.title,
    required this.artistName,
    required this.hlsUrl,
    required this.artworkUrl,
    required this.duration,
    required this.playCount,
    this.waveform,
  });

  factory _GenreTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['user'] as Map<String, dynamic>? ??
        json['artist'] as Map<String, dynamic>? ??
        const {};
    final media = json['media'] as Map<String, dynamic>?;
    return _GenreTrack(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      permalink: json['permalink'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artistName: artist['displayName'] as String? ??
          artist['username'] as String? ??
          '',
      hlsUrl: json['hlsUrl'] as String? ??
          media?['hlsUrl'] as String? ??
          json['audioUrl'] as String? ??
          '',
      artworkUrl: (json['artworkUrl'] ?? json['artwork_url'] ?? '') as String,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] as num?)?.toInt() ??
          (json['playback_count'] as num?)?.toInt() ??
          0,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }

  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: id,
        title: title,
        artist: artistName,
        audioUrl: hlsUrl,
        coverUrl: artworkUrl.isEmpty ? null : artworkUrl,
        duration: duration > 0 ? Duration(seconds: duration) : null,
        trackPermalink: permalink,
      );
}
