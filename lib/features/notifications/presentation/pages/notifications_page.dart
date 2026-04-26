import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notification_provider.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationProvider.notifier).fetchNotifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFFFF5500), fontSize: 13),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.cast, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, NotificationState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5500)),
      );
    }
    if (state.error != null) {
      return Center(
        child: Text(
          state.error!,
          style: const TextStyle(color: Colors.white54, fontSize: 15),
        ),
      );
    }

    final items = state.filtered;
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No notifications',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    final grouped = _groupByDate(items);
    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final entry = grouped[i];
        if (entry is _SectionHeader) {
          return _buildSectionHeader(entry.label);
        }
        return _buildNotificationTile(context, entry as AppNotification);
      },
    );
  }

  // ── Date grouping ────────────────────────────────────────────────────────────

  List<Object> _groupByDate(List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<AppNotification>> buckets = {
      'Today': [],
      'Yesterday': [],
      'This week': [],
      'Earlier': [],
    };

    for (final n in notifications) {
      final day =
          DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (!day.isBefore(today)) {
        buckets['Today']!.add(n);
      } else if (!day.isBefore(yesterday)) {
        buckets['Yesterday']!.add(n);
      } else if (day.isAfter(weekAgo)) {
        buckets['This week']!.add(n);
      } else {
        buckets['Earlier']!.add(n);
      }
    }

    final result = <Object>[];
    for (final label in ['Today', 'Yesterday', 'This week', 'Earlier']) {
      final list = buckets[label]!;
      if (list.isEmpty) continue;
      result.add(_SectionHeader(label));
      result.addAll(list);
    }
    return result;
  }

  // ── Section header ───────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Notification tile ────────────────────────────────────────────────────────

  Widget _buildNotificationTile(BuildContext context, AppNotification n) {
    final bg =
        n.isRead ? const Color(0xFF111111) : const Color(0xFF1E1E1E);

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade800,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(notificationProvider.notifier).deleteNotification(n.id),
      child: InkWell(
        onTap: () => _handleTap(context, n),
        onLongPress: () => _showDeleteSheet(context, n),
        child: Container(
          color: bg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Unread accent bar
              Container(
                width: 3,
                height: 72,
                color: n.isRead
                    ? Colors.transparent
                    : const Color(0xFFFF5500),
              ),
              const SizedBox(width: 12),
              // Avatar + badge
              _buildAvatar(n),
              const SizedBox(width: 12),
              // Notification text
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _notificationText(n),
                    style: TextStyle(
                      color: n.isRead ? Colors.white70 : Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Time
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  n.timeAgo,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteSheet(BuildContext context, AppNotification n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete notification',
                style: TextStyle(color: Colors.red, fontSize: 15),
              ),
              onTap: () {
                Navigator.of(context).pop();
                ref
                    .read(notificationProvider.notifier)
                    .deleteNotification(n.id);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(AppNotification n) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          n.actorAvatarUrl != null
              ? CachedNetworkImage(
                  imageUrl: n.actorAvatarUrl!,
                  imageBuilder: (_, img) => CircleAvatar(
                    radius: 22,
                    backgroundImage: img,
                  ),
                  placeholder: (_, __) => _fallbackAvatar(),
                  errorWidget: (_, __, ___) => _fallbackAvatar(),
                )
              : _fallbackAvatar(),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFFF5500),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _typeIcon(n.type),
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return const CircleAvatar(
      radius: 22,
      backgroundColor: Color(0xFF333333),
      child: Icon(Icons.person, color: Colors.white54, size: 22),
    );
  }

  IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.repost:
        return Icons.repeat;
      case NotificationType.comment:
        return Icons.chat_bubble;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.newTrack:
        return Icons.music_note;
      case NotificationType.newPlaylist:
        return Icons.queue_music;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.system:
        return Icons.notifications;
    }
  }

  String _actorPrefix(AppNotification n) {
    if (n.actorCount <= 1) return n.actorName;
    final others = n.actorCount - 1;
    return '${n.actorName} and $others other${others == 1 ? '' : 's'}';
  }

  String _notificationText(AppNotification n) {
    final actor = _actorPrefix(n);
    switch (n.type) {
      case NotificationType.follow:
        return '$actor started following you';
      case NotificationType.like:
        return '$actor liked your track ${n.trackTitle ?? ''}';
      case NotificationType.repost:
        return '$actor reposted your track ${n.trackTitle ?? ''}';
      case NotificationType.comment:
        final quote =
            n.commentText != null ? '"${n.commentText}"' : '';
        final track =
            n.trackTitle != null ? ' on ${n.trackTitle}' : '';
        return '$actor commented: $quote$track';
      case NotificationType.message:
        return '$actor sent you a message';
      case NotificationType.newTrack:
        return '$actor released a new track${n.trackTitle != null ? ': ${n.trackTitle}' : ''}';
      case NotificationType.newPlaylist:
        return '$actor created a new playlist${n.trackTitle != null ? ': ${n.trackTitle}' : ''}';
      case NotificationType.mention:
        return '$actor mentioned you';
      case NotificationType.system:
        return n.commentText ?? 'System notification';
    }
  }

  // ── Tap handling ─────────────────────────────────────────────────────────────

  void _handleTap(BuildContext context, AppNotification n) {
    ref.read(notificationProvider.notifier).markAsRead(n.id);
    switch (n.type) {
      case NotificationType.follow:
        {
          final slug = n.actorPermalink.replaceFirst('@', '');
          context.push('/user/$slug', extra: {
            'displayName': n.actorName,
            'userId': n.actorId,
          });
        }
        break;
      case NotificationType.like:
      case NotificationType.repost:
        context.push('/player');
        break;
      case NotificationType.comment:
      case NotificationType.mention:
        context.push('/comments', extra: {
          'trackId': null,
          'trackTitle': n.trackTitle,
          'trackArtist': null,
          'trackArtworkUrl': null,
          'currentPositionSeconds': 0,
        });
        break;
      case NotificationType.newTrack:
      case NotificationType.newPlaylist:
        {
          final slug = n.actorPermalink.replaceFirst('@', '');
          context.push('/user/$slug', extra: {
            'displayName': n.actorName,
            'userId': n.actorId,
          });
        }
        break;
      case NotificationType.message:
        context.push('/messages');
        break;
      case NotificationType.system:
        break;
    }
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FilterSheet(),
    );
  }
}

// ── Section header sentinel ────────────────────────────────────────────────────

class _SectionHeader {
  final String label;
  const _SectionHeader(this.label);
}

// ── Filter bottom sheet ────────────────────────────────────────────────────────

class _FilterOption {
  final NotificationType? type;
  final IconData icon;
  final String label;
  const _FilterOption(this.type, this.icon, this.label);
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  static const _options = [
    _FilterOption(null, Icons.notifications, 'All notifications'),
    _FilterOption(NotificationType.like, Icons.favorite, 'Likes'),
    _FilterOption(NotificationType.comment, Icons.chat_bubble, 'Comments'),
    _FilterOption(NotificationType.repost, Icons.repeat, 'Reposts'),
    _FilterOption(NotificationType.follow, Icons.person_add, 'Followings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(notificationProvider).activeFilter;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Show notifications for:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ..._options.map((opt) {
            final selected = activeFilter == opt.type;
            return ListTile(
              leading: Icon(
                opt.icon,
                color: selected
                    ? const Color(0xFFFF5500)
                    : Colors.white54,
                size: 22,
              ),
              title: Text(
                opt.label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFFF5500)
                      : Colors.white,
                  fontSize: 15,
                ),
              ),
              trailing: selected
                  ? const Icon(
                      Icons.check,
                      color: Color(0xFFFF5500),
                      size: 18,
                    )
                  : null,
              onTap: () {
                ref
                    .read(notificationProvider.notifier)
                    .setFilter(opt.type);
                Navigator.of(context).pop();
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
