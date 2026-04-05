import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/presentation/providers/player_provider.dart';
import '../themes/app_theme.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(child: navigationShell),
          // Hidden on Feed tab (index 1) — Feed manages its own mini player
          _MiniPlayerSlot(currentIndex: navigationShell.currentIndex),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF1A1A1A),
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: Colors.white.withAlpha(153),
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle:
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.dynamic_feed_outlined),
          activeIcon: Icon(Icons.dynamic_feed),
          label: 'Feed',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          activeIcon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.library_music_outlined),
          activeIcon: Icon(Icons.library_music),
          label: 'Library',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.graphic_eq),
          activeIcon: Icon(Icons.graphic_eq),
          label: 'Upgrade',
        ),
      ],
    );
  }
}

class _MiniPlayerSlot extends StatelessWidget {
  final int currentIndex;

  const _MiniPlayerSlot({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    // Feed tab (index 1) manages its own mini player — hide here
    if (currentIndex == 1) return const SizedBox.shrink();
    return const _MiniPlayerBar();
  }
}

class _MiniPlayerBar extends ConsumerStatefulWidget {
  const _MiniPlayerBar();

  @override
  ConsumerState<_MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<_MiniPlayerBar> {
  bool _isLiked = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final title = playerState.currentTrackTitle ?? 'No track playing';
    final artist = playerState.currentTrackArtist ?? '';
    final isPlaying = playerState.isPlaying;

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '♫  $title',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        artist,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_outlined,
                      color: Colors.white, size: 22),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? const Color(0xFFFF5500) : Colors.white,
                    size: 22,
                  ),
                  onPressed: () => setState(() => _isLiked = !_isLiked),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
