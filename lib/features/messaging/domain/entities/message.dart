import 'attachment.dart';

class Message {
  final String id;
  final String conversationId;
  /// Sender identity is just an ID — resolve display info against
  /// Conversation.participants at render time.
  final String senderId;
  final String content;
  /// Nullable: most messages have no attachment.
  final Attachment? attachment;
  /// 'sent' → 'delivered' → 'read'
  final String? status;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.attachment,
    this.status,
    this.isEdited = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  Message copyWith({String? status}) => Message(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        attachment: attachment,
        status: status ?? this.status,
        isEdited: isEdited,
        isDeleted: isDeleted,
        createdAt: createdAt,
      );

  factory Message.fromJson(Map<String, dynamic> json) {
    final attachmentJson = json['attachment'] as Map<String, dynamic>?;
    return Message(
      id: json['_id'] as String? ?? '',
      // Falls back to '' when message is embedded as Conversation.lastMessage
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      attachment:
          attachmentJson != null ? Attachment.fromJson(attachmentJson) : null,
      status: json['status'] as String?,
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
