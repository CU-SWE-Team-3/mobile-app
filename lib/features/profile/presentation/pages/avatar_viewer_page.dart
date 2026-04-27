import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AvatarViewerPage extends StatelessWidget {
  const AvatarViewerPage({super.key});

  static const Color _bg = Color(0xFF1A1A1A);
  static const Color _orange = Color(0xFFFF5500);

  @override
  Widget build(BuildContext context) {
    final double circleSize = MediaQuery.of(context).size.width * 0.78;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── circle photo centered ──────────────────────────────────
            Center(
              child: GestureDetector(
                key: const ValueKey('profile_avatar_viewer_edit_button'),
                onTap: () => context.go('/profile/avatar'),
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const CircleAvatar(
                    radius: double.infinity,
                    backgroundColor: Color(0xFF6699BB),
                    child: Icon(
                      Icons.person,
                      size: 120,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),

            // ── X close button top-left ────────────────────────────────
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                key: const ValueKey('profile_avatar_viewer_close_button'),
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/profile'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // ── camera FAB bottom-right ────────────────────────────────
            Positioned(
              bottom: 32,
              right: 28,
              child: GestureDetector(
                key: const ValueKey('profile_avatar_viewer_camera_button'),
                onTap: () => context.go('/profile/avatar'),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _orange.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 24,
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