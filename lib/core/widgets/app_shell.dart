import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/presentation/widgets/mini_player_widget.dart';


class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: navigationShell,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerWidget(),
          ),
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

// ── Bottom Nav Bar (Codex new style) ─────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  static const _items = <({String label, IconData active, IconData inactive})>[
    (label: 'Home', active: Icons.home, inactive: Icons.home_outlined),
    (label: 'Feed', active: Icons.web_asset, inactive: Icons.web_asset_outlined),
    (label: 'Search', active: Icons.search, inactive: Icons.search),
    (
      label: 'Library',
      active: Icons.library_music,
      inactive: Icons.library_music_outlined,
    ),
    (label: 'Upgrade', active: Icons.graphic_eq, inactive: Icons.graphic_eq),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        border: Border(top: BorderSide(color: Color(0xFF3B3B3B))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int index = 0; index < _items.length; index++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          currentIndex == index
                              ? _items[index].active
                              : _items[index].inactive,
                          color: currentIndex == index
                              ? Colors.white
                              : const Color(0xFFB4B4B4),
                          size: 27,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[index].label,
                          style: TextStyle(
                            color: currentIndex == index
                                ? Colors.white
                                : const Color(0xFFB4B4B4),
                            fontSize: 11,
                            fontWeight: currentIndex == index
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ],
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