import '../../domain/entities/attachment.dart';
import '../../domain/entities/attachment_picker_item.dart';
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
    required String content,
    Attachment? attachment,
  }) =>
      _dataSource.sendMessage(
        receiverId: receiverId,
        content: content,
        attachment: attachment,
      );

  @override
  Future<List<Participant>> searchUsers(String query) =>
      _dataSource.searchUsers(query);

  @override
  Future<List<AttachmentPickerItem>> searchTracks(String query) =>
      _dataSource.searchTracks(query);

  @override
  Future<List<AttachmentPickerItem>> searchPlaylists(String query) =>
      _dataSource.searchPlaylists(query);

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
