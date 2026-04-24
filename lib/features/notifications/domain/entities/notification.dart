enum NotificationType { follow, like, repost, comment }

class AppNotification {
  final String id;
  final NotificationType type;
  final String actorName;
  final String? actorAvatarUrl;
  final String actorPermalink;
  final String? trackTitle;
  final String? commentText;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.actorName,
    this.actorAvatarUrl,
    required this.actorPermalink,
    this.trackTitle,
    this.commentText,
    required this.isRead,
    required this.createdAt,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? actorName,
    String? actorAvatarUrl,
    String? actorPermalink,
    String? trackTitle,
    String? commentText,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actorName: actorName ?? this.actorName,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
      actorPermalink: actorPermalink ?? this.actorPermalink,
      trackTitle: trackTitle ?? this.trackTitle,
      commentText: commentText ?? this.commentText,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
