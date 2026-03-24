import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/features/library/presentation/pages/library_albums_page.dart';

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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  const Text(
                    'GET PRO',
                    style: TextStyle(
                      color: Color(0xFFFF5500),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.cast_rounded,
                        color: Colors.white, size: 22),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 1),

                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () => context.push('/settings'),
                  ),

                  const SizedBox(width: 4),

                  // Grey circle avatar with person icon — no photo
                  // Avatar → opens Profile page
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF2A2A2A),
                      child: Icon(Icons.person, color: Colors.white, size: 34),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Menu list ─────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {},
                color: const Color(0xFFFF5500),
                backgroundColor: const Color(0xFF1A1A1A),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _LibraryMenuItem(title: 'Your likes', onTap: () {}),
                    _LibraryMenuItem(title: 'Playlists', onTap: () {}),
                    _LibraryMenuItem(
                      title: 'Albums',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LibraryAlbumsPage()),
                      ),
                    ),
                    _LibraryMenuItem(
                      title: 'Following',
                      onTap: () => context.push('/library/following'),
                    ),
                    _LibraryMenuItem(
                      title: 'Stations',
                      onTap: () => context.push('/library/stations'),
                    ),
                    // ── Only this line changed ──────────────────────────
                    _LibraryMenuItem(
                      title: 'Your insights',
                      onTap: () => context.push('/library/insights'),
                    ),
                    _LibraryMenuItem(
                      title: 'Your uploads',
                      onTap: () => context.push('/library/uploads'),
                    ),

                    const SizedBox(height: 32),

                    // ── Recently played ───────────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Recently played',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Find all your recently played content here.',
                        style:
                            TextStyle(color: Color(0xFF999999), fontSize: 14),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Listening history ─────────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Listening history',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Find all the tracks you've listened to here.",
                        style:
                            TextStyle(color: Color(0xFF999999), fontSize: 14),
                      ),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
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

  const _LibraryMenuItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 15),
          ],
        ),
      ),
    );
  }
}
