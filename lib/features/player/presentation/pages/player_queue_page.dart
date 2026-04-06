import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';
import '../widgets/queue_item_tile.dart';

class PlayerQueuePage extends ConsumerWidget {
  const PlayerQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final queue = playerState.queue;
    final currentIndex = playerState.currentQueueIndex;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: Text(
          queue.isEmpty ? 'Queue' : 'Queue  ·  ${queue.length}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (queue.isNotEmpty)
            TextButton(
              onPressed: notifier.clearQueue,
              child: const Text(
                'Clear',
                style: TextStyle(color: Color(0xFFFF5500), fontSize: 14),
              ),
            ),
        ],
      ),
      body: queue.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music, color: Colors.white12, size: 72),
                  SizedBox(height: 16),
                  Text(
                    'Your queue is empty',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tracks you add will appear here',
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              // Drag handle is the rightmost icon in QueueItemTile;
              // set buildDefaultDragHandles to false so only that icon
              // triggers a drag and normal taps still fire onTap.
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) =>
                  notifier.reorderQueue(oldIndex, newIndex),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final track = queue[index];
                return ReorderableDragStartListener(
                  key: ValueKey('drag_$index'),
                  index: index,
                  child: QueueItemTile(
                    key: ValueKey(track.id),
                    track: track,
                    index: index,
                    isCurrentTrack: index == currentIndex,
                    onTap: () => notifier.skipToIndex(index),
                    onRemove: () => notifier.removeFromQueue(index),
                  ),
                );
              },
            ),
    );
  }
}
