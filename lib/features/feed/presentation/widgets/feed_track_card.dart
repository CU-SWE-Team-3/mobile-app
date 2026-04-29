import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/user_session.dart';
import '../../../engagement/presentation/providers/engagement_provider.dart';
import '../../../player/presentation/providers/follow_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/feed_provider.dart';

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

  void _openMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FeedTrackOptionsSheet(trackId: widget.track.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final playerState = ref.watch(playerProvider);
    final isCurrentTrack = playerState.currentTrack?.id == track.id;
    final isPlaying = isCurrentTrack && playerState.isPlaying;

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

    return Stack(
      fit: StackFit.expand,
      children: [
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
                  child: Icon(Icons.music_note, color: Colors.white24, size: 64),
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
            right: 0,
            child: _ActivityHeader(track: track),
          ),

        // ── Right-side action column ─────────────────────────────────────
        Positioned(
          right: 12,
          bottom: 100,
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
              const SizedBox(height: 28),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: _formatCount(track.commentCount),
                onTap: _openComments,
              ),
              const SizedBox(height: 28),
              _ActionButton(
                icon: Icons.repeat,
                iconColor: engState.isReposted
                    ? const Color(0xFFFF5500)
                    : Colors.white,
                label: _formatCount(engState.repostCount),
                loading: engState.isLoadingRepost,
                onTap: () => ref
                    .read(engagementProvider(engParams).notifier)
                    .toggleRepost(),
              ),
              const SizedBox(height: 28),
              _ActionButton(
                icon: Icons.playlist_add,
                label: '',
                onTap: _openAddToPlaylist,
              ),
              const SizedBox(height: 28),
              _ActionButton(
                icon: Icons.more_vert,
                label: '',
                onTap: _openMoreOptions,
              ),
            ],
          ),
        ),

        // ── Bottom artist card ───────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Artist avatar
                  _ArtistAvatar(avatarUrl: track.artistAvatarUrl),
                  const SizedBox(width: 10),

                  // Title + artist name
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Follow button (hidden for own tracks)
                  if (track.artistId.isNotEmpty &&
                      track.artistId != _myUserId)
                    _FollowButton(
                      isFollowing: followState.isFollowing,
                      isLoading:
                          followState.isLoading || followState.isChecking,
                      onTap: () => ref
                          .read(followProvider(track.artistId).notifier)
                          .toggle(track.artistId),
                    ),

                  const SizedBox(width: 8),

                  // Play / pause
                  GestureDetector(
                    onTap: isCurrentTrack && playerState.error == null
                        ? ref.read(playerProvider.notifier).togglePlayPause
                        : () => ref
                            .read(playerProvider.notifier)
                            .playTrack(track.toPlayerTrack()),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5500),
                        shape: BoxShape.circle,
                      ),
                      child: playerState.isLoading && isCurrentTrack
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

String _formatCount(int n) {
  if (n <= 0) return '';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : Icon(icon, color: iconColor, size: 26),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
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

class _FeedTrackOptionsSheet extends StatelessWidget {
  final String trackId;

  const _FeedTrackOptionsSheet({required this.trackId});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);

    void go(String path, {Object? extra}) {
      Navigator.pop(context);
      router.push(path, extra: extra);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        _OptionTile(
          icon: Icons.favorite,
          label: 'Your Likes',
          onTap: () => go('/likes'),
        ),
        _OptionTile(
          icon: Icons.repeat_one,
          label: 'Your Reposts',
          onTap: () => go('/profile/reposts'),
        ),
        _OptionTile(
          icon: Icons.favorite_border,
          label: 'Who liked this',
          onTap: () => go('/likers', extra: {'trackId': trackId}),
        ),
        _OptionTile(
          icon: Icons.repeat,
          label: 'Who reposted this',
          onTap: () => go('/reposters', extra: {'trackId': trackId}),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
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
