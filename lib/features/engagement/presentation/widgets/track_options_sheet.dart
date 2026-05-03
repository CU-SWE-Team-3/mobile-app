import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/core/providers/session_provider.dart';
import 'package:soundcloud_clone/core/utils/track_url_builder.dart';
import 'package:soundcloud_clone/core/utils/profile_navigation.dart';
import 'package:soundcloud_clone/features/engagement/data/sources/engagement_remote_data_source.dart';
import 'package:soundcloud_clone/features/engagement/presentation/providers/engagement_provider.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/participant.dart';
import 'package:soundcloud_clone/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:soundcloud_clone/features/messaging/presentation/widgets/send_to_sheet.dart';
import 'package:soundcloud_clone/features/player/presentation/providers/player_provider.dart';
import 'package:soundcloud_clone/features/station/presentation/providers/station_providers.dart';
import 'package:soundcloud_clone/features/premium/presentation/providers/subscription_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/likers_list_page.dart';
import '../pages/reposters_list_page.dart';
import '../../../playlist/presentation/pages/add_to_playlist_page.dart';
import '../../../premium/data/services/track_download_service.dart';

class TrackOptionsSheet extends ConsumerStatefulWidget {
  final String trackId;
  final String? title;
  final String? artistName;
  final String? artworkUrl;
  final String? audioUrl;
  final List<int>? waveform;
  final String? artistId;
  final String? artistPermalink;
  final String? trackPermalink;
  final List<PlayerTrack>? queue;
  final bool showSendTo;
  final bool showShare;
  final bool showReport;
  final bool initialIsLiked;
  final bool initialIsReposted;
  final int initialLikeCount;
  final int initialRepostCount;
  final VoidCallback? onUnlike;
  final VoidCallback? onEditTrack;
  final VoidCallback? onChangeVisibility;
  final VoidCallback? onDeleteTrack;
  final bool isInPlaylist;
  final FutureOr<void> Function()? onRemoveFromPlaylist;

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
    this.trackPermalink,
    this.queue,
    this.showSendTo = true,
    this.showShare = true,
    this.showReport = true,
    this.initialIsLiked = false,
    this.initialIsReposted = false,
    this.initialLikeCount = 0,
    this.initialRepostCount = 0,
    this.onUnlike,
    this.onEditTrack,
    this.onChangeVisibility,
    this.onDeleteTrack,
    this.isInPlaylist = false,
    this.onRemoveFromPlaylist,
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

    if (!sub.isPremium || sub.planType != 'Go+') {
      await ref.read(subscriptionProvider.notifier).refreshFromProfile();
      sub = ref.read(subscriptionProvider);
      debugPrint('[Download] after refresh - isPremium=${sub.isPremium}');
    }

    if (!sub.isPremium || sub.planType != 'Go+') {
      if (!mounted) return;
      final scaffold = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Offline downloads require Go+.'),
          backgroundColor: Color(0xFF333333),
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);

    final result = await downloadTrack(
      ref: ref,
      trackId: widget.trackId,
      title: widget.title ?? 'Unknown',
      artistName: widget.artistName ?? 'Unknown',
      artworkUrl: widget.artworkUrl,
      source: 'options_sheet',
    );

    if (!mounted) return;
    setState(() => _isDownloading = false);

    final scaffold = ScaffoldMessenger.of(context);
    switch (result) {
      case TrackDownloadSuccess():
        Navigator.pop(context);
        scaffold.showSnackBar(const SnackBar(
          content: Text('Track saved to Offline Downloads.'),
          backgroundColor: Color(0xFF333333),
        ));
      case TrackDownloadMetadataOnly():
        Navigator.pop(context);
        scaffold.showSnackBar(const SnackBar(
          content: Text(
            'Direct download is disabled for this track. '
            'Saved to Offline Downloads preview.',
          ),
          backgroundColor: Color(0xFF333333),
          duration: Duration(seconds: 4),
        ));
      case TrackDownloadPlanGated():
        Navigator.pop(context);
        scaffold.showSnackBar(const SnackBar(
          content: Text('Requires a Go+ Subscription for offline listening.'),
          backgroundColor: Color(0xFF333333),
        ));
      case TrackDownloadError(:final message):
        scaffold.showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ));
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
    if (success && wasLiked) {
      widget.onUnlike?.call();
    }
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
      isReposted: widget.initialIsReposted,
      likeCount: widget.initialLikeCount,
      repostCount: widget.initialRepostCount,
    );
    final engagementState = ref.watch(engagementProvider(engagementParams));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.54,
      maxChildSize: 0.96,
      snap: true,
      snapSizes: const [0.54, 0.92],
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return Container(
          color: const Color(0xFF111111),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SheetDragHandle(),
                  if (hasDetails)
                    _TrackSheetHeader(
                        title: widget.title!,
                        artist: widget.artistName!,
                        artworkUrl: widget.artworkUrl),
                  if (widget.showSendTo) _InlineSendTo(trackId: widget.trackId),
                  if (widget.showShare)
                    _ShareRow(
                      trackId: widget.trackId,
                      title: widget.title,
                      artistName: widget.artistName,
                      artistPermalink: widget.artistPermalink,
                      trackPermalink: widget.trackPermalink,
                    ),
                  const SizedBox(height: 12),
                  _OptionTile(
                    icon: engagementState.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: engagementState.isLiked ? 'Unlike' : 'Like',
                    onTap: () => _toggleLike(engagementParams, engagementState),
                  ),
                  _OptionTile(
                      icon: Icons.format_list_bulleted,
                      label: 'Play Next',
                      onTap: _playNext),
                  _OptionTile(
                      icon: Icons.format_list_numbered,
                      label: 'Play Last',
                      onTap: _playLast),
                  _OptionTile(
                    key: const ValueKey('track_playlist_action_button'),
                    icon: widget.isInPlaylist &&
                            widget.onRemoveFromPlaylist != null
                        ? Icons.remove_circle_outline
                        : Icons.playlist_add_outlined,
                    label: widget.isInPlaylist &&
                            widget.onRemoveFromPlaylist != null
                        ? 'Remove from playlist'
                        : 'Add to playlist',
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.isInPlaylist &&
                          widget.onRemoveFromPlaylist != null) {
                        widget.onRemoveFromPlaylist?.call();
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddToPlaylistPage(trackId: widget.trackId),
                        ),
                      );
                    },
                  ),
                  _StationOptionTile(
                      trackId: widget.trackId,
                      title: widget.title,
                      artistName: widget.artistName,
                      artworkUrl: widget.artworkUrl),
                  _isDownloading
                      ? const ListTile(
                          leading: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.orange),
                          ),
                          title: Text('Downloading...',
                              style: TextStyle(color: Colors.white70)),
                        )
                      : _OptionTile(
                          key: const ValueKey('premium_download_button'),
                          icon: Icons.download_outlined,
                          label: 'Download',
                          onTap: _handleDownload,
                        ),
                  if (widget.onEditTrack != null ||
                      widget.onChangeVisibility != null ||
                      widget.onDeleteTrack != null) ...[
                    const Divider(color: Color(0xFF2A2A2A), height: 1),
                    if (widget.onEditTrack != null)
                      _OptionTile(
                        icon: Icons.edit_outlined,
                        label: 'Edit track',
                        onTap: () {
                          Navigator.pop(context);
                          widget.onEditTrack?.call();
                        },
                      ),
                    if (widget.onChangeVisibility != null)
                      _OptionTile(
                        icon: Icons.lock_outline,
                        label: 'Change visibility',
                        onTap: () {
                          Navigator.pop(context);
                          widget.onChangeVisibility?.call();
                        },
                      ),
                    if (widget.onDeleteTrack != null)
                      _OptionTile(
                        icon: Icons.delete_outline,
                        label: 'Delete track',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onDeleteTrack?.call();
                        },
                      ),
                  ],
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
                    label: engagementState.isReposted
                        ? 'Undo Repost'
                        : 'Repost on SoundCloud',
                    onTap: engagementState.isLoadingRepost
                        ? () {}
                        : () {
                            Navigator.pop(context);
                            ref
                                .read(engagementProvider(engagementParams)
                                    .notifier)
                                .toggleRepost();
                          },
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
                          builder: (_) =>
                              LikersListPage(trackId: widget.trackId),
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
                      onTap: () => _showSoon('Behind this track coming soon')),
                  _OptionTile(
                      icon: Icons.outlined_flag,
                      label: 'Report',
                      onTap: () => _showSoon('Report coming soon')),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white54,
          borderRadius: BorderRadius.circular(999),
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
  final String? title;
  final String? artistName;
  final String? artistPermalink;
  final String? trackPermalink;

  const _ShareRow({
    required this.trackId,
    this.title,
    this.artistName,
    this.artistPermalink,
    this.trackPermalink,
  });

  String get _url => buildTrackUrl(
        trackId: trackId,
        artistPermalink: artistPermalink,
        trackPermalink: trackPermalink,
      );

  String get _shareText {
    final trackTitle = title?.trim();
    final artist = artistName?.trim();
    final hasTitle = trackTitle != null && trackTitle.isNotEmpty;
    final hasArtist = artist != null && artist.isNotEmpty;
    final label = hasTitle
        ? 'Listen to $trackTitle${hasArtist ? ' by $artist' : ''}'
        : 'Listen to this track';
    return '$label on #BioBeats\n$_url';
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openSms(BuildContext context) async {
    final encoded = Uri.encodeComponent(_shareText);
    final opened = await launchUrl(
      Uri.parse('sms:?body=$encoded'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open SMS.'),
          backgroundColor: Color(0xFF333333),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final encoded = Uri.encodeComponent(_shareText);
    final opened = await launchUrl(
      Uri.parse('whatsapp://send?text=$encoded'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp.'),
          backgroundColor: Color(0xFF333333),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
              _ShareButton(
                icon: Icons.content_copy_outlined,
                label: 'Copy Link',
                onTap: () => _copyLink(context),
              ),
              const SizedBox(width: 10),
              _ShareButton(
                icon: Icons.chat,
                label: 'WhatsApp',
                green: true,
                onTap: () => _openWhatsApp(context),
              ),
              const SizedBox(width: 10),
              _ShareButton(
                icon: Icons.check_circle_outline,
                label: 'Status',
                green: true,
                onTap: () => _openWhatsApp(context),
              ),
              const SizedBox(width: 10),
              _ShareButton(
                icon: Icons.sms_outlined,
                label: 'SMS',
                onTap: () => _openSms(context),
              ),
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
  final Color color;

  const _OptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        label,
        style: TextStyle(color: color, fontSize: 15),
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

// Composite tile: "Start station" (navigate) + like-station toggle (heart icon).
class _StationOptionTile extends ConsumerWidget {
  final String trackId;
  final String? title;
  final String? artistName;
  final String? artworkUrl;

  const _StationOptionTile({
    required this.trackId,
    this.title,
    this.artistName,
    this.artworkUrl,
  });

  String get _stationId => 'track_$trackId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likeState = ref.watch(stationLikeProvider(_stationId));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.wifi_tethering_outlined,
          color: Colors.white, size: 24),
      title: const Text(
        'Start station',
        style: TextStyle(color: Colors.white, fontSize: 15),
      ),
      trailing: GestureDetector(
        onTap: () {
          if (!likeState.isLoading) {
            ref.read(stationLikeProvider(_stationId).notifier).toggle();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: likeState.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFF5500)),
                )
              : Icon(
                  likeState.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: likeState.isLiked
                      ? const Color(0xFFFF5500)
                      : Colors.white54,
                  size: 22,
                ),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        context.push('/station', extra: {
          'trackId': trackId,
          'title': title,
          'artistName': artistName,
          'artworkUrl': artworkUrl,
        });
      },
    );
  }
}
