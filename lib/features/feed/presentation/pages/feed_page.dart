import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/user_session.dart';
import '../../../engagement/presentation/providers/engagement_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/feed_track_card.dart';

enum _Tab { discover, following }

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  _Tab _tab = _Tab.following;
  final PageController _pageController = PageController();
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
      final likedIds = <String>{};
      for (final item in likedRaw) {
        if (item is! Map<String, dynamic>) continue;
        final track =
            (item['target'] ?? item['track']) as Map<String, dynamic>?;
        final id = (track?['_id'] ?? item['_id']) as String?;
        if (id != null && id.isNotEmpty) likedIds.add(id);
      }

      final repostsData =
          results[1].data['data'] as Map<String, dynamic>? ?? {};
      final repostedRaw = (repostsData['repostedTracks'] as List?) ?? [];
      final repostedIds = <String>{};
      for (final item in repostedRaw) {
        if (item is! Map<String, dynamic>) continue;
        final track =
            (item['target'] ?? item['track']) as Map<String, dynamic>?;
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
    for (final feedProvider in [discoverFeedProvider, followingFeedProvider]) {
      for (final track in ref.read(feedProvider).tracks) {
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
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    if (tab == _Tab.discover) {
      ref.read(discoverFeedProvider.notifier).load();
    } else {
      ref.read(followingFeedProvider.notifier).load();
    }
  }

  // ── Page change ─────────────────────────────────────────────────────────────

  void _onPageChanged(int index, List<FeedTrack> tracks) {
    if (index < 0 || index >= tracks.length) return;
    setState(() => _currentPage = index);
    final track = tracks[index];
    ref.read(playerProvider.notifier).playTrack(track.toPlayerTrack());
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(
      _tab == _Tab.discover ? discoverFeedProvider : followingFeedProvider,
    );

    // Seed engagement state and auto-play first track when feed loads.
    ref.listen(
      _tab == _Tab.discover ? discoverFeedProvider : followingFeedProvider,
      (prev, next) {
        // Use the pre-fetched liked/reposted ID sets for correct initial state.
        // If IDs haven't arrived yet, seed() is called again from
        // _reseedLoadedTracks() once _fetchUserInteractionIds() completes.
        for (final track in next.tracks) {
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
      body: Column(
        children: [
          // ── Tab toggle ──────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
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
                        isSelected: _tab == _Tab.discover,
                        onTap: () => _switchTab(_Tab.discover),
                      ),
                      _TabButton(
                        key: const ValueKey('feed_following_tab_button'),
                        label: 'Following',
                        isSelected: _tab == _Tab.following,
                        onTap: () => _switchTab(_Tab.following),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: _buildBody(feedState),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(FeedState feedState) {
    if (feedState.isLoading && feedState.tracks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    }

    if (feedState.error != null && feedState.tracks.isEmpty) {
      return _ErrorView(
        message: feedState.error!,
        onRetry: () {
          _loaded.remove(_tab);
          _ensureLoaded(_tab);
        },
      );
    }

    if (feedState.tracks.isEmpty) {
      return _EmptyView(tab: _tab);
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: feedState.tracks.length,
      onPageChanged: (i) => _onPageChanged(i, feedState.tracks),
      itemBuilder: (context, index) => FeedTrackCard(
        key: ValueKey(feedState.tracks[index].id),
        track: feedState.tracks[index],
        isActive: index == _currentPage,
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
