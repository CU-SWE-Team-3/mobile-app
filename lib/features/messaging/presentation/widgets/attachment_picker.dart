import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/attachment_picker_item.dart';
import '../providers/messaging_providers.dart';

/// Modal bottom sheet with Tracks and Playlists tabs.
/// Returns the selected [AttachmentPickerItem] via Navigator.pop, or null if dismissed.
class AttachmentPickerSheet extends ConsumerStatefulWidget {
  const AttachmentPickerSheet({super.key});

  @override
  ConsumerState<AttachmentPickerSheet> createState() =>
      _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState extends ConsumerState<AttachmentPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _trackQueryCtrl = TextEditingController();
  final _playlistQueryCtrl = TextEditingController();

  List<AttachmentPickerItem> _trackResults = [];
  List<AttachmentPickerItem> _playlistResults = [];
  bool _isSearchingTracks = false;
  bool _isSearchingPlaylists = false;

  Timer? _trackDebounce;
  Timer? _playlistDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _trackQueryCtrl.dispose();
    _playlistQueryCtrl.dispose();
    _trackDebounce?.cancel();
    _playlistDebounce?.cancel();
    super.dispose();
  }

  void _onTrackQueryChanged(String query) {
    _trackDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _trackResults = []);
      return;
    }
    _trackDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchTracks(query),
    );
  }

  void _onPlaylistQueryChanged(String query) {
    _playlistDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _playlistResults = []);
      return;
    }
    _playlistDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchPlaylists(query),
    );
  }

  Future<void> _searchTracks(String query) async {
    setState(() => _isSearchingTracks = true);
    try {
      final results = await ref
          .read(messagingRepositoryProvider)
          .searchTracks(query.trim());
      if (!mounted) return;
      setState(() {
        _trackResults = results;
        _isSearchingTracks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearchingTracks = false);
    }
  }

  Future<void> _searchPlaylists(String query) async {
    setState(() => _isSearchingPlaylists = true);
    try {
      final results = await ref
          .read(messagingRepositoryProvider)
          .searchPlaylists(query.trim());
      if (!mounted) return;
      setState(() {
        _playlistResults = results;
        _isSearchingPlaylists = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearchingPlaylists = false);
    }
  }

  void _selectItem(AttachmentPickerItem item) {
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title row
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFFF5500),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFFFF5500),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Tracks'),
              Tab(text: 'Playlists'),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SearchTab(
                  controller: _trackQueryCtrl,
                  hintText: 'Search tracks...',
                  isLoading: _isSearchingTracks,
                  results: _trackResults,
                  defaultIcon: Icons.music_note_rounded,
                  emptyLabel: 'Search for a track to share',
                  onChanged: _onTrackQueryChanged,
                  onSelect: _selectItem,
                ),
                _SearchTab(
                  controller: _playlistQueryCtrl,
                  hintText: 'Search playlists...',
                  isLoading: _isSearchingPlaylists,
                  results: _playlistResults,
                  defaultIcon: Icons.queue_music_rounded,
                  emptyLabel: 'Search for a playlist to share',
                  onChanged: _onPlaylistQueryChanged,
                  onSelect: _selectItem,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search tab (shared by Tracks and Playlists) ───────────────────────────────

class _SearchTab extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isLoading;
  final List<AttachmentPickerItem> results;
  final IconData defaultIcon;
  final String emptyLabel;
  final ValueChanged<String> onChanged;
  final ValueChanged<AttachmentPickerItem> onSelect;

  const _SearchTab({
    required this.controller,
    required this.hintText,
    required this.isLoading,
    required this.results,
    required this.defaultIcon,
    required this.emptyLabel,
    required this.onChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle:
                  const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white38,
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              suffixIcon: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF5500),
                        ),
                      ),
                    )
                  : null,
            ),
            onChanged: onChanged,
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    emptyLabel,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) => _ResultTile(
                    item: results[i],
                    defaultIcon: defaultIcon,
                    onTap: () => onSelect(results[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Individual result row ─────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final AttachmentPickerItem item;
  final IconData defaultIcon;
  final VoidCallback onTap;

  const _ResultTile({
    required this.item,
    required this.defaultIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasArtwork = item.artworkUrl != null &&
        item.artworkUrl!.isNotEmpty &&
        !item.artworkUrl!.contains('default-artwork');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: item.artworkUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _artworkPlaceholder(defaultIcon),
                    )
                  : _artworkPlaceholder(defaultIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artworkPlaceholder(IconData icon) => Container(
        width: 44,
        height: 44,
        color: const Color(0xFF333333),
        child: Icon(icon, color: Colors.white24, size: 18),
      );
}
