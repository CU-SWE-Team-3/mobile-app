import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ── Temporary fake data — delete when backend is ready ──
final List<Map<String, dynamic>> _fakeUsers = [
  {"name": "Khalid", "country": "Egypt", "followers": 10, "image": "https://i.pravatar.cc/150?img=3"},
  {"name": "Ali", "country": "USA", "followers": 5, "image": null},
  {"name": "Mazen", "country": null, "followers": 2, "image": null},
  {"name": "Farghaly", "country": "Sheikh Zayed", "followers": 800, "image": "https://i.pravatar.cc/150?img=5"},
];

class FollowersListPage extends StatefulWidget {
  const FollowersListPage({super.key});

  @override
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage> {
  final Set<int> _following = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),  // ← fixed: was Navigator.pop(context)
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
          'Followers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Icon(Icons.cast, color: Colors.white),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _fakeUsers.length,
        itemBuilder: (context, index) {
          final user = _fakeUsers[index];
          final bool isFollowing = _following.contains(index);

          return InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: user["image"] != null
                        ? NetworkImage(user["image"] as String)
                        : null,
                    child: user["image"] == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),

                  const SizedBox(width: 15),

                  // Name + country + followers
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user["name"] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user["country"] != null)
                          Text(
                            user["country"] as String,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        Row(
                          children: [
                            const Icon(Icons.person,
                                color: Colors.grey, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              "${user["followers"]} Followers",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Follow button
                  SizedBox(
                    height: 36,
                    width: 110,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isFollowing ? Colors.grey[800] : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          if (isFollowing) {
                            _following.remove(index);
                            _fakeUsers[index]["followers"]--;
                          } else {
                            _following.add(index);
                            _fakeUsers[index]["followers"]++;
                          }
                        });
                      },
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
        },
      ),
    );
  }
}