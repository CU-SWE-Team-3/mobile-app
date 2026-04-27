import 'package:flutter/material.dart';

import '../pages/likers_list_page.dart';
import '../pages/reposters_list_page.dart';
import '../../../playlist/presentation/pages/add_to_playlist_page.dart';

class TrackOptionsSheet extends StatelessWidget {
  final String trackId;

  const TrackOptionsSheet({super.key, required this.trackId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.favorite_border, color: Colors.white70),
          title: const Text('People who liked this track',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LikersListPage(trackId: trackId)),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.repeat, color: Colors.white70),
          title: const Text('People who reposted this track',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RepostersListPage(trackId: trackId)),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.playlist_add, color: Colors.white70),
          title: const Text('Add to playlist',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddToPlaylistPage(trackId: trackId)),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
