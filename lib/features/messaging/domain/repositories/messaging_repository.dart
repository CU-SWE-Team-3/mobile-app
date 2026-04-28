import '../entities/conversation.dart';
import '../entities/message.dart';
import '../entities/participant.dart';

abstract class MessagingRepository {
  Future<List<Conversation>> getConversations({int page = 1, int limit = 20});
  Future<List<Message>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  });
  Future<Message> sendMessage({
    required String receiverId,
    required String content,
  });
  Future<List<Participant>> searchUsers(String query);
  Future<List<Participant>> getFollowing(String userId);
  Future<void> markAsRead(String conversationId);
  Future<Message> editMessage(String messageId, String content);
  Future<void> deleteMessageForEveryone(String messageId);
}
