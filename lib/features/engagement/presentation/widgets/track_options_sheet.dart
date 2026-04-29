import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/providers/session_provider.dart';
import 'package:soundcloud_clone/core/utils/profile_navigation.dart';
import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/participant.dart';
import 'package:soundcloud_clone/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:soundcloud_clone/features/messaging/presentation/widgets/send_to_sheet.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';

import '../pages/likers_list_page.dart';
import '../pages/reposters_list_page.dart';
import '../../../playlist/presentation/pages/add_to_playlist_page.dart';
import '../../../premium/data/models/offline_downloaded_track.dart';
import '../../../premium/data/services/offline_downloads_repository.dart';
import '../../../premium/presentation/providers/subscription_provider.dart';

class TrackOptionsSheet extends ConsumerStatefulWidget {
  final String trackId;
  final String? title;
  final String? artistName;
  final String? artworkUrl;
  final String? audioUrl;
  final List<int>? waveform;
  final String? artistId;
  final String? artistPermalink;
  final List<PlayerTrack>? queue;
  final bool showSendTo;
  final bool showShare;
  final bool showReport;
  final bool initialIsLiked;
  final int initialLikeCount;
  final int initialRepostCount;

  const TrackOptionsSheet({
    super.key,
    required this.trackId,
    this.title,
    this.artistName,
    this.artworkUrl,
    this.audioUrl,
    this.waveform,
    this.artistId,
    this.artistPermalink,
    this.queue,
    this.showSendTo = true,
    this.showShare = true,
    this.showReport = true,
    this.initialIsLiked = false,
    this.initialLikeCount = 0,
    this.initialRepostCount = 0,
  });

  @override
  ConsumerState<TrackOptionsSheet> createState() => _TrackOptionsSheetState();
}

class _TrackOptionsSheetState extends ConsumerState<TrackOptionsSheet> {
  bool _isDownloading = false;

  Future<void> _handleDownload() async {
    debugPrint(
        '[Download] tapped from options sheet, trackId=${widget.trackId}');

    var sub = ref.read(subscriptionProvider);
    debugPrint(
      '[Download] isPremium=${sub.isPremium}, currentPlan=${sub.planType}',
    );

    if (!sub.isPremium) {
      await ref.read(subscriptionProvider.notifier).refreshFromProfile();
      sub = ref.read(subscriptionProvider);
      debugPrint('[Download] after refresh - isPremium=${sub.isPremium}');
    }

    if (!sub.isPremium) {
      if (!mounted) return;
      final scaffold = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Offline downloads require Go+ or Artist Pro.'),
          backgroundColor: Color(0xFF333333),
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);
    debugPrint('[Download] calling GET /tracks/${widget.trackId}/download');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/offline_${widget.trackId}.mp3';
      final dioClient = ref.read(dioClientProvider);
      await dioClient.dio.download(
        '/tracks/${widget.trackId}/download',
        localPath,
      );
      debugPrint('[Download] backend responded 200 - saving metadata');

      final repo = ref.read(offlineDownloadsRepositoryProvider);
      await repo.save(
        OfflineDownloadedTrack(
          trackId: widget.trackId,
          title: widget.title ?? 'Unknown',
          artistName: widget.artistName ?? 'Unknown',
          artworkUrl: widget.artworkUrl,
          downloadedAt: DateTime.now(),
          localPath: localPath,
          planType: sub.planType,
        ),
      );
      ref.invalidate(offlineDownloadsProvider);

      if (!mounted) return;
      final scaffold = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Track saved for offline listening.'),
          backgroundColor: Color(0xFF333333),
        ),
      );
    } on DioException catch (e) {
      debugPrint(
        '[Download] failed - status: ${e.response?.statusCode}, body: ${e.response?.data}',
      );
      if (!mounted) return;
      setState(() => _isDownloading = false);
      String msg;
      if (e.response?.statusCode == 401) {
        msg = 'Please log in again.';
      } else if (e.response?.statusCode == 403) {
        final data = e.response?.data;
        msg = (data is Map ? data['message'] as String? : null) ??
            'Offline downloads require Go+ or Artist Pro.';
      } else {
        msg = 'Download failed. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSoon(String label) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        backgroundColor: const Color(0xFF333333),
      ),
    );
  }

  PlayerTrack _playerTrack() => PlayerTrack(
        id: widget.trackId,
        title: widget.title ?? 'Track',
        artist: widget.artistName ?? 'Unknown artist',
        artistId: widget.artistId,
        artistPermalink: widget.artistPermalink,
        audioUrl: widget.audioUrl ?? '',
        coverUrl: widget.artworkUrl,
        waveform: widget.waveform,
      );

  void _playLast() {
    ref.read(playerProvider.notifier).addToQueue(_playerTrack());
    Navigator.pop(context);
  }

  void _playNext() {
    final state = ref.read(playerProvider);
    ref.read(playerProvider.notifier).addToQueue(_playerTrack());
    if (state.queue.isNotEmpty) {
      final oldIndex = state.queue.length;
      final insertAt = (state.currentQueueIndex + 1).clamp(0, oldIndex);
      if (insertAt < oldIndex) {
        ref.read(playerProvider.notifier).reorderQueue(oldIndex, insertAt);
      }
    }
    Navigator.pop(context);
  }

  Future<void> _toggleLike(
    EngagementParams params,
    EngagementState engagementState,
  ) async {
    final wasLiked = engagementState.isLiked;
    final wasCount = engagementState.likeCount;

    void writeOverride({
      required bool liked,
      required int likeCount,
    }) {
      final current = Map<String, TrackSummary>.from(
        ref.read(likedTrackOverridesProvider),
      );
      if (liked) {
        current[widget.trackId] = TrackSummary(
          id: widget.trackId,
          title: widget.title ?? 'Track',
          artistName: widget.artistName ?? 'Unknown artist',
          artistId: widget.artistId,
          artistPermalink: widget.artistPermalink,
          artworkUrl: widget.artworkUrl,
          audioUrl: widget.audioUrl,
          waveform: widget.waveform,
          likeCount: likeCount,
          repostCount: widget.initialRepostCount,
        );
      } else {
        current.remove(widget.trackId);
      }
      ref.read(likedTrackOverridesProvider.notifier).state = current;
    }

    writeOverride(
      liked: !wasLiked,
      likeCount: wasLiked ? max(0, wasCount - 1) : wasCount + 1,
    );
    final success =
        await ref.read(engagementProvider(params).notifier).toggleLike();
    if (!mounted) return;
    Navigator.pop(context);
    if (!success) {
      writeOverride(liked: wasLiked, likeCount: wasCount);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update like. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDetails = widget.title != null && widget.artistName != null;
    final engagementParams = EngagementParams(
      trackId: widget.trackId,
      isLiked: widget.initialIsLiked,
      likeCount: widget.initialLikeCount,
      repostCount: widget.initialRepostCount,
    );
    final engagementState = ref.watch(engagementProvider(engagementParams));

    return Container(
      color: const Color(0xFF111111),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDetails)
                _TrackSheetHeader(
                  title: widget.title!,
                  artist: widget.artistName!,
                  artworkUrl: widget.artworkUrl,
                ),
              if (widget.showSendTo) _InlineSendTo(trackId: widget.trackId),
              if (widget.showShare) _ShareRow(trackId: widget.trackId),
              const SizedBox(height: 12),
              _OptionTile(
                icon: engagementState.isLiked
                    ? Icons.favorite
                    : Icons.favorite_border,
                label: engagementState.isLiked ? 'Unlike' : 'Like',
                onTap: engagementState.isLoadingLike
                    ? () {}
                    : () => _toggleLike(engagementParams, engagementState),
              ),
              _OptionTile(
                icon: Icons.format_list_bulleted,
                label: 'Play Next',
                onTap: _playNext,
              ),
              _OptionTile(
                icon: Icons.format_list_numbered,
                label: 'Play Last',
                onTap: _playLast,
              ),
              _OptionTile(
                icon: Icons.playlist_add_outlined,
                label: 'Add to playlist',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddToPlaylistPage(trackId: widget.trackId),
                    ),
                  );
                },
              ),
              _OptionTile(
                icon: Icons.wifi_tethering_outlined,
                label: 'Start station',
                onTap: () => _showSoon('Start station coming soon'),
              ),
              _isDownloading
                  ? const ListTile(
                      leading: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange,
                        ),
                      ),
                      title: Text(
                        'Downloading...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : _OptionTile(
                      icon: Icons.download_outlined,
                      label: 'Download',
                      onTap: _handleDownload,
                    ),
              const Divider(color: Color(0xFF2A2A2A), height: 1),
              _OptionTile(
                icon: Icons.person_outline,
                label: 'Go to artist profile',
                onTap: () {
                  if (widget.artistId != null &&
                      widget.artistPermalink != null &&
                      widget.artistName != null) {
                    Navigator.pop(context);
                    navigateToUserProfile(
                      context,
                      userId: widget.artistId!,
                      permalink: widget.artistPermalink!,
                      displayName: widget.artistName!,
                    );
                  } else {
                    _showSoon('Artist profile unavailable');
                  }
                },
              ),
              _OptionTile(
                icon: Icons.chat_bubble_outline,
                label: 'View comments',
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '/comments',
                    extra: {
                      'trackId': widget.trackId,
                      'trackTitle': widget.title,
                      'trackArtist': widget.artistName,
                      'trackArtworkUrl': widget.artworkUrl,
                      'currentPositionSeconds': 0,
                    },
                  );
                },
              ),
              _OptionTile(
                icon: Icons.repeat,
                label: 'Repost on SoundCloud',
                onTap: () => _showSoon('Repost coming soon'),
              ),
              const Divider(color: Color(0xFF2A2A2A), height: 1),
              _OptionTile(
                icon: Icons.people_outline,
                label: 'People who liked this track',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LikersListPage(trackId: widget.trackId),
                    ),
                  );
                },
              ),
              _OptionTile(
                icon: Icons.people_alt_outlined,
                label: 'People who reposted this track',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RepostersListPage(trackId: widget.trackId),
                    ),
                  );
                },
              ),
              _OptionTile(
                icon: Icons.graphic_eq,
                label: 'Behind this track',
                onTap: () => _showSoon('Behind this track coming soon'),
              ),
              if (widget.showReport)
                _OptionTile(
                  icon: Icons.outlined_flag,
                  label: 'Report',
                  onTap: () => _showSoon('Report coming soon'),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineSendTo extends ConsumerWidget {
  final String trackId;

  const _InlineSendTo({required this.trackId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(sessionUserIdProvider);
    final convAsync = ref.watch(conversationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Text(
            'SEND TO',
            style: TextStyle(
              color: Color(0xFFB6B6B6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        convAsync.when(
          loading: () => const SizedBox(
            height: 72,
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF5500),
                strokeWidth: 2,
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (conversations) {
            final contacts = <Participant>[];
            for (final conv in conversations) {
              Participant? other;
              for (final participant in conv.participants) {
                if (participant.id != myId && participant.id.isNotEmpty) {
                  other = participant;
                  break;
                }
              }
              if (other != null &&
                  !contacts.any((item) => item.id == other!.id)) {
                contacts.add(other);
              }
              if (contacts.length == 6) break;
            }

            if (contacts.isEmpty) return const SizedBox.shrink();
            final repo = ref.read(messagingRepositoryProvider);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final contact in contacts)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          try {
                            await repo.sendMessage(
                              receiverId: contact.id,
                              attachmentType: 'track',
                              attachmentId: trackId,
                            );
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Sent to ${contact.displayName}'),
                                backgroundColor: const Color(0xFF333333),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (_) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to send'),
                                backgroundColor: Color(0xFFCC3333),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: _SendToAvatar(
                          name: contact.displayName,
                          avatarUrl: contact.avatarUrl,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String trackId;

  const _ShareRow({required this.trackId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: Text(
            'SHARE',
            style: TextStyle(
              color: Color(0xFFB6B6B6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _ShareButton(
                icon: Icons.send_outlined,
                label: 'Message',
                onTap: () {
                  Navigator.pop(context);
                  showSendToSheet(context, ShareableTrack(trackId));
                },
              ),
              const SizedBox(width: 10),
              const _ShareButton(
                icon: Icons.content_copy_outlined,
                label: 'Copy Link',
              ),
              const SizedBox(width: 10),
              const _ShareButton(
                icon: Icons.chat,
                label: 'WhatsApp',
                green: true,
              ),
              const SizedBox(width: 10),
              const _ShareButton(
                icon: Icons.check_circle_outline,
                label: 'Status',
                green: true,
              ),
              const SizedBox(width: 10),
              const _ShareButton(icon: Icons.sms_outlined, label: 'SMS'),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackSheetHeader extends StatelessWidget {
  final String title;
  final String artist;
  final String? artworkUrl;

  const _TrackSheetHeader({
    required this.title,
    required this.artist,
    required this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 166,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F283B), Color(0xFF7E576F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 104,
              height: 104,
              child: artworkUrl == null || artworkUrl!.isEmpty
                  ? const _SheetArtworkPlaceholder()
                  : CachedNetworkImage(
                      imageUrl: artworkUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const _SheetArtworkPlaceholder(),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  artist,
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendToAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _SendToAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final isValid = avatarUrl != null &&
        avatarUrl!.isNotEmpty &&
        avatarUrl!.startsWith('http');
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF3A3A3A),
            backgroundImage:
                isValid ? CachedNetworkImageProvider(avatarUrl!) : null,
            child: !isValid
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool green;
  final VoidCallback? onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    this.green = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color:
                    green ? const Color(0xFF28D366) : const Color(0xFF2F2F2F),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: onTap,
    );
  }
}

class _SheetArtworkPlaceholder extends StatelessWidget {
  const _SheetArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF303030),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 34),
      ),
    );
  }
}
