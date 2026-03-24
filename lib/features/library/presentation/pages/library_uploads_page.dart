import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../domain/entities/upload_track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/upload_provider.dart';

class LibraryUploadsPage extends ConsumerStatefulWidget {
  const LibraryUploadsPage({super.key});

  @override
  ConsumerState<LibraryUploadsPage> createState() => _LibraryUploadsPageState();
}

class _LibraryUploadsPageState extends ConsumerState<LibraryUploadsPage> {
  late TextEditingController _searchController;
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
    final allTracks = ref.read(uploadedTracksProvider);
    setState(() {
      if (query.isEmpty) {
        _filteredTracks = List.from(allTracks);
      } else {
        _filteredTracks = allTracks
            .where((track) =>
                track.title.toLowerCase().contains(query) ||
                track.artist.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _pickAndUpload(BuildContext context) async {
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

  void _playTrack(UploadTrack track) {
    if (track.audioFilePath != null) {
      ref.read(playerProvider.notifier).playTrackFromFile(
            filePath: track.audioFilePath!,
            title: track.title,
            artist: track.artist,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Now playing: ${track.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
                leading: const Icon(Icons.play_arrow, color: Colors.white),
                title:
                    const Text('Play', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _playTrack(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title:
                    const Text('Edit', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/library/uploads/edit');
                },
              ),
              ListTile(
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
    final uploadedTracks = ref.watch(uploadedTracksProvider);

    // Update filtered tracks when the provider changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilter();
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
            child: GestureDetector(
              onTap: () {
                if (playerState.currentTrackPath != null) {
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
                  playerState.isPlaying && playerState.currentTrackPath != null
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
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
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search in your uploads',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon:
                    Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
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
          // Tracks list (empty or populated)
          Expanded(
            child: _filteredTracks.isEmpty
                ? Center(
                    child: Text(
                      uploadedTracks.isEmpty
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
                          playerState.currentTrackPath == track.audioFilePath;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: GestureDetector(
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
                                  child: track.coverImagePath != null
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
                                    ],
                                  ),
                                ),
                                // Options menu
                                GestureDetector(
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUpload(context),
        backgroundColor: const Color(0xFFFF5500),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
