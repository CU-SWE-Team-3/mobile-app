import 'package:flutter/material.dart';

class SuggestedRow extends StatefulWidget {
  final String? title;

  const SuggestedRow({super.key, this.title});

  @override
  State<SuggestedRow> createState() => _SuggestedRowState();
}

class _SuggestedRowState extends State<SuggestedRow> {
  static const List<_MockUser> _users = [
    _MockUser('Flume',       '@flume',      '1.2M followers', Color(0xFF6C63FF)),
    _MockUser('deadmau5',    '@deadmau5',   '890K followers', Color(0xFFE53935)),
    _MockUser('Burial',      '@burial',     '340K followers', Color(0xFF37474F)),
    _MockUser('Four Tet',    '@fourtet',    '560K followers', Color(0xFF00897B)),
    _MockUser('Bicep',       '@bicep',      '780K followers', Color(0xFF1E88E5)),
    _MockUser('Aphex Twin',  '@aphextwin',  '1.5M followers', Color(0xFF8E24AA)),
    _MockUser('Bonobo',      '@bonobo',     '920K followers', Color(0xFF43A047)),
    _MockUser('ODESZA',      '@odesza',     '2.1M followers', Color(0xFFFF5500)),
  ];

  final Map<int, bool> _followingMap = {};

  void _toggleFollow(int index) {
    setState(() {
      _followingMap[index] = !(_followingMap[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final user = _users[index];
              final isFollowing = _followingMap[index] ?? false;
              return _UserCard(
                user: user,
                isFollowing: isFollowing,
                onToggle: () => _toggleFollow(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final _MockUser user;
  final bool isFollowing;
  final VoidCallback onToggle;

  const _UserCard({
    required this.user,
    required this.isFollowing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 25,
            backgroundColor: user.avatarColor,
            child: Text(
              user.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Name
          Text(
            user.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),

          // Username
          Text(
            user.username,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
          ),
          const SizedBox(height: 2),

          // Follower count
          Text(
            user.followerCount,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Follow / Following button
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              onPressed: onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFollowing ? const Color(0xFFFF5500) : Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  color: isFollowing ? Colors.white : Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockUser {
  final String name;
  final String username;
  final String followerCount;
  final Color avatarColor;

  const _MockUser(this.name, this.username, this.followerCount, this.avatarColor);
}
