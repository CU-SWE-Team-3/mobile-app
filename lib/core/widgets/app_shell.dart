import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../themes/app_theme.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Expanded(child: navigationShell),
          // TODO: Module 5 (Ziad Awad) — replace with MiniPlayer widget
          const _MiniPlayerSlot(),
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
    return NavigationBar(
      backgroundColor: AppTheme.surface,
      indicatorColor: AppTheme.primary.withAlpha(51),
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, color: AppTheme.textSecondary),
          selectedIcon: Icon(Icons.home, color: AppTheme.primary),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.search, color: AppTheme.textSecondary),
          selectedIcon: Icon(Icons.search, color: AppTheme.primary),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(Icons.cloud_upload_outlined, color: AppTheme.textSecondary),
          selectedIcon: Icon(Icons.cloud_upload, color: AppTheme.primary),
          label: 'Upload',
        ),
        NavigationDestination(
          icon: Icon(Icons.library_music_outlined, color: AppTheme.textSecondary),
          selectedIcon: Icon(Icons.library_music, color: AppTheme.primary),
          label: 'Library',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
          selectedIcon: Icon(Icons.person, color: AppTheme.primary),
          label: 'You',
        ),
      ],
    );
  }
}

/// Placeholder for the persistent mini-player (Module 5).
/// Replace this with the real MiniPlayer widget once Module 5 is implemented.
class _MiniPlayerSlot extends StatelessWidget {
  const _MiniPlayerSlot();

  @override
  Widget build(BuildContext context) {
    // Returns empty by default — MiniPlayer will occupy this slot
    return const SizedBox.shrink();
  }
}
