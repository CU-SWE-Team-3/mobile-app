import 'message.dart';
import 'participant.dart';

class Conversation {
  final String id;
  final List<Participant> participants;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] as List<dynamic>? ?? [];
    final lastMsgJson = json['lastMessage'] as Map<String, dynamic>?;
    return Conversation(
      id: json['_id'] as String? ?? '',
      participants: rawParticipants
          .map((p) => Participant.fromJson(p as Map<String, dynamic>))
          .toList(),
      lastMessage: lastMsgJson != null ? Message.fromJson(lastMsgJson) : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
