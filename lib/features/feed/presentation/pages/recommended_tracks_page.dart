import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/player/domain/entities/player_track.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

class _Track {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
  final String? artworkUrl;
  final String hlsUrl;
  final List<int>? waveform;

  const _Track({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artistId,
    required this.artistPermalink,
    required this.artworkUrl,
    required this.hlsUrl,
    required this.waveform,
  });

  factory _Track.fromJson(Map<String, dynamic> json) {
    final target = json['target'] as Map<String, dynamic>?;
    final track = target ?? json;
    final artist = track['artist'] as Map<String, dynamic>? ?? {};
    final audio = track['audio'] as Map<String, dynamic>?;
    return _Track(
      id: track['_id'] as String? ?? '',
      title: track['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artistId: artist['_id'] as String?,
      artistPermalink: artist['permalink'] as String?,
      artworkUrl: track['artworkUrl'] as String?,
      hlsUrl: track['hlsUrl'] as String? ?? audio?['hlsUrl'] as String? ?? '',
      waveform: (track['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

class RecommendedTracksPage extends ConsumerStatefulWidget {
  const RecommendedTracksPage({super.key});

  @override
  ConsumerState<RecommendedTracksPage> createState() =>
      _RecommendedTracksPageState();
}

class _RecommendedTracksPageState extends ConsumerState<RecommendedTracksPage> {
  List<_Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response = await dioClient.dio.get('/discovery/recommended');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final rawTracks = data['tracks'] as List<dynamic>? ?? [];
      final tracks = rawTracks
          .map((e) => _Track.fromJson(e as Map<String, dynamic>))
          .where((track) => track.id.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _play(int index) {
    final playable = _tracks.where((t) => t.hlsUrl.isNotEmpty).toList();
    if (playable.isEmpty) return;

    final queue = playable
        .map((t) => PlayerTrack(
              id: t.id,
              title: t.title,
              artist: t.artistName,
              artistId: t.artistId,
              artistPermalink: t.artistPermalink,
              audioUrl: t.hlsUrl,
              coverUrl: t.artworkUrl,
              waveform: t.waveform,
            ))
        .toList();

    final tapped = _tracks[index];
    final startIndex = playable.indexWhere((t) => t.id == tapped.id);

    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: startIndex < 0 ? 0 : startIndex,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: const Text(
          'More of what you like',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6A2A)),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load tracks',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }
    if (_tracks.isEmpty) {
      return const Center(
        child: Text(
          'No recommendations yet',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
        final track = _tracks[index];
        return GestureDetector(
          onTap: () => _play(index),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _artwork(track.artworkUrl),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                track.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _artwork(String? url) {
    if (url == null || url.isEmpty || !url.startsWith('http')) {
      return _placeholder();
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF3A3A3A),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white38, size: 32),
      ),
    );
  }
}
