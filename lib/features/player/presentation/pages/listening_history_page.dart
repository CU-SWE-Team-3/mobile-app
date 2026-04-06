import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/history_provider.dart';
import '../providers/player_provider.dart';

class ListeningHistoryPage extends ConsumerWidget {
  const ListeningHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);
    final notifier = ref.read(playerProvider.notifier);
    final historyNotifier = ref.read(historyProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Listening History',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (historyState.history.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, historyNotifier),
              child: const Text(
                'Clear',
                style: TextStyle(color: Color(0xFFFF5500), fontSize: 14),
              ),
            ),
        ],
      ),
      body: historyState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            )
          : historyState.history.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time,
                          color: Colors.white12, size: 72),
                      SizedBox(height: 16),
                      Text(
                        'No listening history yet',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your played tracks will be grouped by date',
                        style:
                            TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFFF5500),
                  backgroundColor: const Color(0xFF1A1A1A),
                  onRefresh: historyNotifier.refresh,
                  child: _GroupedHistoryList(
                    entries: historyState.history,
                    onTrackTap: (track) => notifier.playTrack(track),
                  ),
                ),
    );
  }

  void _confirmClear(
      BuildContext context, HistoryNotifier historyNotifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Clear history?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently remove all listening history.',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              historyNotifier.clearHistory();
            },
            child: const Text('Clear',
                style: TextStyle(color: Color(0xFFFF5500))),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped list widget
// ---------------------------------------------------------------------------

class _GroupedHistoryList extends StatelessWidget {
  final List<HistoryEntry> entries;
  final void Function(PlayerTrack track) onTrackTap;

  const _GroupedHistoryList({
    required this.entries,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(entries);
    final sections = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: sections.fold<int>(
        0,
        // +1 per section for the header row
        (sum, s) => sum + 1 + s.value.length,
      ),
      itemBuilder: (context, flatIndex) {
        // Walk through sections to find which item this flat index maps to.
        int cursor = 0;
        for (final section in sections) {
          if (flatIndex == cursor) {
            return _SectionHeader(label: section.key);
          }
          cursor++;
          final sectionEnd = cursor + section.value.length;
          if (flatIndex < sectionEnd) {
            final entry = section.value[flatIndex - cursor];
            return _HistoryTile(
              entry: entry,
              onTap: () => onTrackTap(entry.track),
            );
          }
          cursor = sectionEnd;
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Groups [entries] into labelled buckets: "Today", "Yesterday", "Earlier".
  /// The map is insertion-ordered (LinkedHashMap) so iteration order is stable.
  static Map<String, List<HistoryEntry>> _groupByDate(
      List<HistoryEntry> entries) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final today = <HistoryEntry>[];
    final yesterday = <HistoryEntry>[];
    final earlier = <HistoryEntry>[];

    for (final e in entries) {
      final d = e.playedAt;
      if (!d.isBefore(todayStart)) {
        today.add(e);
      } else if (!d.isBefore(yesterdayStart)) {
        yesterday.add(e);
      } else {
        earlier.add(e);
      }
    }

    return {
      if (today.isNotEmpty) 'Today': today,
      if (yesterday.isNotEmpty) 'Yesterday': yesterday,
      if (earlier.isNotEmpty) 'Earlier': earlier,
    };
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History tile
// ---------------------------------------------------------------------------

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final track = entry.track;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: track.coverUrl != null
            ? CachedNetworkImage(
                imageUrl: track.coverUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (_, __) => _coverFallback(),
                errorWidget: (_, __, ___) => _coverFallback(),
              )
            : _coverFallback(),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: Text(
        _formatTime(entry.playedAt),
        style: const TextStyle(color: Colors.white24, fontSize: 11),
      ),
      onTap: onTap,
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static Widget _coverFallback() => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(4),
        ),
        child:
            const Icon(Icons.music_note, color: Colors.white24, size: 22),
      );
}
