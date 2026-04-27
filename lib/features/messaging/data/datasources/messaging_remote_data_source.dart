import 'package:dio/dio.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/participant.dart';

class MessagingRemoteDataSource {
  final Dio _dio;

  MessagingRemoteDataSource(this._dio);

  Future<List<Conversation>> getConversations({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/messages/conversations',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final raw = data['conversations'] as List<dynamic>? ?? [];
    return raw
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<List<Message>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/messages/$conversationId/messages',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final raw = data['messages'] as List<dynamic>? ?? [];
    return raw
        .map((m) => Message.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<Message> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    final response = await _dio.post(
      '/messages',
      data: {'receiverId': receiverId, 'content': content},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return Message.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<List<Participant>> searchUsers(String query) async {
    final response = await _dio.get(
      '/tracks/search',
      queryParameters: {'q': query, 'type': 'users'},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final raw = data['users'] as List<dynamic>? ?? [];
    return raw
        .map((u) => Participant.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<List<Participant>> getFollowing(String userId) async {
    final response = await _dio.get('/network/$userId/following');
    final raw = response.data['data'] as List<dynamic>? ?? [];
    return raw
        .map((u) => Participant.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String conversationId) async {
    await _dio.patch('/messages/conversations/$conversationId/read');
  }
}
