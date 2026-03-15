import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MiniPlayerWidget extends ConsumerWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 56,
      color: const Color(0xFF1F1F1F),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          Icon(Icons.music_note, color: Colors.white54, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Track Title — Artist',
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.play_arrow, color: Colors.white),
          SizedBox(width: 8),
          Icon(Icons.skip_next, color: Colors.white),
        ],
      ),
    );
  }
}
