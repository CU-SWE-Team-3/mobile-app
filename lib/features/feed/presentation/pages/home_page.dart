import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/followers/presentation/widgets/suggested_row.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _FeedTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final int playCount;
  final String? hlsUrl;
  final List<int>? waveform;

  _FeedTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artworkUrl,
    required this.playCount,
    this.hlsUrl,
    this.waveform,
  });

  factory _FeedTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    return _FeedTrack(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      playCount: json['playCount'] as int? ?? 0,
      hlsUrl: json['hlsUrl'] as String?,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

String _formatPlayCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M plays';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K plays';
  return '$count plays';
}

// ── Page ──────────────────────────────────────────────────────────────────────

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const List<String> _genres = [
    'Electronic', 'Folk', 'House', 'Techno', 'Pop',
    'Hip-Hop', 'Jazz', 'Classical', 'R&B', 'Metal',
  ];

  int _selectedGenreIndex = 0;

  List<_FeedTrack> _tracks = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSuggestedDialog();
    });
  }

  Future<void> _maybeShowSuggestedDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('suggested_dialog_shown') ?? false;
    if (alreadyShown || !mounted) return;
    await prefs.setBool('suggested_dialog_shown', true);
    if (mounted) _showSuggestedDialog(context);
  }

  Future<void> _fetchFeed() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final response = await dioClient.dio.get('/network/feed');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      if (mounted) {
        setState(() {
          _tracks = data
              .map((e) => _FeedTrack.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _showSuggestedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'People you might like',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF999999)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SuggestedRow(title: null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)),
        ),
      );
    }

    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              const Text(
                'Couldn\'t load feed',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _fetchFeed,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFFFF5500), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Follow some artists to see their tracks here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF999999), fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      children: _tracks.asMap().entries.map((entry) => _TrackRow(
        track: entry.value,
        allTracks: _tracks,
        index: entry.key,
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'GET PRO',
              style: TextStyle(
                color: Color(0xFFFF5500),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.cast, color: Colors.white, size: 22),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.upload_rounded, color: Colors.white, size: 22),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.mail_outline, color: Colors.white, size: 22),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFeed,
        color: const Color(0xFFFF5500),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // Section 1 — Trending by genre
          const Text(
            'Trending by genre',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = _selectedGenreIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGenreIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF5500)
                            : Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _genres[index],
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFFF5500)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Section 2 — Feed tracks
          _buildTrackSection(),
          const SizedBox(height: 24),

          // Section 3 — Suggested users
          const SuggestedRow(),
          const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }
}

// ── Track row ─────────────────────────────────────────────────────────────────

class _TrackRow extends ConsumerWidget {
  final _FeedTrack track;
  final List<_FeedTrack> allTracks;
  final int index;

  const _TrackRow({
    required this.track,
    required this.allTracks,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          final url = track.hlsUrl;
          if (url == null || url.isEmpty) return;
          final queue = allTracks
              .where((t) => t.hlsUrl != null && t.hlsUrl!.isNotEmpty)
              .map((t) => PlayerTrack(
                    id: t.id,
                    title: t.title,
                    artist: t.artistName,
                    audioUrl: t.hlsUrl!,
                    coverUrl: t.artworkUrl,
                    waveform: t.waveform,
                  ))
              .toList();
          final startIndex = allTracks
              .where((t) => t.hlsUrl != null && t.hlsUrl!.isNotEmpty)
              .toList()
              .indexWhere((t) => t.id == track.id);
          ref.read(playerProvider.notifier).playQueue(
                queue,
                startIndex: startIndex < 0 ? 0 : startIndex,
              );
        },
        child: Row(
        children: [
          // Artwork
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: track.artworkUrl != null && track.artworkUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: track.artworkUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
                    )
                  : const _ArtworkPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),

          // Title + artist + play count
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPlayCount(track.playCount),
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // 3-dot menu
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_vert,
              color: Color(0xFF999999),
              size: 20,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2A2A2A),
      child: Center(
        child: Icon(Icons.music_note, color: Color(0xFF666666), size: 28),
      ),
    );
  }
}
