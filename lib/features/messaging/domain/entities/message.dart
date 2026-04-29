import 'attachment.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final String content;
  final Attachment? attachment;
  final String? status;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderDisplayName,
    this.senderAvatarUrl,
    required this.content,
    this.attachment,
    this.status,
    this.isEdited = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  Message copyWith({
    String? status,
    String? content,
    bool? isEdited,
    bool? isDeleted,
  }) =>
      Message(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderDisplayName: senderDisplayName,
        senderAvatarUrl: senderAvatarUrl,
        content: content ?? this.content,
        attachment: attachment,
        status: status ?? this.status,
        isEdited: isEdited ?? this.isEdited,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
      );

  factory Message.fromJson(Map<String, dynamic> json) {
    final attachmentJson = json['attachment'] as Map<String, dynamic>?;
    final sender = json['senderId'] is Map
        ? Map<String, dynamic>.from(json['senderId'] as Map)
        : json['sender'] is Map
            ? Map<String, dynamic>.from(json['sender'] as Map)
            : null;

    return Message(
      id: json['_id'] as String? ?? '',
      conversationId: _idValue(json['conversationId'] ?? json['conversation']),
      senderId:
          sender?['_id']?.toString() ?? _idValue(json['senderId']),
      senderDisplayName: sender?['displayName']?.toString(),
      senderAvatarUrl: sender?['avatarUrl']?.toString(),
      content: json['content'] as String? ?? '',
      attachment:
          attachmentJson != null ? Attachment.fromJson(attachmentJson) : null,
      status: json['status'] as String?,
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static String _idValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return (map['_id'] ?? map['id'] ?? '').toString();
    }
    return value.toString();
  }
}
