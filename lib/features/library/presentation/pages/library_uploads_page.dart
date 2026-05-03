import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../../engagement/presentation/widgets/track_options_sheet.dart';
import '../../domain/entities/upload_track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../premium/presentation/providers/subscription_provider.dart';
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
  final Set<String> _deletingTrackIds = <String>{};
  String _currentDisplayName = '';
  bool _uploadBtnPressed = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_applyFilter);
    _loadCurrentDisplayName();
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

  Future<void> _loadCurrentDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final displayName = prefs.getString('displayName') ??
        prefs.getString('username') ??
        prefs.getString('name') ??
        '';
    if (!mounted) return;
    setState(() {
      _currentDisplayName = displayName;
    });
  }

  String _resolvedArtistName(UploadTrack track) {
    return track.artist.isNotEmpty ? track.artist : _currentDisplayName;
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    // Module 12: Free/Go+ users can upload up to 3 tracks; Artist Pro/Pro is
    // unlimited. Download permission is separate and belongs to Go+ only.
    await ref.read(subscriptionProvider.notifier).refreshFromProfile();
    final sub = ref.read(subscriptionProvider);
    debugPrint(
      '[Upload] entitlement — isPremium=${sub.isPremium}, '
      'planType=${sub.planType ?? "null"}, '
      'canUploadUnlimited=${sub.canUploadUnlimited}, '
      'canDownload=${sub.canDownload}',
    );
    if (!sub.canUploadUnlimited && _allTracks.length >= 3) {
      if (context.mounted) _showUploadLimitDialog(context);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav'],
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

  void _showAmplifyInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.flash_on, color: Color(0xFF9B3FFF), size: 22),
            SizedBox(width: 10),
            Text('Amplify Credits',
                style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Amplify uses AI to recommend your tracks to the right audience. '
          'Amplify credits are available exclusively with Artist Pro campaigns.\n\n'
          'Upgrade to Artist Pro to unlock Amplify and grow your audience.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it',
                style: TextStyle(color: Color(0xFFFF5500))),
          ),
        ],
      ),
    );
  }

  void _showUploadLimitDialog(BuildContext context) {
    final sub = ref.read(subscriptionProvider);
    final isGoPlus = sub.planType == 'Go+';
    final planLabel = sub.planType == null ? 'Free' : sub.displayPlanName;
    final limitMessage = isGoPlus
        ? 'Go+ includes offline downloads, but unlimited uploads require Artist Pro.'
        : '$planLabel accounts can upload up to 3 tracks. Upgrade to Artist Pro for unlimited uploads.';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Upload limit reached',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          limitMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Not now', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/upgrade');
            },
            child: const Text('Upgrade', style: TextStyle(color: Colors.white)),
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
              artist: _resolvedArtistName(t),
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
    final trackId = track.id;
    if (trackId == null || trackId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Track options are not available yet.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TrackOptionsSheet(
        trackId: trackId,
        title: track.title,
        artistName: track.artist,
        artworkUrl: track.artworkUrl,
        audioUrl: track.hlsUrl,
        waveform: track.waveform,
        initialLikeCount: track.likeCount,
        initialRepostCount: track.repostCount,
        onEditTrack: () {
          ref.read(trackEditProvider.notifier).state = track;
          context.push('/library/uploads/edit');
        },
        onChangeVisibility: () {},
        onDeleteTrack: () => _deleteTrackPermanently(track),
      ),
    );
  }

  Future<void> _deleteTrackPermanently(UploadTrack track) async {
    final trackId = track.id;
    if (trackId == null || trackId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This track cannot be deleted right now.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Delete Track',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete "${track.title}" permanently? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingTrackIds.add(trackId);
    });

    try {
      await ref.read(dioClientProvider).dio.delete('/tracks/$trackId');

      final currentTrackId = ref.read(playerProvider).currentTrack?.id;
      if (currentTrackId == trackId) {
        ref.read(playerProvider.notifier).stop();
        ref.read(playerProvider.notifier).clearQueue();
      }

      _allTracks.removeWhere((t) => t.id == trackId);
      _filteredTracks.removeWhere((t) => t.id == trackId);

      ref.invalidate(myTracksProvider);

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track deleted permanently'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete track: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingTrackIds.remove(trackId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final myTracksAsync = ref.watch(myTracksProvider);

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
          // Artist Pro banner
          Builder(builder: (context) {
            final sub = ref.watch(subscriptionProvider);
            if (!sub.canUploadUnlimited) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9B3FFF), Color(0xFFFF5500)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Artist tools unlocked',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Info pills section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Builder(builder: (context) {
              // Backend returns duration in seconds per API spec.
              // Tracks without duration are skipped (ignored), not counted as 0.
              final totalSeconds = _allTracks.fold<int>(0, (sum, t) {
                if (t.duration == null || t.duration! <= 0) {
                  debugPrint(
                      '[Library] track "${t.title}" has no duration — skipped from total');
                  return sum;
                }
                return sum + t.duration!;
              });
              final totalMins = (totalSeconds / 60).floor();
              return Row(
                children: [
                  // Upload arrow button with 3D press animation
                  GestureDetector(
                    key: const ValueKey('upload_pick_file_button'),
                    onTapDown: (_) => setState(() => _uploadBtnPressed = true),
                    onTapUp: (_) async {
                      setState(() => _uploadBtnPressed = false);
                      await _pickAndUpload(context);
                    },
                    onTapCancel: () =>
                        setState(() => _uploadBtnPressed = false),
                    child: AnimatedScale(
                      scale: _uploadBtnPressed ? 0.88 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                      child: Container(
                        key: const ValueKey('upload_track_button'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _uploadBtnPressed
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: const Icon(
                          Icons.upload_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Amplify credits pill — tappable info dialog
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showAmplifyInfoDialog(context),
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
                            Flexible(
                              child: Text(
                                'No Amplify credits',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.info_outline,
                                color: Colors.white38, size: 14),
                          ],
                        ),
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
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_upload,
                              color: Color(0xFF5C8DFF), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '$totalMins/120 mins used',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
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
              data: (tracks) {
                _allTracks = tracks;
                final query = _searchController.text.toLowerCase().trim();
                final visibleTracks = query.isEmpty
                    ? tracks
                    : tracks
                        .where((track) =>
                            track.title.toLowerCase().contains(query) ||
                            track.artist.toLowerCase().contains(query))
                        .toList();
                _filteredTracks = List.from(visibleTracks);

                if (visibleTracks.isEmpty) {
                  return Center(
                    child: Text(
                      tracks.isEmpty
                          ? 'No uploads yet'
                          : 'No results for "${_searchController.text}"',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: visibleTracks.length,
                  itemBuilder: (context, index) {
                    final track = visibleTracks[index];
                    final isDeleting = track.id != null &&
                        _deletingTrackIds.contains(track.id);
                    final isCurrentTrack = track.id != null &&
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      _resolvedArtistName(track),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (track.processingState != null &&
                                        track.processingState != 'Finished')
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFFFF5500),
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
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
                                key: const ValueKey(
                                    'uploads_track_options_button'),
                                onTap: isDeleting
                                    ? null
                                    : () => _showTrackOptionsSheet(track),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: isDeleting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFFF5500),
                                          ),
                                        )
                                      : Icon(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
