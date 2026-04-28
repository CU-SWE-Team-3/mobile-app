import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/profile_navigation.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/search_section_header.dart';

// ── Genre definition (preserved from the original SearchPage) ─────────────────

class _Genre {
  final String name;
  final String assetPath;
  final Color color;
  final int imageWidth;
  final int imageHeight;
  const _Genre(
      this.name, this.assetPath, this.color, this.imageWidth, this.imageHeight);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _bg = Color(0xFF1A1A1A);
  static const _orange = Color(0xFFFF5500);
  static const _fieldBg = Color(0xFF343434);

  static const List<_Genre> _genres = [
    _Genre('Hip Hop & Rap', 'assets/images/HipHop_&_Rap.png',
        Color(0xFFFF5500), 502, 443),
    _Genre('Electronic', 'assets/images/Electronic.png', Color(0xFF1A6EDD),
        434, 575),
    _Genre('Pop', 'assets/images/Pop.png', Color(0xFFDD1A8C), 431, 579),
    _Genre('R&B', 'assets/images/R&B.png', Color(0xFF9B59B6), 495, 206),
    _Genre('Chill', 'assets/images/Chill.png', Color(0xFF1AAD6E), 501, 212),
    _Genre('Party', 'assets/images/Party.png', Color(0xFFDDAA1A), 500, 429),
    _Genre(
        'Workout', 'assets/images/Workout.png', Color(0xFFE53935), 510, 489),
    _Genre('Techno', 'assets/images/Techno.png', Color(0xFF5C6BC0), 416, 600),
    _Genre('House', 'assets/images/House.png', Color(0xFF7B1FA2), 416, 600),
    _Genre('Feel Good', 'assets/images/Feel_good.png', Color(0xFF43A047), 548,
        264),
    _Genre(
        'At Home', 'assets/images/At_home.png', Color(0xFFFF8F00), 556, 274),
    _Genre('Healing Era', 'assets/images/Healing_era.png', Color(0xFF00897B),
        511, 488),
  ];

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Field callbacks ───────────────────────────────────────────────────────

  void _onQueryChanged(String value) {
    ref.read(searchProvider.notifier).onQueryChanged(value);
    setState(() {}); // refresh suffix icon
  }

  void _onSubmitted(String value) {
    FocusScope.of(context).unfocus();
    ref.read(searchProvider.notifier).submit(value);
  }

  void _clearAndReset() {
    _controller.clear();
    _focusNode.unfocus();
    ref.read(searchProvider.notifier).reset();
  }

  // ── Navigation + history helpers ─────────────────────────────────────────

  Future<void> _tapTrack(SearchResultTrack track) async {
    await ref
        .read(searchProvider.notifier)
        .saveToHistory(SearchHistoryEntry.fromTrack(track));
    if (!mounted) return;
    ref.read(playerProvider.notifier).playQueue(
      [
        PlayerTrack(
          id: track.id,
          title: track.title,
          artist: track.artistName,
          audioUrl: track.hlsUrl,
          coverUrl: track.artworkUrl,
          duration: track.durationSeconds != null
              ? Duration(seconds: track.durationSeconds!)
              : null,
          artistId: track.artistId,
          artistPermalink: track.artistPermalink,
        )
      ],
      startIndex: 0,
    );
  }

  Future<void> _tapUser(SearchResultUser user) async {
    await ref
        .read(searchProvider.notifier)
        .saveToHistory(SearchHistoryEntry.fromUser(user));
    if (!mounted) return;
    await navigateToUserProfile(
      context,
      userId: user.id,
      permalink: user.permalink ?? '',
      displayName: user.displayName,
    );
  }

  Future<void> _tapPlaylist(SearchResultPlaylist playlist) async {
    await ref
        .read(searchProvider.notifier)
        .saveToHistory(SearchHistoryEntry.fromPlaylist(playlist));
    if (!mounted) return;
    context.push('/playlist', extra: {'playlistId': playlist.id});
  }

  Future<void> _tapHistoryEntry(SearchHistoryEntry entry) async {
    await ref
        .read(searchProvider.notifier)
        .saveToHistory(entry.copyWith(addedAt: DateTime.now()));
    if (!mounted) return;
    switch (entry.type) {
      case SearchEntityType.track:
        if (entry.hlsUrl != null && entry.hlsUrl!.isNotEmpty) {
          ref.read(playerProvider.notifier).playQueue(
            [
              PlayerTrack(
                id: entry.id,
                title: entry.displayName,
                artist: entry.subtitle,
                audioUrl: entry.hlsUrl!,
                coverUrl: entry.imageUrl,
                artistId: entry.artistId,
              )
            ],
            startIndex: 0,
          );
        }
      case SearchEntityType.user:
        if (mounted) {
          await navigateToUserProfile(
            context,
            userId: entry.id,
            permalink: entry.permalink ?? '',
            displayName: entry.displayName,
          );
        }
      case SearchEntityType.playlist:
        if (mounted) {
          context.push('/playlist', extra: {'playlistId': entry.id});
        }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search field ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const ValueKey('search_field'),
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white),
                cursorColor: _orange,
                onSubmitted: _onSubmitted,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search tracks, artists, playlists...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _controller.text.isNotEmpty
                      ? GestureDetector(
                          key: const ValueKey('search_clear_button'),
                          onTap: _clearAndReset,
                          child:
                              const Icon(Icons.close, color: Colors.white38),
                        )
                      : null,
                  filled: true,
                  fillColor: _fieldBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // ── Tab bar — results mode only ───────────────────────────────
            if (state.mode == SearchMode.results)
              _TabBar(
                selected: state.filter,
                onChanged: (f) =>
                    ref.read(searchProvider.notifier).setFilter(f),
              ),
            // ── Body ─────────────────────────────────────────────────────
            Expanded(child: _body(state)),
          ],
        ),
      ),
    );
  }

  Widget _body(SearchState state) {
    return switch (state.mode) {
      SearchMode.idle => _VibesGrid(genres: _genres),
      SearchMode.history => _historyPanel(state.history),
      SearchMode.results => _resultsBody(state),
    };
  }

  // ── History panel ─────────────────────────────────────────────────────────

  Widget _historyPanel(List<SearchHistoryEntry> history) {
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'No recent searches',
              style: TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: history.length,
      itemBuilder: (_, i) {
        final entry = history[i];
        return SearchResultTile(
          displayName: entry.displayName,
          subtitle: entry.subtitle,
          imageUrl: entry.imageUrl,
          type: entry.type,
          onTap: () => _tapHistoryEntry(entry),
          onRemove: () => ref
              .read(searchProvider.notifier)
              .removeHistoryEntry(entry.id, entry.type),
        );
      },
    );
  }

  // ── Results body ──────────────────────────────────────────────────────────

  Widget _resultsBody(SearchState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _orange),
      );
    }

    if (state.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Search failed. Please try again.',
              style: TextStyle(color: Colors.grey[400], fontSize: 15),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey('search_retry_button'),
              onPressed: () =>
                  ref.read(searchProvider.notifier).submit(state.query),
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              child:
                  const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (!state.hasResults) {
      return Center(
        child: Text(
          'No results for "${state.query}"',
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (state.visibleTracks.isNotEmpty) ...[
          const SearchSectionHeader('Tracks'),
          for (final t in state.visibleTracks)
            SearchResultTile(
              displayName: t.title,
              subtitle: t.artistName,
              imageUrl: t.artworkUrl,
              type: SearchEntityType.track,
              onTap: () => _tapTrack(t),
            ),
        ],
        if (state.visibleUsers.isNotEmpty) ...[
          const SearchSectionHeader('Artists'),
          for (final u in state.visibleUsers)
            SearchResultTile(
              displayName: u.displayName,
              subtitle: u.bio != null && u.bio!.isNotEmpty
                  ? u.bio!
                  : '${u.followerCount} followers',
              imageUrl: u.avatarUrl,
              type: SearchEntityType.user,
              onTap: () => _tapUser(u),
            ),
        ],
        if (state.visiblePlaylists.isNotEmpty) ...[
          const SearchSectionHeader('Playlists'),
          for (final p in state.visiblePlaylists)
            SearchResultTile(
              displayName: p.title,
              subtitle: p.creatorName ?? '',
              imageUrl: p.artworkUrl,
              type: SearchEntityType.playlist,
              onTap: () => _tapPlaylist(p),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Tab Bar ───────────────────────────────────────────────────────────────────
//
// Each tab occupies exactly (viewportWidth / 4). With 5 tabs the total
// scrollable content is 5/4 of the viewport, so the 5th tab peeks out,
// signalling scrollability. The orange underline is also (viewportWidth / 4)
// wide, so it always spans exactly one tab — i.e. one-quarter of the visible
// bar — matching the SoundCloud indicator style.

class _TabBar extends StatefulWidget {
  final SearchFilter selected;
  final ValueChanged<SearchFilter> onChanged;
  const _TabBar({required this.selected, required this.onChanged});

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (filter: SearchFilter.all,       label: 'All'),
    (filter: SearchFilter.tracks,    label: 'Tracks'),
    (filter: SearchFilter.users,     label: 'Profiles'),
    (filter: SearchFilter.playlists, label: 'Playlists'),
    (filter: SearchFilter.albums,    label: 'Albums'),
  ];

  static const _orange = Color(0xFFFF5500);
  static const _indicatorH = 2.0;
  static const _barH = 44.0;

  late final AnimationController _animCtrl;
  late Animation<double> _indicatorAnim;
  final _scrollCtrl = ScrollController();

  // Set on first LayoutBuilder call; used by didUpdateWidget & _onTabTap.
  double _tabWidth = 0;

  int get _selectedIndex =>
      _tabs.indexWhere((t) => t.filter == widget.selected);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Begin at x=0 (All tab). Will snap to correct position on first layout
    // if the initial filter differs (rare — provider defaults to 'all').
    _indicatorAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_TabBar old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected && _tabWidth > 0) {
      _animateIndicatorTo(_selectedIndex * _tabWidth);
    }
  }

  void _animateIndicatorTo(double targetX) {
    final fromX = _indicatorAnim.value;
    _indicatorAnim = Tween<double>(begin: fromX, end: targetX).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
    _animCtrl.forward(from: 0);
  }

  void _onTabTap(int index) {
    // Delegate filter change to parent; animation fires via didUpdateWidget.
    widget.onChanged(_tabs[index].filter);

    // Scroll the row so the tapped tab is centered in the viewport.
    if (_scrollCtrl.hasClients) {
      final viewportW = _scrollCtrl.position.viewportDimension;
      final targetOffset =
          (index * _tabWidth) - (viewportW / 2 - _tabWidth / 2);
      _scrollCtrl.animateTo(
        targetOffset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final newTabWidth = constraints.maxWidth / 4;

        // Snap indicator to correct position without animation on first layout.
        if (_tabWidth == 0 && newTabWidth > 0) {
          _tabWidth = newTabWidth;
          final initialX = _selectedIndex * _tabWidth;
          _indicatorAnim = AlwaysStoppedAnimation<double>(initialX);
        } else {
          _tabWidth = newTabWidth;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _barH,
              child: Stack(
                children: [
                  // ── Tab labels ────────────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(_tabs.length, (i) {
                        final selected = i == _selectedIndex;
                        return SizedBox(
                          width: _tabWidth,
                          height: _barH,
                          child: GestureDetector(
                            onTap: () => _onTabTap(i),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Text(
                                _tabs[i].label,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // ── Sliding underline indicator ───────────────────────
                  AnimatedBuilder(
                    animation:
                        Listenable.merge([_animCtrl, _scrollCtrl]),
                    builder: (_, __) {
                      final scrollOffset = _scrollCtrl.hasClients
                          ? _scrollCtrl.offset
                          : 0.0;
                      // Convert content-space x → viewport-space x.
                      final viewportX =
                          _indicatorAnim.value - scrollOffset;
                      return Positioned(
                        left: viewportX,
                        bottom: 0,
                        width: _tabWidth,
                        height: _indicatorH,
                        child: Container(color: _orange),
                      );
                    },
                  ),
                ],
              ),
            ),
            // ── Full-width divider below all tabs ─────────────────────────
            Container(height: 0.5, color: Colors.white12),
          ],
        );
      },
    );
  }
}

// ── Vibes Grid (preserved from original SearchPage) ───────────────────────────

class _VibesGrid extends StatelessWidget {
  final List<_Genre> genres;
  const _VibesGrid({required this.genres});

  @override
  Widget build(BuildContext context) {
    const gap = 2.0;
    final left = [for (int i = 0; i < genres.length; i += 2) genres[i]];
    final right = [for (int i = 1; i < genres.length; i += 2) genres[i]];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vibes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < left.length; i++) ...[
                      _GenreCard(genre: left[i]),
                      if (i < left.length - 1) const SizedBox(height: gap),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < right.length; i++) ...[
                      _GenreCard(genre: right[i]),
                      if (i < right.length - 1) const SizedBox(height: gap),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final _Genre genre;
  const _GenreCard({required this.genre});

  String get _route => switch (genre.name) {
        'Hip Hop & Rap' => '/home/genre/hiphop',
        'Electronic' => '/home/genre/electronic',
        'Pop' => '/home/genre/pop',
        'R&B' => '/home/genre/rnb',
        'Chill' => '/home/genre/chill',
        _ => '/search/genre/${Uri.encodeComponent(genre.name)}',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(_route),
      child: AspectRatio(
        aspectRatio: genre.imageWidth / genre.imageHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(genre.assetPath, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
