class CommentUser {
  final String id;
  final String displayName;
  final String permalink;
  final String? avatarUrl;

  const CommentUser({
    required this.id,
    required this.displayName,
    required this.permalink,
    this.avatarUrl,
  });
}

class CommentReply {
  final String id;
  final String content;
  final int timestamp;
  final CommentUser user;
  final DateTime createdAt;

  const CommentReply({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.user,
    required this.createdAt,
  });
}

class Comment {
  final String id;
  final String content;
  final int timestamp;
  final CommentUser user;
  final String? parentCommentId;
  final List<CommentReply> replies;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.user,
    this.parentCommentId,
    this.replies = const [],
    required this.createdAt,
  });
}