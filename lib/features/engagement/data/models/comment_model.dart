import '../../domain/entities/comment.dart';

class CommentUserModel extends CommentUser {
  const CommentUserModel({
    required super.id,
    required super.displayName,
    required super.permalink,
    super.avatarUrl,
  });

  factory CommentUserModel.fromJson(Map<String, dynamic> json) {
    return CommentUserModel(
      id: json['_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Unknown',
      permalink: json['permalink'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class CommentReplyModel extends CommentReply {
  const CommentReplyModel({
    required super.id,
    required super.content,
    required super.timestamp,
    required super.user,
    required super.createdAt,
  });

  factory CommentReplyModel.fromJson(Map<String, dynamic> json) {
    return CommentReplyModel(
      id: json['_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      user: CommentUserModel.fromJson(
          json['user'] as Map<String, dynamic>? ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class CommentModel extends Comment {
  const CommentModel({
    required super.id,
    required super.content,
    required super.timestamp,
    required super.user,
    super.parentCommentId,
    super.replies,
    required super.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'] as List<dynamic>? ?? [];
    return CommentModel(
      id: json['_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      user: CommentUserModel.fromJson(
          json['user'] as Map<String, dynamic>? ?? {}),
      parentCommentId: json['parentComment'] as String?,
      replies: rawReplies
          .map((r) => CommentReplyModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}