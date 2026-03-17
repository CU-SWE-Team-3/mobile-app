import 'package:flutter/material.dart';
import 'package:soundcloud_clone/core/themes/app_theme.dart';
import 'package:soundcloud_clone/features/followers/presentation/widgets/suggested_row.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> _genres = [
    'Electronic', 'Folk', 'House', 'Techno', 'Pop',
    'Hip-Hop', 'Jazz', 'Classical', 'R&B', 'Metal',
  ];

  static const List<_MockTrack> _tracks = [
    _MockTrack('Your Loving Arms (FREE DL)', 'Phase Two'),
    _MockTrack('Hera', 'Ömer Bükülmezoğlu'),
    _MockTrack('Black Aura - Freedom (Original...)', 'Take It Easy Records'),
    _MockTrack('Midnight Drive', 'Nocturnals'),
    _MockTrack('Solar Flare', 'Astral Collective'),
  ];

  int _selectedGenreIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSuggestedDialog(context);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
      body: ListView(
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

          // Section 2 — Track list
          ..._tracks.map((track) => _TrackRow(track: track)),
          const SizedBox(height: 24),

          // Section 3 — Suggested users
          const SuggestedRow(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final _MockTrack track;

  const _TrackRow({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Album art placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.music_note,
              color: Color(0xFF666666),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),

          // Title + artist
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
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
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
    );
  }
}

class _MockTrack {
  final String title;
  final String artist;

  const _MockTrack(this.title, this.artist);
}
