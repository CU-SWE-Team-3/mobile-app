import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ── mutable profile data (updated when edit page saves) ──────────────
  String _username = 'SUNDER';
  String _bio = 'I know that it is thunder not sunder';
  String _city = '';
  String _country = '';
  bool _bioExpanded = false;

  final _tracks = const [
    _Track('It_is_realme.mp3', 'SUNDER', '1:20'),
    _Track('I am in tiny room', 'SUNDER', '2:44'),
  ];

  final _likes = const [
    _Track('🕊♡without a trace @@2rel', 'Alis', '2:12',
        likeColor: Colors.purple),
    _Track('Girls Like You - Maroon 5 ft. ...', 'Hiderway', '4:57',
        likeColor: Colors.red),
  ];

  final _playlists = const [_Playlist('my songs', 'SUNDER')];

  // ── colors ───────────────────────────────────────────────────────────
  static const _bg = Color(0xFF111111);
  static const _surface = Color(0xFF1E1E1E);
  static const _orange = Color(0xFFFF5500);
  static final _sub = Colors.white.withOpacity(0.55);

  // ── navigate to edit and receive result ──────────────────────────────
  Future<void> _openEdit() async {
    final result = await context.push<Map<String, String>>(
      '/profile/edit',
      extra: {
        'username': _username,
        'city': _city,
        'country': _country,
        'bio': _bio,
      },
    );
    // If edit page returned data → update profile
    if (result != null && mounted) {
      setState(() {
        _username = result['username'] ?? _username;
        _city = result['city'] ?? _city;
        _country = result['country'] ?? _country;
        _bio = result['bio'] ?? _bio;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroSection(context),
                    _bioSection(),
                    _insightsRow(context),
                    _spotlight(),
                    _sectionHeader('Tracks',
                        onSeeAll: () => context.push('/profile/tracks')),
                    ..._tracks.map((t) => _TrackTile(
                          track: t,
                          onTap: () => context.push('/player'),
                          onMore: () {},
                        )),
                    _sectionHeader('Playlists'),
                    _playlistRow(context),
                    _sectionHeader('Likes', onSeeAll: () {}),
                    ..._likes.map((t) => _TrackTile(
                          track: t,
                          onTap: () {},
                          onMore: () {},
                          showHeart: true,
                        )),
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

  // ── top bar ──────────────────────────────────────────────────────────
  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _iconBtn(Icons.arrow_back_ios_new_rounded,
                () => Navigator.of(context).maybePop()),
            const Spacer(),
            _iconBtn(Icons.cast_rounded, () {}),
            const SizedBox(width: 8),
            _iconBtn(Icons.more_vert_rounded, () {}),
          ],
        ),
      );

  // ── hero ─────────────────────────────────────────────────────────────
  Widget _heroSection(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar — tap to view fullscreen
            GestureDetector(
              onTap: () => context.push('/profile/avatar-view'),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _orange, width: 2.5),
                ),
                child: const CircleAvatar(
                  radius: 42,
                  backgroundColor: Color(0xFF6699BB),
                  child:
                      Icon(Icons.person, size: 48, color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Username
            Text(
              _username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            // City / Country subtitle
            if (_city.isNotEmpty || _country.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  [_city, _country]
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                  style: TextStyle(color: _sub, fontSize: 13),
                ),
              ),
            // Follower / Following
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/followers'),
                  child: Text('1 Follower',
                      style: TextStyle(color: _sub, fontSize: 13)),
                ),
                Text('  ·  ',
                    style: TextStyle(color: _sub, fontSize: 13)),
                GestureDetector(
                  onTap: () => context.push('/profile/following'),
                  child: Text('2 Following',
                      style: TextStyle(color: _sub, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action row
            Row(
              children: [
                // Edit button → pushes EditProfilePage, awaits result
                GestureDetector(
                  onTap: _openEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Edit',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _iconCircle(Icons.shuffle_rounded, () {}),
                const SizedBox(width: 12),
                _playCircle(context),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      );

  // ── bio ──────────────────────────────────────────────────────────────
  Widget _bioSection() {
    if (_bio.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bio,
            maxLines: _bioExpanded ? null : 2,
            overflow: _bioExpanded ? null : TextOverflow.ellipsis,
            style:
                TextStyle(color: _sub, fontSize: 14, height: 1.5),
          ),
          if (_bio.length > 60)
            GestureDetector(
              onTap: () =>
                  setState(() => _bioExpanded = !_bioExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    _bioExpanded ? 'Show less' : 'Show more',
                    style: TextStyle(
                        color: Colors.blue[400],
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
  }

  // ── insights (button only, no navigation) ────────────────────────────
  Widget _insightsRow(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Text('Your insights',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: _sub, size: 20),
          ],
        ),
      );

  // ── spotlight ────────────────────────────────────────────────────────
  Widget _spotlight() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Pinned to Spotlight',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Edit',
                        style: TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Pin items to your Spotlight',
                style: TextStyle(color: _sub, fontSize: 13)),
          ],
        ),
      );

  // ── section header ───────────────────────────────────────────────────
  Widget _sectionHeader(String title, {VoidCallback? onSeeAll}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('See All',
                      style: TextStyle(
                          color: Colors.white, fontSize: 13)),
                ),
              ),
          ],
        ),
      );

  // ── playlist row ─────────────────────────────────────────────────────
  Widget _playlistRow(BuildContext context) => SizedBox(
        height: 215,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _playlists.length,
          itemBuilder: (_, i) {
            final p = _playlists[i];
            return GestureDetector(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 150,
                          height: 150,
                          color: Colors.grey[850],
                          child: const Icon(Icons.queue_music,
                              size: 52, color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.owner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

  // ── helpers ──────────────────────────────────────────────────────────
  Widget _iconBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Widget _iconCircle(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  Widget _playCircle(BuildContext context) => GestureDetector(
        onTap: () => context.push('/player'),
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.black, size: 28),
        ),
      );
}

// ── data models ──────────────────────────────────────────────────────────
class _Track {
  final String title;
  final String artist;
  final String duration;
  final Color? likeColor;
  const _Track(this.title, this.artist, this.duration, {this.likeColor});
}

class _Playlist {
  final String name;
  final String owner;
  const _Playlist(this.name, this.owner);
}

// ── track tile ───────────────────────────────────────────────────────────
class _TrackTile extends StatelessWidget {
  final _Track track;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final bool showHeart;

  const _TrackTile({
    required this.track,
    required this.onTap,
    required this.onMore,
    this.showHeart = false,
  });

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withOpacity(0.55);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 56,
                height: 56,
                color: track.likeColor ?? const Color(0xFF2A2A2A),
                child: const Icon(Icons.music_note,
                    color: Colors.white38, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(track.artist,
                      style:
                          TextStyle(color: sub, fontSize: 12)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 13, color: sub),
                      Text('  ${track.duration}',
                          style:
                              TextStyle(color: sub, fontSize: 11)),
                      if (showHeart) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.favorite,
                            size: 13, color: Colors.redAccent),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onMore,
              child: Icon(Icons.more_vert_rounded,
                  color: sub, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}