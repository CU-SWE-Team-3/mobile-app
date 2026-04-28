import 'package:dio/dio.dart';

import '../../domain/entities/attachment.dart';
import '../../domain/entities/attachment_picker_item.dart';
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
    Attachment? attachment,
  }) async {
    final body = <String, dynamic>{'receiverId': receiverId};
    if (content.isNotEmpty) body['content'] = content;
    if (attachment != null) {
      body['attachmentType'] = attachment.type;
      body['attachmentId'] = attachment.referenceId;
    }
    final response = await _dio.post('/messages', data: body);
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

  Future<List<AttachmentPickerItem>> searchTracks(String query) async {
    final response = await _dio.get(
      '/tracks/search',
      queryParameters: {'q': query, 'type': 'tracks'},
    );
    final raw = _extractList(response.data['data'], 'tracks');
    return raw
        .map((t) {
          final m = t as Map<String, dynamic>;
          final user = m['user'] as Map<String, dynamic>? ?? {};
          return AttachmentPickerItem(
            id: m['_id'] as String? ?? '',
            type: 'track',
            title: m['title'] as String? ?? '',
            subtitle: user['displayName'] as String? ?? '',
            artworkUrl: m['artworkUrl'] as String?,
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<AttachmentPickerItem>> searchPlaylists(String query) async {
    final response = await _dio.get(
      '/tracks/search',
      queryParameters: {'q': query, 'type': 'playlists'},
    );
    final raw = _extractList(response.data['data'], 'playlists');
    return raw
        .map((p) {
          final m = p as Map<String, dynamic>;
          final creator = m['creator'] as Map<String, dynamic>? ??
              m['user'] as Map<String, dynamic>? ??
              {};
          return AttachmentPickerItem(
            id: m['_id'] as String? ?? '',
            type: 'playlist',
            title: m['title'] as String? ?? '',
            subtitle: (m['ownerName'] as String?) ??
                (creator['displayName'] as String?) ??
                '',
            artworkUrl: m['artworkUrl'] as String?,
          );
        })
        .where((item) => item.id.isNotEmpty)
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

  /// Handles two response shapes from the search endpoint:
  /// - `data` is a List directly (default/no-type behaviour seen in search_page)
  /// - `data` is a Map keyed by the type name (e.g. {'tracks': [...]} or {'playlists': [...]})
  List<dynamic> _extractList(dynamic data, String key) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      return data[key] as List<dynamic>? ?? [];
    }
    return [];
  }
}
