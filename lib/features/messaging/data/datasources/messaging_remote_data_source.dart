import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
    try {
      final response = await _dio.get(
        '/messages/conversations',
        queryParameters: {'page': page, 'limit': limit},
      );
      final raw = _extractList(
        response.data,
        const ['conversations', 'items', 'results'],
      );
      return raw
          .whereType<Map>()
          .map((c) => Conversation.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    } on DioException catch (e) {
      debugPrint(
        '[Messaging] getConversations failed: '
        'status=${e.response?.statusCode} data=${e.response?.data}',
      );
      rethrow;
    } catch (e) {
      debugPrint('[Messaging] getConversations parse failed: $e');
      rethrow;
    }
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
    return raw.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<Message> sendMessage({
    required String receiverId,
    String content = '',
    String? conversationId,
    String? attachmentType,
    String? attachmentId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final body = <String, dynamic>{
      'receiverId': receiverId,
      'content': content,
      if (conversationId != null && conversationId.isNotEmpty)
        'conversationId': conversationId,
      if (attachmentType != null && attachmentType.isNotEmpty)
        'attachmentType': attachmentType,
      if (attachmentId != null && attachmentId.isNotEmpty)
        'attachmentId': attachmentId,
    };
    try {
      final response = await _dio.post(
        '/messages',
        data: body,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      debugPrint(
        '[Messaging] sendMessage completed in ${stopwatch.elapsedMilliseconds}ms',
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return Message.fromJson(data['message'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint(
        '[Messaging] sendMessage failed after ${stopwatch.elapsedMilliseconds}ms: $e',
      );
      rethrow;
    }
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

  Future<Message> editMessage(String messageId, String content) async {
    final response = await _dio.patch(
      '/messages/$messageId',
      data: {'content': content},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return Message.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    await _dio.delete('/messages/$messageId/everyone');
  }

  List<dynamic> _extractList(dynamic body, List<String> keys) {
    if (body is List) return body;
    if (body is! Map) return const [];

    final map = Map<String, dynamic>.from(body);
    final data = map['data'];
    if (data is List) return data;
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      for (final key in keys) {
        final value = dataMap[key];
        if (value is List) return value;
      }
    }

    for (final key in keys) {
      final value = map[key];
      if (value is List) return value;
    }

    return const [];
  }
}
