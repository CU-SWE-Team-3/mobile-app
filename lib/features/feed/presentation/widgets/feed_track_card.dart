import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/user_session.dart';
import '../../../../core/utils/profile_navigation.dart';
import '../../../engagement/presentation/providers/engagement_provider.dart';
import '../../../engagement/presentation/widgets/track_options_sheet.dart';
import '../../../player/presentation/providers/follow_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/feed_provider.dart';

final discoverManualPlaybackTrackIdProvider = StateProvider<String?>(
  (ref) => null,
);

class FeedTrackCard extends ConsumerStatefulWidget {
  final FeedTrack track;
  final bool isActive;

  const FeedTrackCard({
    super.key,
    required this.track,
    required this.isActive,
  });

  @override
  ConsumerState<FeedTrackCard> createState() => _FeedTrackCardState();
}

class _FeedTrackCardState extends ConsumerState<FeedTrackCard> {
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    UserSession.getUserId().then((id) {
      if (mounted) setState(() => _myUserId = id);
    });
  }

  void _openComments() {
    final track = widget.track;
    final playerState = ref.read(playerProvider);
    final positionSeconds = playerState.currentTrack?.id == track.id
        ? playerState.position.inSeconds
        : 0;
    context.push('/comments', extra: {
      'trackId': track.id,
      'trackTitle': track.title,
      'trackArtist': track.artistName,
      'trackArtworkUrl': _resolveImageUrl(track.artworkUrl) ?? '',
      'currentPositionSeconds': positionSeconds,
    });
  }

  void _openAddToPlaylist() {
    context.push('/playlist/add-track', extra: {'trackId': widget.track.id});
  }

  void _openMoreOptions(EngagementState engState, String? artworkUrl) {
    final track = widget.track;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TrackOptionsSheet(
        trackId: track.id,
        title: track.title,
        artistName: track.artistName,
        artworkUrl: artworkUrl,
        audioUrl: track.audioUrl,
        waveform: track.waveform,
        artistId: track.artistId,
        artistPermalink: track.artistPermalink,
        initialIsLiked: engState.isLiked,
        initialIsReposted: engState.isReposted,
        initialLikeCount: engState.likeCount,
        initialRepostCount: engState.repostCount,
      ),
    );
  }

  Future<void> _openArtistProfile() async {
    final track = widget.track;
    if (track.artistId.isEmpty) return;

    await navigateToUserProfile(
      context,
      userId: track.artistId,
      permalink: track.artistPermalink?.isNotEmpty == true
          ? track.artistPermalink!
          : track.artistId,
      displayName: track.artistName,
    );
  }

  Future<void> _openFullPlayerFromBeginning() async {
    final playerTrack = widget.track.toPlayerTrack();
    final notifier = ref.read(playerProvider.notifier);
    final playerState = ref.read(playerProvider);
    final manualTrackId = ref.read(discoverManualPlaybackTrackIdProvider);

    if (manualTrackId == playerTrack.id &&
        playerState.currentTrack?.id == playerTrack.id &&
        playerState.error == null) {
      notifier.togglePlayPause();
      return;
    }

    ref.read(discoverManualPlaybackTrackIdProvider.notifier).state =
        playerTrack.id;

    if (playerState.currentTrack?.id == playerTrack.id &&
        playerState.error == null) {
      await notifier.seekTo(Duration.zero);
      notifier.resume();
    } else {
      await notifier.playTrack(playerTrack);
    }

    if (mounted) {
      context.push('/player');
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final playerState = ref.watch(playerProvider);
    final manualTrackId = ref.watch(discoverManualPlaybackTrackIdProvider);
    final isCurrentTrack = playerState.currentTrack?.id == track.id;
    final isManualCurrentTrack =
        manualTrackId == track.id && isCurrentTrack && playerState.error == null;
    final progressDuration = playerState.duration > Duration.zero
        ? playerState.duration
        : track.toPlayerTrack().duration ?? Duration.zero;
    final playProgress =
        isManualCurrentTrack && progressDuration.inMilliseconds > 0
            ? (playerState.position.inMilliseconds /
                    progressDuration.inMilliseconds)
                .clamp(0.0, 1.0)
                .toDouble()
            : 0.0;
    final engParams = EngagementParams(
      trackId: track.id,
      isLiked: track.isLiked,
      isReposted: track.isReposted,
      likeCount: track.likeCount,
      repostCount: track.repostCount,
    );
    final engState = ref.watch(engagementProvider(engParams));

    final followState = track.artistId.isNotEmpty
        ? ref.watch(followProvider(track.artistId))
        : const FollowState();

    final resolvedArtwork = _resolveImageUrl(track.artworkUrl);
    final hasArtwork = resolvedArtwork != null &&
        !(track.artworkUrl?.startsWith('default') ?? false) &&
        !resolvedArtwork.contains('default-artwork');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          key: const ValueKey('feed_track_tile'),
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: SizedBox(key: ValueKey('feed_track_tile')),
            ),
        // ── Background artwork ───────────────────────────────────────────
            hasArtwork
                ? CachedNetworkImage(
                    imageUrl: resolvedArtwork,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFF1A1A1A)),
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF1A1A1A)),
                  )
                : Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Center(
                      child: Icon(
                        Icons.music_note,
                        color: Colors.white24,
                        size: 64,
                      ),
                    ),
                  ),

        // ── Gradient overlay ─────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x88000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xDD000000),
                  ],
                  stops: [0.0, 0.25, 0.55, 1.0],
                ),
              ),
            ),

        // ── Activity header (repost / post label) ────────────────────────
            if (track.activityType != null)
              Positioned(
                top: 0,
                left: 0,
                right: 48,
                child: _ActivityHeader(track: track),
              ),

            Positioned(
              top: 14,
              right: 8,
              child: _ActionButton(
                icon: Icons.more_vert,
                label: '',
                onTap: () => _openMoreOptions(engState, resolvedArtwork),
              ),
            ),

        // ── Right-side action column ─────────────────────────────────────
            Positioned(
              right: 12,
              bottom: 150,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: engState.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    iconColor: engState.isLiked
                        ? const Color(0xFFFF5500)
                        : Colors.white,
                    label: _formatCount(engState.likeCount),
                    loading: engState.isLoadingLike,
                    onTap: () => ref
                        .read(engagementProvider(engParams).notifier)
                        .toggleLike(),
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: _formatCount(track.commentCount, showZero: true),
                    onTap: _openComments,
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    icon: Icons.playlist_add,
                    label: 'Add',
                    onTap: _openAddToPlaylist,
                  ),
                ],
              ),
            ),

        // ── Bottom artist card ───────────────────────────────────────────
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: GestureDetector(
                onTap: () => context.push('/player'),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF5F666D).withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    height: 1.08,
                                    fontWeight: FontWeight.w800,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _ArtistAvatar(
                                      avatarUrl: track.artistAvatarUrl,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _openArtistProfile,
                                        behavior: HitTestBehavior.opaque,
                                        child: Text(
                                          track.artistName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black87,
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (track.artistId.isNotEmpty &&
                                        track.artistId != _myUserId) ...[
                                      const SizedBox(width: 10),
                                      _FollowButton(
                                        isFollowing: followState.isFollowing,
                                        isLoading: followState.isLoading ||
                                            followState.isChecking,
                                        onTap: () => ref
                                            .read(
                                              followProvider(track.artistId)
                                                  .notifier,
                                            )
                                            .toggle(track.artistId),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          _CardPlayButton(
                            isLoading:
                                isManualCurrentTrack && playerState.isLoading,
                            isPlaying:
                                isManualCurrentTrack && playerState.isPlaying,
                            progress: playProgress,
                            onTap: _openFullPlayerFromBeginning,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Converts a relative artworkUrl (e.g. "artwork.png") returned by the
// /discovery/trending endpoint into a fully-qualified URL. Full URLs are
// returned unchanged; null/empty inputs return null.
String? _resolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  final path = url.startsWith('/') ? url : '/$url';
  return 'https://biobeats.duckdns.org$path';
}

String _formatCount(int n, {bool showZero = false}) {
  if (n <= 0) return showZero ? '0' : '';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.iconColor = Colors.white,
    required this.label,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 34,
        height: 42,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: iconColor, size: 26),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _CardPlayButton extends StatelessWidget {
  final bool isLoading;
  final bool isPlaying;
  final double progress;
  final VoidCallback onTap;

  const _CardPlayButton({
    required this.isLoading,
    required this.isPlaying,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        height: 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3.5,
                backgroundColor: Colors.white.withValues(alpha: 0.24),
                color: const Color(0xFFFF5500),
              ),
            ),
            isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 31,
                  ),
          ],
        ),
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _ArtistAvatar({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final isValid = avatarUrl != null &&
        avatarUrl!.isNotEmpty &&
        avatarUrl!.startsWith('http');
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white38, width: 1),
      ),
      child: ClipOval(
        child: isValid
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.person, color: Colors.white38, size: 20),
        ),
      );
}

class _ActivityHeader extends StatelessWidget {
  final FeedTrack track;

  const _ActivityHeader({required this.track});

  @override
  Widget build(BuildContext context) {
    final label =
        track.activityType == 'repost' ? 'reposted a track' : 'posted a track';
    final timeAgo = _formatRelativeTime(track.activityTimestamp);
    final actorName = track.actorName ?? '';
    final avatarUrl = track.actorAvatarUrl;
    final isValidAvatar =
        avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http');

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: ClipOval(
                child: isValidAvatar
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _avatarFallback(),
                        errorWidget: (_, __, ___) => _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                  ),
                  children: [
                    TextSpan(
                      text: actorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: ' $label'),
                    if (timeAgo != null) TextSpan(text: ' · $timeAgo'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.person, color: Colors.white38, size: 14),
        ),
      );
}

String? _formatRelativeTime(DateTime? timestamp) {
  if (timestamp == null) return null;
  final diff = DateTime.now().difference(timestamp);
  if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.transparent
              : const Color(0xFFFF5500),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFollowing
                ? Colors.white54
                : const Color(0xFFFF5500),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
