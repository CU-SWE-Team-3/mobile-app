import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/themes/app_theme.dart';
import '../providers/follow_provider.dart';
import '../providers/player_provider.dart';
import '../../../engagement/data/models/comment_model.dart';
import '../../../engagement/presentation/providers/comments_provider.dart';
import '../../../engagement/presentation/providers/engagement_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../premium/presentation/providers/subscription_provider.dart';

class FullPlayerPage extends ConsumerStatefulWidget {
  const FullPlayerPage({super.key});

  @override
  ConsumerState<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends ConsumerState<FullPlayerPage> {
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

  void _openComments(
    BuildContext context, {
    required int currentPositionSeconds,
    required String? trackId,
    required String? trackTitle,
    required String? trackArtist,
    required String? trackArtworkUrl,
  }) {
    if (trackId == null) return;
    context.push('/comments', extra: {
      'trackId': trackId,
      'trackTitle': trackTitle ?? '',
      'trackArtist': trackArtist ?? '',
      'trackArtworkUrl': trackArtworkUrl ?? '',
      'currentPositionSeconds': currentPositionSeconds,
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final artworkUrl = playerState.currentTrackArtworkUrl;
    final trackId = playerState.currentTrack?.id;
    final artistId = playerState.currentTrack?.artistId;

    final followState = artistId != null
        ? ref.watch(followProvider(artistId))
        : const FollowState();

    // Engagement state (like + repost) — keyed by trackId
    final engParams = EngagementParams(trackId: trackId ?? '');
    final engState = trackId != null
        ? ref.watch(engagementProvider(engParams))
        : const EngagementState();

    final progress = playerState.duration.inMilliseconds > 0
        ? (playerState.position.inMilliseconds /
                playerState.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final currentSec = playerState.position.inSeconds;

    // Family provider — each trackId gets its own instance, shared across pages
    final commentsState = trackId != null
        ? ref.watch(commentsProvider(trackId))
        : const CommentsState();


    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Full-bleed artwork background ──────────────────
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

          // ── Layer 2: Gradient scrim (top + bottom only) ─────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xAA000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xF0000000),
                ],
                stops: [0.0, 0.22, 0.52, 1.0],
              ),
            ),
          ),

          // ── Layer 3: Paused-state dim overlay ───────────────────────
          AnimatedOpacity(
            opacity: playerState.isPlaying ? 0.0 : 0.55,
            duration: const Duration(milliseconds: 300),
            child: const ColoredBox(color: Colors.black),
          ),

          // ── Layer 4: UI content ─────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top bar ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleButton(
                        key: const ValueKey('player_back_button'),
                        icon: Icons.keyboard_arrow_down,
                        onTap: () => context.pop(),
                      ),
                      _CircleButton(
                        key: const ValueKey('player_follow_button'),
                        icon: followState.isFollowing
                            ? Icons.person
                            : Icons.person_add_outlined,
                        onTap: artistId != null
                            ? () => ref
                                .read(followProvider(artistId).notifier)
                                .toggle(artistId)
                            : () {},
                        loading: followState.isLoading,
                      ),
                    ],
                  ),
                ),

                // ── Track title + artist ─────────────────────────────
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
                            color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        key: const ValueKey('player_behind_track_button'),
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

                // ── Middle: artwork fills here; paused controls centred ──
                Expanded(
                  child: GestureDetector(
                    onTap: notifier.togglePlayPause,
                    behavior: HitTestBehavior.translucent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: playerState.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 250),
                        child: IgnorePointer(
                          ignoring: playerState.isPlaying,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                key: const ValueKey(
                                    'player_skip_previous_button'),
                                onTap: () => ref
                                    .read(playerProvider.notifier)
                                    .skipPrevious(),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.skip_previous_rounded,
                                      color: Colors.white,
                                      size: 30),
                                ),
                              ),
                              const SizedBox(width: 28),
                              GestureDetector(
                                key: const ValueKey('player_play_button'),
                                onTap: notifier.togglePlayPause,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.60),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    playerState.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 28),
                              GestureDetector(
                                key: const ValueKey(
                                    'player_skip_next_button'),
                                onTap: () => ref
                                    .read(playerProvider.notifier)
                                    .skipNext(),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.skip_next_rounded,
                                      color: Colors.white, size: 30),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Time pill (above waveform) ───────────────────────
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

                const SizedBox(height: 8),

                // ── Waveform + floating comment avatars ──────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        key: const ValueKey('player_waveform_seek'),
                        onTapDown: (details) {
                          final pct = (details.localPosition.dx /
                                  constraints.maxWidth)
                              .clamp(0.0, 1.0);
                          notifier.seekTo(Duration(
                            milliseconds: (pct *
                                    playerState.duration.inMilliseconds)
                                .round(),
                          ));
                        },
                        onHorizontalDragUpdate: (details) {
                          final pct = (details.localPosition.dx /
                                  constraints.maxWidth)
                              .clamp(0.0, 1.0);
                          notifier.seekTo(Duration(
                            milliseconds: (pct *
                                    playerState.duration.inMilliseconds)
                                .round(),
                          ));
                        },
                        child: SizedBox(
                          height: 120,
                          width: constraints.maxWidth,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                top: 40,
                                child: CustomPaint(
                                  painter: _WaveformPainter(
                                      progress: progress,
                                      waveform: playerState
                                          .currentTrack?.waveform,
                                      isPlaying: playerState.isPlaying),
                                ),
                              ),
                              if (playerState.duration.inSeconds > 0)
                                ..._buildCommentAvatars(
                                  comments: commentsState.comments,
                                  totalSeconds:
                                      playerState.duration.inSeconds,
                                  width: constraints.maxWidth,
                                  currentSec: currentSec,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),


                const SizedBox(height: 12),

                // ── Comment input bar ────────────────────────────────
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
                            key: const ValueKey(
                                'player_comment_input_field'),
                            controller: _commentController,
                            focusNode: _commentFocus,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText:
                                  'Drop a comment at ${_formatSec(currentSec)}...',
                              hintStyle: const TextStyle(
                                  color: Colors.white54, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            textInputAction: TextInputAction.send,
                            keyboardAppearance: Brightness.dark,
                            maxLines: 1,
                            onSubmitted: (text) async {
                              if (text.trim().isEmpty || trackId == null) {
                                return;
                              }
                              await ref
                                  .read(commentsProvider(trackId).notifier)
                                  .postComment(
                                    content: text.trim(),
                                    timestamp: currentSec,
                                  );
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
                                        offset:
                                            _commentController.text.length);
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
                                        offset:
                                            _commentController.text.length);
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
                                        offset:
                                            _commentController.text.length);
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

                // ── Bottom action bar ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActionButton(
                        key: const ValueKey('player_like_button'),
                        icon: engState.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        iconColor:
                            engState.isLiked ? Colors.orange : Colors.white,
                        label: engState.likeCount > 0
                            ? '${engState.likeCount}'
                            : '',
                        onTap: engState.isLoadingLike || trackId == null
                            ? () {}
                            : () => ref
                                .read(
                                    engagementProvider(engParams).notifier)
                                .toggleLike(),
                      ),
                      _ActionButton(
                        key: const ValueKey('player_repost_button'),
                        icon: Icons.repeat,
                        iconColor: engState.isReposted
                            ? Colors.orange
                            : Colors.white,
                        label: engState.repostCount > 0
                            ? '${engState.repostCount}'
                            : '',
                        onTap: engState.isLoadingRepost || trackId == null
                            ? () {}
                            : () => ref
                                .read(
                                    engagementProvider(engParams).notifier)
                                .toggleRepost(),
                      ),
                      _ActionButton(
                        key: const ValueKey('player_comment_button'),
                        icon: Icons.comment_outlined,
                        label: commentsState.comments.isNotEmpty
                            ? '${commentsState.comments.length}'
                            : '',
                        onTap: () => _openComments(
                          context,
                          currentPositionSeconds: currentSec,
                          trackId: trackId,
                          trackTitle: playerState.currentTrackTitle,
                          trackArtist: playerState.currentTrackArtist,
                          trackArtworkUrl:
                              playerState.currentTrackArtworkUrl,
                        ),
                      ),
                      _ActionButton(
                        key: const ValueKey('player_share_button'),
                        icon: Icons.share_outlined,
                        label: '',
                        onTap: () {},
                      ),
                      _DownloadButton(trackId: trackId),
                      _ActionButton(
                        key: const ValueKey('player_queue_button'),
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

  List<Widget> _buildCommentAvatars({
    required List<CommentModel> comments,
    required int totalSeconds,
    required double width,
    required int currentSec,
  }) {
    if (totalSeconds == 0 || comments.isEmpty) return [];

    // Only show a comment pin when playback is within 3 seconds of its timestamp
    // This mimics real SoundCloud where avatars appear as the track plays
    const visibleWindow = 1;

    final Map<int, CommentModel> buckets = {};
    for (final c in comments) {
      final bucket = c.timestamp ~/ 3;
      buckets.putIfAbsent(bucket, () => c);
    }

    return buckets.entries
        .where((entry) {
          final diff = (currentSec - entry.value.timestamp).abs();
          return diff <= visibleWindow;
        })
        .map((entry) {
          final comment = entry.value;
          final xFraction = comment.timestamp / totalSeconds;
          final xPos = (xFraction * width).clamp(0.0, width - 200.0);
          return Positioned(
            left: xPos,
            top: 0,
            child: _WaveformCommentPin(
              avatarUrl: comment.user.avatarUrl,
              displayName: comment.user.displayName,
              content: comment.content,
              timestamp: comment.timestamp,
            ),
          );
        })
        .toList();
  }
}

// ── Waveform comment pin ─────────────────────────────────────────────────────

class _WaveformCommentPin extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final String content;
  final int timestamp;

  const _WaveformCommentPin({
    required this.avatarUrl,
    required this.displayName,
    required this.content,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl!.isNotEmpty &&
        avatarUrl!.startsWith('http');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar circle
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: ClipOval(
            child: isValidUrl
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _placeholder(),
                    errorWidget: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
        ),
        const SizedBox(width: 6),
        // Comment bubble — always visible like real SoundCloud
        Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.78),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF3A3A3A),
        child: const Icon(Icons.person, color: Colors.white38, size: 12),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _formatSec(int seconds) {
  final m = (seconds ~/ 60).toString();
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  const _CircleButton(
      {super.key, required this.icon, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
            color: Colors.black38, shape: BoxShape.circle),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : Icon(icon, color: Colors.white, size: 22),
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
    super.key,
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
            Text(label,
                style:
                    const TextStyle(color: Colors.white, fontSize: 11)),
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
// Download button — premium gated
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadButton extends ConsumerStatefulWidget {
  final String? trackId;
  const _DownloadButton({required this.trackId});

  @override
  ConsumerState<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<_DownloadButton> {
  bool _isDownloading = false;

  Future<void> _onTap() async {
    final isPremium = ref.read(subscriptionProvider).isPremium;
    if (!isPremium) {
      _showUpgradeDialog();
      return;
    }
    if (widget.trackId == null || _isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      await ref.read(dioClientProvider).dio.get(
        '/tracks/${widget.trackId}/download',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('403')
            ? 'Download limit reached. Upgrade for more.'
            : 'Download failed. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showUpgradeDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Premium feature',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Upgrade to Artist Pro or Go+ to download tracks and listen offline.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/upgrade');
            },
            child: const Text('Upgrade',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(subscriptionProvider).isPremium;

    return GestureDetector(
      key: const ValueKey('player_download_button'),
      onTap: _onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isDownloading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isPremium
                      ? Icons.download_outlined
                      : Icons.download_outlined,
                  color: isPremium ? Colors.white : Colors.white30,
                  size: 26,
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waveform CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  final double progress;
  final List<int>? waveform;
  final bool isPlaying;

  static const _fallbackHeights = [
    0.30, 0.50, 0.70, 0.40, 0.90, 0.60, 0.80, 0.50, 0.30, 0.70,
    0.40, 0.60, 0.80, 0.50, 0.30, 0.90, 0.70, 0.40, 0.60, 0.50,
    0.80, 0.30, 0.70, 0.50, 0.40, 0.90, 0.60, 0.30, 0.80, 0.50,
    0.40, 0.70, 0.30, 0.60, 0.90, 0.50, 0.80, 0.40, 0.70, 0.30,
    0.50, 0.80, 0.60, 0.40, 0.70, 0.30, 0.90, 0.50, 0.60, 0.40,
    0.80, 0.30, 0.70, 0.50, 0.40, 0.60, 0.90, 0.30, 0.50, 0.70,
    0.40, 0.80, 0.60, 0.30, 0.90, 0.50, 0.70, 0.40, 0.60, 0.30,
  ];

  _WaveformPainter(
      {required this.progress, this.waveform, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isPlaying) {
      const strokeWidth = 2.0;
      final playedPaint = Paint()
        ..color = AppTheme.primary
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      final unplayedPaint = Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      final y = size.height / 2;
      final splitX = size.width * progress;
      canvas.drawLine(Offset(0, y), Offset(splitX, y), playedPaint);
      canvas.drawLine(Offset(splitX, y), Offset(size.width, y), unplayedPaint);
      return;
    }

    final List<double> heights;
    if (waveform != null && waveform!.isNotEmpty) {
      heights = waveform!.map((v) => (v / 100.0).clamp(0.05, 1.0)).toList();
    } else {
      heights = _fallbackHeights;
    }

    final barCount = heights.length;
    const spacing = 2.0;
    final barWidth = (size.width - (barCount - 1) * spacing) / barCount;

    final playedPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    final unplayedPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final barHeight = heights[i] * size.height;
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
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.isPlaying != isPlaying;
}
