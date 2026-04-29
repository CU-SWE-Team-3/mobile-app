import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/participant.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../datasources/messaging_remote_data_source.dart';

class MessagingRepositoryImpl implements MessagingRepository {
  final MessagingRemoteDataSource _dataSource;

  MessagingRepositoryImpl(this._dataSource);

  @override
  Future<List<Conversation>> getConversations({
    int page = 1,
    int limit = 20,
  }) =>
      _dataSource.getConversations(page: page, limit: limit);

  @override
  Future<List<Message>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) =>
      _dataSource.getMessages(conversationId, page: page, limit: limit);

  @override
  Future<Message> sendMessage({
    required String receiverId,
    String content = '',
    String? conversationId,
    String? attachmentType,
    String? attachmentId,
  }) =>
      _dataSource.sendMessage(
        receiverId: receiverId,
        content: content,
        conversationId: conversationId,
        attachmentType: attachmentType,
        attachmentId: attachmentId,
      );

  @override
  Future<List<Participant>> searchUsers(String query) =>
      _dataSource.searchUsers(query);

  @override
  Future<List<Participant>> getFollowing(String userId) =>
      _dataSource.getFollowing(userId);

  @override
  Future<void> markAsRead(String conversationId) =>
      _dataSource.markAsRead(conversationId);

  @override
  Future<Message> editMessage(String messageId, String content) =>
      _dataSource.editMessage(messageId, content);

  @override
  Future<void> deleteMessageForEveryone(String messageId) =>
      _dataSource.deleteMessageForEveryone(messageId);
}
