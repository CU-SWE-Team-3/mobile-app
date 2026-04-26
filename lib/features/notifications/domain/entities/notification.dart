enum NotificationType {
  follow,
  like,
  repost,
  comment,
  message,
  newTrack,
  newPlaylist,
  mention,
  system;

  static NotificationType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'FOLLOW':
        return NotificationType.follow;
      case 'LIKE':
        return NotificationType.like;
      case 'REPOST':
        return NotificationType.repost;
      case 'COMMENT':
        return NotificationType.comment;
      case 'MESSAGE':
        return NotificationType.message;
      case 'NEW_TRACK':
        return NotificationType.newTrack;
      case 'NEW_PLAYLIST':
        return NotificationType.newPlaylist;
      case 'MENTION':
        return NotificationType.mention;
      default:
        return NotificationType.system;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String actorId;
  final String actorName;
  final String? actorAvatarUrl;
  final String actorPermalink;
  final int actorCount;
  final String? trackTitle;
  final String? commentText;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    this.actorAvatarUrl,
    required this.actorPermalink,
    this.actorCount = 1,
    this.trackTitle,
    this.commentText,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actors = json['actors'] as List<dynamic>? ?? [];
    final primary = actors.isNotEmpty
        ? actors[0] as Map<String, dynamic>
        : <String, dynamic>{};
    final target = json['target'] as Map<String, dynamic>?;

    return AppNotification(
      id: json['_id'] as String? ?? json['id'] as String,
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      actorId: primary['_id'] as String? ?? '',
      actorName: primary['displayName'] as String? ?? 'Unknown',
      actorAvatarUrl: primary['avatarUrl'] as String?,
      actorPermalink: primary['permalink'] as String? ?? '',
      actorCount: json['actorCount'] as int? ?? actors.length,
      trackTitle: target?['title'] as String?,
      commentText: json['contentSnippet'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

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
    String? actorId,
    String? actorName,
    String? actorAvatarUrl,
    String? actorPermalink,
    int? actorCount,
    String? trackTitle,
    String? commentText,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
      actorPermalink: actorPermalink ?? this.actorPermalink,
      actorCount: actorCount ?? this.actorCount,
      trackTitle: trackTitle ?? this.trackTitle,
      commentText: commentText ?? this.commentText,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
