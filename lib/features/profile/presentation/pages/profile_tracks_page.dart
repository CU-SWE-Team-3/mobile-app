import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

// ── Local model ───────────────────────────────────────────────────────────────

class _MyTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artworkUrl;
  final String hlsUrl;
  final List<int>? waveform;
  final Duration? duration;

  const _MyTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artworkUrl,
    required this.hlsUrl,
    this.artistId,
    this.waveform,
    this.duration,
  });

  factory _MyTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final durationRaw = json['duration'];
    return _MyTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artistId: artist['_id'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String? ?? '',
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      duration: durationRaw != null
          ? Duration(seconds: (durationRaw as num).toInt())
          : null,
    );
  }

  PlayerTrack toPlayerTrack() => PlayerTrack(
        id: id,
        title: title,
        artist: artistName,
        artistId: artistId,
        audioUrl: hlsUrl,
        coverUrl: artworkUrl,
        waveform: waveform,
        duration: duration,
      );
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ProfileTracksPage extends ConsumerStatefulWidget {
  const ProfileTracksPage({super.key});

  @override
  ConsumerState<ProfileTracksPage> createState() => _ProfileTracksPageState();
}

class _ProfileTracksPageState extends ConsumerState<ProfileTracksPage> {
  static const _bg = Color(0xFF111111);

  List<_MyTrack> _tracks = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchTracks();
  }

  Future<void> _fetchTracks() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/tracks/my-tracks');
      final data = response.data['data'] as List<dynamic>;
      final tracks = data
          .cast<Map<String, dynamic>>()
          .map(_MyTrack.fromJson)
          .where((t) => t.hlsUrl.isNotEmpty)
          .toList();
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _playFrom(int index) {
    if (_tracks.isEmpty) return;
    final queue = _tracks.map((t) => t.toPlayerTrack()).toList();
    ref.read(playerProvider.notifier).playQueue(queue, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('profile_tracks_back_button'),
                    onTap: () =>
                        context.canPop() ? context.pop() : null,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tracks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    key: const ValueKey('profile_tracks_cast_button'),
                    onTap: () {},
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cast_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── shuffle + play row ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  const Spacer(),
                  // Shuffle
                  GestureDetector(
                    key: const ValueKey('profile_tracks_shuffle_button'),
                    onTap: () {
                      if (_tracks.isEmpty) return;
                      _playFrom(Random().nextInt(_tracks.length));
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shuffle_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Play
                  GestureDetector(
                    key: const ValueKey('profile_tracks_play_all_button'),
                    onTap: () => _playFrom(0),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 28),
                    ),
                  ),
                ],
              ),
            ),

            // ── body ─────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Failed to load tracks',
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 12),
                              TextButton(
                                key: const ValueKey(
                                    'profile_tracks_retry_button'),
                                onPressed: _fetchTracks,
                                child: const Text('Retry',
                                    style:
                                        TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : _tracks.isEmpty
                          ? const Center(
                              child: Text('No tracks yet',
                                  style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: _tracks.length,
                              itemBuilder: (_, i) => _TrackTile(
                                track: _tracks[i],
                                onTap: () => _playFrom(i),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Track tile ────────────────────────────────────────────────────────────────

class _TrackTile extends StatelessWidget {
  final _MyTrack track;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withOpacity(0.55);
    final duration = track.duration;
    final durationLabel = duration != null
        ? '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'
        : '';

    return GestureDetector(
      key: const ValueKey('profile_tracks_tile'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (track.artworkUrl != null && track.artworkUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: track.artworkUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 14),
            // Title + artist + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(track.artistName,
                      style: TextStyle(color: sub, fontSize: 13)),
                  if (durationLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(durationLabel,
                        style: TextStyle(color: sub, fontSize: 12)),
                  ],
                ],
              ),
            ),
            // More button
            GestureDetector(
              key: const ValueKey('profile_tracks_more_button'),
              onTap: () {},
              child: Icon(Icons.more_vert_rounded, color: sub, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF6699BB),
        child: const Icon(Icons.music_note, color: Colors.white70, size: 30),
      );
}
