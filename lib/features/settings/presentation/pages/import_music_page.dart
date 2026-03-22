import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ImportMusicPage extends ConsumerWidget {
  const ImportMusicPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Import my music',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.cast_outlined),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Import from another app
            GestureDetector(
              onTap: () => context.push('/settings/import-music/import'),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Import from another app',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Move your playlists and likes from other apps to SoundCloud',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withOpacity(0.4),
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Divider
            Container(
              height: 0.5,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 20),

            // Section 2: Manage imported likes
            GestureDetector(
              onTap: () => context.push('/settings/import-music/manage'),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage imported likes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Remove imported likes or add them to a playlist',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withOpacity(0.4),
                    size: 24,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared provider grid page for both import and manage screens
class _ProviderGridPage extends ConsumerWidget {
  final String title;

  const _ProviderGridPage({required this.title});

  static const List<_ProviderInfo> providers = [
    _ProviderInfo(
      name: 'Spotify',
      color: Color(0xFF1DB954),
      logoBuilder: _spotifyLogo,
    ),
    _ProviderInfo(
      name: 'Apple Music',
      color: Color(0xFFFC3C44),
      logoBuilder: _appleMusicLogo,
    ),
    _ProviderInfo(
      name: 'Deezer',
      color: Color(0xFFA238FF),
      logoBuilder: _deezerLogo,
    ),
    _ProviderInfo(
      name: 'Tidal',
      color: Color(0xFF1E1E1E),
      logoBuilder: _tidalLogo,
    ),
    _ProviderInfo(
      name: 'Amazon Music',
      color: Color(0xFF1A2744),
      logoBuilder: _amazonMusicLogo,
    ),
    _ProviderInfo(
      name: 'Resso',
      color: Color(0xFFFF1D58),
      logoBuilder: _ressoLogo,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a provider',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: providers.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final provider = providers[index];
                return _buildProviderCard(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, _ProviderInfo provider) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              title.contains('Import')
                  ? 'Connecting to ${provider.name}...'
                  : 'Loading ${provider.name} likes...',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: provider.color,
          borderRadius: BorderRadius.circular(14),
          border: provider.name == 'Tidal'
              ? Border.all(color: Colors.white24, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            provider.logoBuilder(context),
          ],
        ),
      ),
    );
  }

  static Widget _spotifyLogo(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: const Icon(
            Icons.circle,
            color: Color(0xFF1DB954),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Spotify',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static Widget _appleMusicLogo(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.apple,
          color: Colors.white,
          size: 32,
        ),
        SizedBox(height: 8),
        Text(
          ' Music',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static Widget _deezerLogo(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.favorite,
          color: Colors.white,
          size: 32,
        ),
        SizedBox(height: 8),
        Text(
          'DEEZER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static Widget _tidalLogo(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '✦',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'TIDAL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  static Widget _amazonMusicLogo(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.music_note,
          color: Colors.white,
          size: 32,
        ),
        SizedBox(height: 4),
        Text(
          'amazon',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'music',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static Widget _ressoLogo(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'resso',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// Provider info model
class _ProviderInfo {
  final String name;
  final Color color;
  final Widget Function(BuildContext) logoBuilder;

  const _ProviderInfo({
    required this.name,
    required this.color,
    required this.logoBuilder,
  });
}

// Import from app page override for routing
class ImportFromAppPage extends ConsumerWidget {
  const ImportFromAppPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ProviderGridPage(title: 'Import music (1/3)');
  }
}

// Manage imported likes page override for routing
class ManageImportedLikesPage extends ConsumerWidget {
  const ManageImportedLikesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ProviderGridPage(title: 'Manage imported likes');
  }
}
