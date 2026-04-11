import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/upload_track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/upload_provider.dart';
import '../providers/my_tracks_provider.dart';

class LibraryUploadsPage extends ConsumerStatefulWidget {
  const LibraryUploadsPage({super.key});

  @override
  ConsumerState<LibraryUploadsPage> createState() => _LibraryUploadsPageState();
}

class _LibraryUploadsPageState extends ConsumerState<LibraryUploadsPage> {
  late TextEditingController _searchController;
  List<UploadTrack> _allTracks = [];
  List<UploadTrack> _filteredTracks = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredTracks = List.from(_allTracks);
      } else {
        _filteredTracks = _allTracks
            .where((track) =>
                track.title.toLowerCase().contains(query) ||
                track.artist.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    // Check Artist role before opening file picker — saves user from a failed upload attempt.
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? '';
    if (role.toLowerCase() != 'artist') {
      if (context.mounted) _showUpgradeRoleDialog(context);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null && context.mounted) {
          await ref
              .read(uploadProvider.notifier)
              .initializeUpload(audioFilePath: path);
          if (context.mounted) context.push('/upload');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUpgradeRoleDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Artist Role Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Only Artist accounts can upload tracks. Upgrade your account to start sharing your music.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            key: const ValueKey('uploads_role_cancel_button'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            key: const ValueKey('uploads_role_upgrade_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(uploadProvider.notifier).upgradeToArtist();
              if (!context.mounted) return;
              final uploadState = ref.read(uploadProvider);
              if (uploadState.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(uploadState.error!),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account upgraded! You can now upload tracks.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'Upgrade to Artist',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _playTrack(UploadTrack track) {
    // Build a queue from all currently displayed tracks that have a streamable
    // HLS URL. Tracks still processing (no hlsUrl) are excluded.
    final playableTracks = _filteredTracks
        .where((t) => t.hlsUrl != null && t.hlsUrl!.isNotEmpty)
        .toList();

    if (playableTracks.isEmpty) return;

    final queue = playableTracks
        .map((t) => PlayerTrack(
              id: t.id ?? t.hlsUrl!,
              title: t.title,
              artist: t.artist,
              audioUrl: t.hlsUrl!,
              coverUrl: t.artworkUrl,
              waveform: t.waveform,
            ))
        .toList();

    final startIndex = playableTracks.indexWhere(
      (t) => t.id != null && t.id == track.id,
    );

    ref.read(playerProvider.notifier).playQueue(
          queue,
          startIndex: startIndex < 0 ? 0 : startIndex,
        );
  }

  void _showTrackOptionsSheet(UploadTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('uploads_options_play_tile'),
                leading: const Icon(Icons.play_arrow, color: Colors.white),
                title:
                    const Text('Play', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _playTrack(track);
                },
              ),
              ListTile(
                key: const ValueKey('uploads_options_edit_tile'),
                leading: const Icon(Icons.edit, color: Colors.white),
                title:
                    const Text('Edit', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/library/uploads/edit');
                },
              ),
              ListTile(
                key: const ValueKey('track_options_visibility_button'),
                leading: const Icon(Icons.lock_outline, color: Colors.white),
                title: const Text('Change visibility',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                key: const ValueKey('track_options_download_button'),
                leading: const Icon(Icons.download_outlined,
                    color: Colors.white),
                title: const Text('Download',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                key: const ValueKey('uploads_options_delete_tile'),
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Track deleted')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final myTracksAsync = ref.watch(myTracksProvider);

    // Sync fetched tracks into local state whenever the provider resolves
    ref.listen<AsyncValue<List<UploadTrack>>>(myTracksProvider, (_, next) {
      next.whenData((tracks) {
        _allTracks = tracks;
        _applyFilter();
      });
    });

    // Both empty and populated states have the same structure now
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Your Uploads',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Builder(
              builder: (context) {
                // True only when the active track belongs to this page's list.
                final currentId = playerState.currentTrack?.id;
                final isFromThisPage = currentId != null &&
                    _filteredTracks.any((t) => t.id == currentId);
                final showPause = isFromThisPage && playerState.isPlaying;

                return GestureDetector(
                  key: const ValueKey('uploads_playpause_button'),
                  onTap: () {
                    if (isFromThisPage) {
                      ref.read(playerProvider.notifier).togglePlayPause();
                    } else if (_filteredTracks.isNotEmpty) {
                      _playTrack(_filteredTracks.first);
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1C1C1E),
                    ),
                    child: Icon(
                      showPause ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('uploads_search_field'),
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search in your uploads',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon:
                    Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        key: const ValueKey('uploads_search_clear_button'),
                        onTap: () {
                          _searchController.clear();
                        },
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
                ),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ),
          // Info pills section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.flash_on,
                            color: Color(0xFF9B3FFF), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'No Amplify credits',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_upload,
                            color: Color(0xFF5C8DFF), size: 16),
                        SizedBox(width: 6),
                        Text(
                          '24/120 mins used',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tracks list (loading / error / populated)
          Expanded(
            child: myTracksAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF5500),
                ),
              ),
              error: (e, stack) {
                // ignore: avoid_print
                print('[LibraryUploadsPage] fetch error: $e\n$stack');
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Failed to load uploads',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        key: const ValueKey('uploads_retry_button'),
                        onPressed: () => ref.invalidate(myTracksProvider),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Color(0xFFFF5500)),
                        ),
                      ),
                    ],
                  ),
                );
              },
              data: (_) => _filteredTracks.isEmpty
                  ? Center(
                      child: Text(
                        _allTracks.isEmpty
                            ? ''
                            : 'No results for "${_searchController.text}"',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                    itemCount: _filteredTracks.length,
                    itemBuilder: (context, index) {
                      final track = _filteredTracks[index];
                      final isCurrentTrack =
                          track.id != null &&
                          playerState.currentTrack?.id == track.id;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: GestureDetector(
                          key: const ValueKey('uploads_track_tile'),
                          onTap: () => _playTrack(track),
                          onLongPress: () => _showTrackOptionsSheet(track),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrentTrack
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // Track thumbnail
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3A3A3C),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: track.artworkUrl != null &&
                                          track.artworkUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: CachedNetworkImage(
                                            imageUrl: track.artworkUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                const Icon(
                                              Icons.graphic_eq,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        )
                                      : track.coverImagePath != null
                                          ? Image.file(
                                              File(track.coverImagePath!),
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.graphic_eq,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                ),
                                const SizedBox(width: 12),
                                // Track info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: isCurrentTrack
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (track.processingState != null &&
                                          track.processingState != 'Finished')
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              const SizedBox(
                                                width: 10,
                                                height: 10,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFFFF5500),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Processing',
                                                style: TextStyle(
                                                  color: Color(0xFFFF5500),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Options menu
                                GestureDetector(
                                  key: const ValueKey('uploads_track_options_button'),
                                  onTap: () => _showTrackOptionsSheet(track),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.more_vert,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('uploads_add_fab'),
        onPressed: () => _pickAndUpload(context),
        backgroundColor: const Color(0xFFFF5500),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
