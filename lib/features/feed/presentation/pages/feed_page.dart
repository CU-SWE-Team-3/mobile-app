import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/network/user_session.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/comments_provider.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/engagement/presentation/widgets/track_options_sheet.dart';
import 'package:soundcloud_clone/features/feed/presentation/providers/feed_provider.dart';
import 'package:soundcloud_clone/features/feed/presentation/widgets/feed_track_card.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';
import 'package:soundcloud_clone/features/player/presentation/widgets/mini_player_widget.dart';

// Fix 1: Define the _Tab enum that is referenced throughout the file but was missing.
enum _Tab { discover, following }

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  _Tab _tab = _Tab.following;
  final PageController _pageController = PageController();
  final ScrollController _followingScrollController = ScrollController();
  int _currentPage = 0;

  // Track which tabs have had their initial load triggered so we only fire once
  // per provider lifecycle (the providers themselves hold the data).
  final Set<_Tab> _loaded = {};

  // Cached sets of the current user's liked and reposted track IDs.
  // Populated once on init; used by the seeding logic for both feed tabs.
  Set<String> _likedIds = const {};
  Set<String> _repostedIds = const {};

  @override
  void initState() {
    super.initState();
    _followingScrollController.addListener(_onFollowingScroll);
    _fetchUserInteractionIds();
    // Trigger initial load after the first frame so providers are accessible.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded(_tab));
  }

  // Fetches the current user's liked and reposted track ID sets once.
  // On completion, re-seeds any already-loaded tracks with the correct state.
  Future<void> _fetchUserInteractionIds() async {
    try {
      final userId = await UserSession.getUserId();
      if (userId == null || userId.isEmpty) return;

      final results = await Future.wait([
        dioClient.dio.get('/profile/$userId/likes'),
        dioClient.dio.get('/profile/$userId/reposts'),
      ]);

      final likesData =
          results[0].data['data'] as Map<String, dynamic>? ?? {};
      final likedRaw = (likesData['likedTracks'] as List?) ?? [];
      Map<String, dynamic>? trackMapFrom(dynamic item) {
        if (item is! Map<String, dynamic>) return null;
        final track = item['target'] ?? item['track'];
        if (track is Map<String, dynamic>) return track;
        if (track is Map) return Map<String, dynamic>.from(track);
        return null;
      }

      final likedIds = <String>{};
      for (final item in likedRaw) {
        final track = trackMapFrom(item);
        final id = track?['_id'] as String?;
        if (id != null && id.isNotEmpty) likedIds.add(id);
      }

      final repostsData =
          results[1].data['data'] as Map<String, dynamic>? ?? {};
      final repostedRaw = (repostsData['repostedTracks'] as List?) ?? [];
      final repostedIds = <String>{};
      for (final item in repostedRaw) {
        if (item is! Map<String, dynamic>) continue;
        final track = trackMapFrom(item);
        final id = (track?['_id'] ?? item['_id']) as String?;
        if (id != null && id.isNotEmpty) repostedIds.add(id);
      }

      if (!mounted) return;
      _likedIds = likedIds;
      _repostedIds = repostedIds;

      // Re-seed tracks that may have loaded before IDs were available.
      _reseedLoadedTracks();
    } catch (_) {
      // Silently fail; seeding falls back to false for both flags.
    }
  }

  // Re-seeds engagement state for every track across both feed providers
  // using the now-populated liked/reposted ID sets.
  void _reseedLoadedTracks() {
    _seedTracks(ref.read(discoverFeedProvider).tracks);
    _seedTracks(ref.read(followingFeedProvider).tracks);
  }

  void _seedTracks(List<FeedTrack> tracks) {
    for (final track in tracks) {
      if (track.id.isEmpty) continue;
      ref
          .read(engagementProvider(EngagementParams(trackId: track.id))
              .notifier)
          .seed(
            isLiked: _likedIds.contains(track.id),
            isReposted: _repostedIds.contains(track.id),
            likeCount: track.likeCount,
            repostCount: track.repostCount,
          );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _followingScrollController.dispose();
    super.dispose();
  }

  // ── Tab management ──────────────────────────────────────────────────────────

  void _switchTab(_Tab tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _currentPage = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _ensureLoaded(tab);
  }

  void _ensureLoaded(_Tab tab) {
    if (_loaded.contains(tab)) return;
    _loaded.add(tab);
    _loadTab(tab);
  }

  Future<void> _loadTab(_Tab tab) {
    if (tab == _Tab.discover) {
      return ref.read(discoverFeedProvider.notifier).load();
    }
    return ref.read(followingFeedProvider.notifier).load();
  }

  Future<void> _refreshCurrentTab() => _loadTab(_tab);

  void _onFollowingScroll() {
    if (!_followingScrollController.hasClients || _tab != _Tab.following) {
      return;
    }
    final position = _followingScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(followingFeedProvider.notifier).loadNextPage();
    }
  }

  // ── Page change ─────────────────────────────────────────────────────────────

  void _onPageChanged(int index, List<FeedTrack> tracks) {
    if (index < 0 || index >= tracks.length) return;
    setState(() => _currentPage = index);
    final track = tracks[index];
    ref.read(playerProvider.notifier).playTrack(track.toPlayerTrack());
    _maybeLoadMoreFollowing(index, tracks.length);
  }

  void _maybeLoadMoreFollowing(int index, int totalTracks) {
    if (_tab != _Tab.following || totalTracks == 0) return;
    final thresholdIndex = totalTracks <= 3 ? totalTracks - 1 : totalTracks - 3;
    if (index < thresholdIndex) return;
    ref.read(followingFeedProvider.notifier).loadNextPage();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ProviderListenable<FeedState> selectedFeedProvider =
        _tab == _Tab.discover ? discoverFeedProvider : followingFeedProvider;
    final feedState = ref.watch(selectedFeedProvider);

    // Seed engagement state and auto-play first track when feed loads.
    ref.listen<FeedState>(
      selectedFeedProvider,
      (prev, next) {
        // Use the pre-fetched liked/reposted ID sets for correct initial state.
        // If IDs haven't arrived yet, seed() is called again from
        // _reseedLoadedTracks() once _fetchUserInteractionIds() completes.
        _seedTracks(next.tracks);
        // Auto-play the first track as soon as it arrives.
        if ((prev == null || prev.tracks.isEmpty) &&
            next.tracks.isNotEmpty &&
            _currentPage == 0) {
          ref
              .read(playerProvider.notifier)
              .playTrack(next.tracks[0].toPlayerTrack());
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Toggle buttons ─────────────────────────────────────
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabButton(
                      key: const ValueKey('feed_discover_tab_button'),
                      label: 'Discover',
                      // Fix 2: Was `_selectedTab == 'Discover'` (undefined variable).
                      // Now correctly compares against the existing _tab enum field.
                      isSelected: _tab == _Tab.discover,
                      // Fix 2 (cont.): Was `setState(() => _selectedTab = 'Discover')`.
                      // Now delegates to _switchTab which handles all tab-switch logic.
                      onTap: () => _switchTab(_Tab.discover),
                    ),
                    _TabButton(
                      key: const ValueKey('feed_following_tab_button'),
                      label: 'Following',
                      // Fix 2: Same correction as above for the Following tab.
                      isSelected: _tab == _Tab.following,
                      onTap: () => _switchTab(_Tab.following),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(child: _buildFeedBody(feedState)),

            // â”€â”€ Mini player bar (Following tab only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            MiniPlayerWidget(),
            // ── Body ───────────────────────────────────────────────

            // ── Mini player bar (Following tab only) ───────────────
          ],
        ),
      ),
    );
  }

  Widget _buildFeedBody(FeedState feedState) {
    if (feedState.isLoading && feedState.tracks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    }

    if (feedState.error != null && feedState.tracks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshCurrentTab,
        color: const Color(0xFFFF5500),
        backgroundColor: const Color(0xFF1A1A1A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: _ErrorView(
              message: feedState.error!,
              onRetry: _refreshCurrentTab,
            ),
          ),
        ),
      );
    }

    if (feedState.tracks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshCurrentTab,
        color: const Color(0xFFFF5500),
        backgroundColor: const Color(0xFF1A1A1A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: _EmptyView(tab: _tab),
          ),
        ),
      );
    }

    if (_tab == _Tab.following) {
      return _buildFollowingFeed(feedState);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshCurrentTab,
          color: const Color(0xFFFF5500),
          backgroundColor: const Color(0xFF1A1A1A),
          child: PageView.builder(
            key: const ValueKey('feed_track_list'),
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: feedState.tracks.length,
            onPageChanged: (index) => _onPageChanged(index, feedState.tracks),
            itemBuilder: (context, index) {
              final track = feedState.tracks[index];
              return FeedTrackCard(
                track: track,
                isActive: index == _currentPage,
              );
            },
          ),
        ),
        if (_tab == _Tab.following && feedState.isLoadingMore)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFFF5500),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFollowingFeed(FeedState feedState) {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      color: const Color(0xFFFF5500),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        key: const ValueKey('feed_track_list'),
        controller: _followingScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
        itemCount: feedState.tracks.length + (feedState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == feedState.tracks.length) {
            return const Padding(
              key: ValueKey('feed_following_pagination_loader'),
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFFF5500),
                ),
              ),
            );
          }

          final track = feedState.tracks[index];
          return _FollowingTrackItem(
            key: ValueKey('feed_following_tile_${track.id}_${index}'),
            track: track,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const ValueKey('feed_retry_button'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final _Tab tab;
  const _EmptyView({required this.tab});

  @override
  Widget build(BuildContext context) {
    final isFollowing = tab == _Tab.following;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowing ? Icons.people_outline : Icons.explore_outlined,
              color: Colors.white38,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isFollowing
                  ? 'No tracks from artists you follow yet.\nFollow some artists to see their tracks here.'
                  : 'No trending tracks available right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowingTrackItem extends ConsumerWidget {
  final FeedTrack track;

  const _FollowingTrackItem({
    super.key,
    required this.track,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final commentsState = ref.watch(commentsProvider(track.id));
    final commentTotal = commentsState.error == null
        ? commentsState.total
        : track.commentCount;
    final artworkUrl = _resolveImageUrl(track.artworkUrl);
    final hasArtwork = artworkUrl != null &&
        !(track.artworkUrl?.startsWith('default') ?? false) &&
        !artworkUrl.contains('default-artwork');
    final cardWidth = MediaQuery.sizeOf(context).width - 24;
    final cardHeight = (cardWidth * 1.08).clamp(360.0, 430.0).toDouble();
    final displayDuration = isCurrentTrack
        ? (playerState.duration > Duration.zero
            ? playerState.duration
            : playerState.currentTrack?.duration ?? Duration.zero)
        : track.toPlayerTrack().duration ?? Duration.zero;

    void playOrPause() {
      if (isCurrentTrack && playerState.error == null) {
        ref.read(playerProvider.notifier).togglePlayPause();
      } else {
        ref.read(playerProvider.notifier).playTrack(track.toPlayerTrack());
      }
    }

    void openOptionsSheet() {
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
          initialLikeCount: engState.likeCount,
          initialRepostCount: engState.repostCount,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FollowingActivityHeader(
            track: track,
            onMoreTap: openOptionsSheet,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: cardHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasArtwork
                      ? CachedNetworkImage(
                          imageUrl: artworkUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: Color(0xFF1A1A1A)),
                          errorWidget: (_, __, ___) =>
                              const _ArtworkFallback(),
                        )
                      : const _ArtworkFallback(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x44000000),
                          Color(0x08000000),
                          Color(0xCC000000),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    right: 14,
                    child: _InlineActionButton(
                      icon: playerState.volume == 0.0
                          ? Icons.volume_off_outlined
                          : Icons.volume_up_outlined,
                      onTap: () =>
                          ref.read(playerProvider.notifier).toggleMute(),
                    ),
                  ),
                  Positioned(
                    top: cardHeight * 0.22,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _InlineActionButton(
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
                        const SizedBox(height: 12),
                        _InlineActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: _formatCount(
                            commentTotal,
                            showZero: true,
                          ),
                          onTap: () => context.push('/comments', extra: {
                            'trackId': track.id,
                            'trackTitle': track.title,
                            'trackArtist': track.artistName,
                            'trackArtworkUrl': artworkUrl ?? '',
                            'currentPositionSeconds': isCurrentTrack
                                ? playerState.position.inSeconds
                                : 0,
                          }),
                        ),
                        const SizedBox(height: 12),
                        _InlineActionButton(
                          icon: Icons.playlist_add,
                          label: 'Add',
                          onTap: () => context.push(
                            '/playlist/add-track',
                            extra: {'trackId': track.id},
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 26,
                    child: _InlinePlayButton(
                      isLoading: playerState.isLoading && isCurrentTrack,
                      isPlaying: isPlaying,
                      onTap: playOrPause,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 64,
                    bottom: 72,
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
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                        if (displayDuration > Duration.zero) ...[
                          const SizedBox(height: 5),
                          Text(
                            _formatDuration(displayDuration),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 6),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 64,
                    bottom: 28,
                    child: Row(
                      children: [
                        _MiniAvatar(avatarUrl: track.artistAvatarUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowingActivityHeader extends StatelessWidget {
  final FeedTrack track;
  final VoidCallback onMoreTap;

  const _FollowingActivityHeader({
    required this.track,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final actor = track.actorName?.isNotEmpty == true
        ? track.actorName!
        : track.artistName;
    final action = _activityText(track.activityType);
    final timeAgo = _formatRelativeTime(track.activityTimestamp);
    final avatarUrl = track.actorAvatarUrl;
    final hasAvatar = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl.startsWith('http');

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
      child: Row(
        children: [
          _HeaderAvatar(avatarUrl: hasAvatar ? avatarUrl : null),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: actor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: ' $action'),
                  if (timeAgo != null) TextSpan(text: ' - $timeAgo'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onMoreTap,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.more_vert, color: Colors.white70, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _InlineActionButton({
    required this.icon,
    this.iconColor = Colors.white,
    this.label = '',
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: iconColor, size: 32),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 3),
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

class _InlinePlayButton extends StatelessWidget {
  final bool isLoading;
  final bool isPlaying;
  final VoidCallback onTap;

  const _InlinePlayButton({
    required this.isLoading,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 31,
              ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _HeaderAvatar({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _AvatarFallback(iconSize: 12),
                errorWidget: (_, __, ___) =>
                    const _AvatarFallback(iconSize: 12),
              )
            : const _AvatarFallback(iconSize: 12),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _MiniAvatar({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null &&
        avatarUrl!.isNotEmpty &&
        avatarUrl!.startsWith('http');
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: ClipOval(
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _AvatarFallback(iconSize: 18),
                errorWidget: (_, __, ___) =>
                    const _AvatarFallback(iconSize: 18),
              )
            : const _AvatarFallback(iconSize: 18),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final double iconSize;

  const _AvatarFallback({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Icon(
          Icons.person,
          color: Colors.white38,
          size: iconSize,
        ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1A1A1A),
      child: Center(
        child: Icon(Icons.music_note, color: Colors.white24, size: 64),
      ),
    );
  }
}

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

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _activityText(String? activityType) {
  switch (activityType) {
    case 'repost':
      return 'reposted a track';
    case 'like':
      return 'liked a track';
    default:
      return 'posted a track';
  }
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
