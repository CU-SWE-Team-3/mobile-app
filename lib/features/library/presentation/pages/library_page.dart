import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/features/settings/presentation/pages/settings_main_page.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [

            // ── AppBar ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 10),

                  const Text(
                    'GET PRO',
                    style: TextStyle(
                      color: Color(0xFFFF5500),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  IconButton(
                    icon: const Icon(Icons.cast, color: Colors.white, size: 22),
                    onPressed: () {},
                  ),

                  // Settings icon → opens Settings page
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsMainPage()),
                    ),
                  ),

                  // Avatar → opens Profile page
                  GestureDetector(
                    onTap: () => context.push('/profile'), // 👈 added
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF2A2A2A),
                      child:
                          Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Menu list ─────────────────────
            Expanded(
              child: ListView(
                children: [
                  _LibraryMenuItem(title: 'Your likes', onTap: () {}),
                  _LibraryMenuItem(title: 'Playlists', onTap: () {}),
                  _LibraryMenuItem(title: 'Albums', onTap: () {}),
                  _LibraryMenuItem(
                    title: 'Following',
                    onTap: () => context.push('/library/following'),
                  ),
                  _LibraryMenuItem(title: 'Stations', onTap: () {}),
                  _LibraryMenuItem(title: 'Your insights', onTap: () {}),
                  _LibraryMenuItem(title: 'Your uploads', onTap: () {}),

                  const SizedBox(height: 28),

                  // ── Recently played ───────────
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Recently played',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Find all your recently played content here.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── Listening history ─────────
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Listening history',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Find all the tracks you've listened to here.",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _LibraryMenuItem({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
        const Divider(
          color: Color(0xFF1F1F1F),
          height: 1,
          thickness: 1,
        ),
      ],
    );
  }
}