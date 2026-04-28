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
    final lastMsgRaw = json['lastMessage'] ?? json['latestMessage'];
    final lastMsgJson =
        lastMsgRaw is Map ? Map<String, dynamic>.from(lastMsgRaw) : null;
    final updatedAtRaw =
        json['updatedAt'] ?? json['lastMessageAt'] ?? json['createdAt'];
    return Conversation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      participants: rawParticipants
          .map(_participantFromRaw)
          .where((p) => p.id.isNotEmpty)
          .toList(),
      lastMessage: lastMsgJson != null ? Message.fromJson(lastMsgJson) : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(updatedAtRaw?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static Participant _participantFromRaw(dynamic raw) {
    if (raw is String) {
      return Participant(id: raw, displayName: '', permalink: '');
    }
    if (raw is! Map) {
      return const Participant(id: '', displayName: '', permalink: '');
    }

    final map = Map<String, dynamic>.from(raw);
    final nested = map['user'] ?? map['userId'] ?? map['participant'];
    if (nested is Map) {
      return Participant.fromJson(Map<String, dynamic>.from(nested));
    }
    return Participant.fromJson(map);
  }
}
