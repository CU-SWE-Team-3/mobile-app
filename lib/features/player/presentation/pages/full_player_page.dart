import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/player_provider.dart';

class FullPlayerPage extends ConsumerStatefulWidget {
  const FullPlayerPage({super.key});

  @override
  ConsumerState<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends ConsumerState<FullPlayerPage> {
  bool _isLiked = false;
  late final TextEditingController _commentController;
  late final FocusNode _commentFocus;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _commentFocus = FocusNode();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final artworkUrl = playerState.currentTrackArtworkUrl;

    final progress = playerState.duration.inMilliseconds > 0
        ? (playerState.position.inMilliseconds /
                playerState.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Full-bleed artwork background ─────────────────────
          artworkUrl != null
              ? CachedNetworkImage(
                  imageUrl: artworkUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Color(0xFF1A1A1A)),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF1A1A1A)),
                )
              : const ColoredBox(color: Color(0xFF1A1A1A)),

          // ── Layer 2: Gradient overlay ───────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xBB000000),
                ],
                stops: [0.0, 0.30, 0.58, 1.0],
              ),
            ),
          ),

          // ── Layer 3: UI content ─────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ─────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleButton(
                        icon: Icons.keyboard_arrow_down,
                        onTap: () => context.pop(),
                      ),
                      _CircleButton(
                        icon: Icons.person_add_outlined,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                // ── Track title + artist ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerState.currentTrackTitle ?? 'Nothing playing',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        playerState.currentTrackArtist ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── "Behind this track" row ────────────────────────
                      GestureDetector(
                        onTap: () {},
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.graphic_eq,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Behind this track',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Spacer — artwork breathes ────────────────────────────
                const Spacer(),

                // ── Waveform seek bar ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapDown: (details) {
                          final pct =
                              (details.localPosition.dx / constraints.maxWidth)
                                  .clamp(0.0, 1.0);
                          notifier.seekTo(Duration(
                            milliseconds: (pct *
                                    playerState.duration.inMilliseconds)
                                .round(),
                          ));
                        },
                        onHorizontalDragUpdate: (details) {
                          final pct =
                              (details.localPosition.dx / constraints.maxWidth)
                                  .clamp(0.0, 1.0);
                          notifier.seekTo(Duration(
                            milliseconds: (pct *
                                    playerState.duration.inMilliseconds)
                                .round(),
                          ));
                        },
                        child: SizedBox(
                          height: 48,
                          width: constraints.maxWidth,
                          child: CustomPaint(
                            painter: _WaveformPainter(progress: progress),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // ── Time pill ────────────────────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_formatDuration(playerState.position)}  |  ${_formatDuration(playerState.duration)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Playback controls ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white, size: 40),
                      onPressed: notifier.skipPrevious,
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: notifier.togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playerState.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 40),
                      onPressed: notifier.skipNext,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Comment input bar ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Drop a comment...',
                              hintStyle: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            textInputAction: TextInputAction.send,
                            keyboardAppearance: Brightness.dark,
                            maxLines: 1,
                            onSubmitted: (_) {
                              _commentController.clear();
                              _commentFocus.unfocus();
                            },
                          ),
                        ),
                        Row(
                          children: [
                            _EmojiButton(
                              emoji: '🔥',
                              onTap: () {
                                _commentController.text += '🔥';
                                _commentController.selection =
                                    TextSelection.collapsed(
                                        offset: _commentController.text.length);
                                _commentFocus.requestFocus();
                              },
                            ),
                            const SizedBox(width: 6),
                            _EmojiButton(
                              emoji: '👏',
                              onTap: () {
                                _commentController.text += '👏';
                                _commentController.selection =
                                    TextSelection.collapsed(
                                        offset: _commentController.text.length);
                                _commentFocus.requestFocus();
                              },
                            ),
                            const SizedBox(width: 6),
                            _EmojiButton(
                              emoji: '🤩',
                              onTap: () {
                                _commentController.text += '🤩';
                                _commentController.selection =
                                    TextSelection.collapsed(
                                        offset: _commentController.text.length);
                                _commentFocus.requestFocus();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Bottom action bar ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActionButton(
                        icon: _isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        iconColor:
                            _isLiked ? Colors.orange : Colors.white,
                        label: '28',
                        onTap: () =>
                            setState(() => _isLiked = !_isLiked),
                      ),
                      _ActionButton(
                        icon: Icons.comment_outlined,
                        label: '3',
                        onTap: () => context.push('/comments'),
                      ),
                      _ActionButton(
                        icon: Icons.share_outlined,
                        label: '',
                        onTap: () {},
                      ),
                      _ActionButton(
                        icon: Icons.queue_music,
                        label: '',
                        onTap: () => context.push('/player/queue'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.iconColor = Colors.white,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 26),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waveform CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  final double progress;

  static const _heights = [
    0.30, 0.50, 0.70, 0.40, 0.90, 0.60, 0.80, 0.50, 0.30, 0.70,
    0.40, 0.60, 0.80, 0.50, 0.30, 0.90, 0.70, 0.40, 0.60, 0.50,
    0.80, 0.30, 0.70, 0.50, 0.40, 0.90, 0.60, 0.30, 0.80, 0.50,
    0.40, 0.70, 0.30, 0.60, 0.90, 0.50, 0.80, 0.40, 0.70, 0.30,
    0.50, 0.80, 0.60, 0.40, 0.70, 0.30, 0.90, 0.50, 0.60, 0.40,
    0.80, 0.30, 0.70, 0.50, 0.40, 0.60, 0.90, 0.30, 0.50, 0.70,
    0.40, 0.80, 0.60, 0.30, 0.90, 0.50, 0.70, 0.40, 0.60, 0.30,
  ];

  const _WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _heights.length;
    const spacing = 2.0;
    final barWidth = (size.width - (barCount - 1) * spacing) / barCount;

    final playedPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final unplayedPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final barHeight = _heights[i] * size.height;
      final x = i * (barWidth + spacing);
      final y = (size.height - barHeight) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(
          rect, i / barCount < progress ? playedPaint : unplayedPaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}
