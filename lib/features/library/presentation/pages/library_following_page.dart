import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final List<Map<String, dynamic>> _fakeFollowing = [
  {
    "name": "z0z",
    "country": null,
    "followers": 3,
    "image": "https://i.pravatar.cc/150?img=1",
    "followsYouBack": true
  },
  {
    "name": "Mohamed Alabasy",
    "country": "Egypt",
    "followers": 2,
    "image": null,
    "followsYouBack": true
  },
  {
    "name": "Khalid",
    "country": "Egypt",
    "followers": 10,
    "image": "https://i.pravatar.cc/150?img=3",
    "followsYouBack": false
  },
  {
    "name": "Farghaly",
    "country": "Sheikh Zayed",
    "followers": 800,
    "image": "https://i.pravatar.cc/150?img=5",
    "followsYouBack": false
  },
];

// ─────────────────────────────────────────────
//  LIBRARY FOLLOWING PAGE
// ─────────────────────────────────────────────
class LibraryFollowingPage extends ConsumerStatefulWidget {
  const LibraryFollowingPage({super.key});

  @override
  ConsumerState<LibraryFollowingPage> createState() =>
      _LibraryFollowingPageState();
}

class _LibraryFollowingPageState extends ConsumerState<LibraryFollowingPage> {
  late Set<int> _following;

  @override
  void initState() {
    super.initState();
    _following = Set.from(List.generate(_fakeFollowing.length, (i) => i));
  }

  bool _isTrueFriend(int index) =>
      _fakeFollowing[index]["followsYouBack"] == true &&
      _following.contains(index);

  @override
  Widget build(BuildContext context) {
    final displayList = _fakeFollowing.asMap().entries.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Following',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        // ✅ Cast button updated
        actions: [
          IconButton(
            icon: const Icon(Icons.cast, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // ── "People who follow you back" banner ──────────────────
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrueFriendsPage(
                    following: _following,
                    onToggleFollow: (index) {
                      setState(() {
                        if (_following.contains(index)) {
                          _following.remove(index);
                          _fakeFollowing[index]["followers"]--;
                        } else {
                          _following.add(index);
                          _fakeFollowing[index]["followers"]++;
                        }
                      });
                    },
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'People who follow you back',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'See your true friends',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Following list ───────────────────────────────────────
          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Text(
                      'Not following anyone yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    itemCount: displayList.length,
                    itemBuilder: (context, i) {
                      final index = displayList[i].key;
                      final user = displayList[i].value;
                      final bool isFollowing = _following.contains(index);

                      return _UserTile(
                        user: user,
                        isFollowing: isFollowing,
                        onToggle: () {
                          setState(() {
                            if (isFollowing) {
                              _following.remove(index);
                              _fakeFollowing[index]["followers"]--;
                            } else {
                              _following.add(index);
                              _fakeFollowing[index]["followers"]++;
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TRUE FRIENDS PAGE
// ─────────────────────────────────────────────
class TrueFriendsPage extends StatefulWidget {
  final Set<int> following;
  final void Function(int index) onToggleFollow;

  const TrueFriendsPage({
    super.key,
    required this.following,
    required this.onToggleFollow,
  });

  @override
  State<TrueFriendsPage> createState() => _TrueFriendsPageState();
}

class _TrueFriendsPageState extends State<TrueFriendsPage> {
  late Set<int> _localFollowing;

  @override
  void initState() {
    super.initState();
    _localFollowing = Set.from(widget.following);
  }

  List<MapEntry<int, Map<String, dynamic>>> get _trueFriends => _fakeFollowing
      .asMap()
      .entries
      .where((e) =>
          e.value["followsYouBack"] == true && _localFollowing.contains(e.key))
      .toList();

  @override
  Widget build(BuildContext context) {
    final friends = _trueFriends;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Your true friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        // ✅ Cast button updated
        actions: [
          IconButton(
            icon: const Icon(Icons.cast, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: friends.isEmpty
          ? Center(
              child: Text(
                'No mutual followers yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            )
          : ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, i) {
                final index = friends[i].key;
                final user = friends[i].value;
                final bool isFollowing = _localFollowing.contains(index);

                return _UserTile(
                  user: user,
                  isFollowing: isFollowing,
                  onToggle: () {
                    setState(() {
                      if (isFollowing) {
                        _localFollowing.remove(index);
                        _fakeFollowing[index]["followers"]--;
                      } else {
                        _localFollowing.add(index);
                        _fakeFollowing[index]["followers"]++;
                      }
                    });
                    widget.onToggleFollow(index);
                  },
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────
//  REUSABLE USER TILE
// ─────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isFollowing;
  final VoidCallback onToggle;

  const _UserTile({
    required this.user,
    required this.isFollowing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage:
                  user["image"] != null ? NetworkImage(user["image"]) : null,
              child: user["image"] == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user["name"],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user["country"] != null)
                    Text(
                      user["country"],
                      style: const TextStyle(color: Colors.grey),
                    ),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        "${user["followers"]} Followers",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              width: 110,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFollowing ? Colors.grey[800] : Colors.white,
                  elevation: 0,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: onToggle,
                child: Text(
                  isFollowing ? "Following" : "Follow",
                  style: TextStyle(
                    color: isFollowing ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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