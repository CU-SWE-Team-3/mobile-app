import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';
import '../network/user_session.dart';

class SocketService {
  // Sourced from AppConstants so socket and REST always point at the same host.
  static String get _socketUrl => AppConstants.socketBaseUrl;

  io.Socket? _socket;

  // Broadcast streams so multiple listeners can subscribe independently
  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _deliveryReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _readReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _stoppedTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageEditedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedEveryoneController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Raw JSON stream for `receive_message` events.
  Stream<Map<String, dynamic>> get newMessages => _newMessageController.stream;

  /// Raw JSON stream for `message_delivered` events.
  Stream<Map<String, dynamic>> get deliveryReceipts =>
      _deliveryReceiptController.stream;

  /// Raw JSON stream for `message_read` events.
  Stream<Map<String, dynamic>> get readReceipts => _readReceiptController.stream;

  /// Raw JSON stream for `user_typing` events.
  Stream<Map<String, dynamic>> get userTyping => _typingController.stream;

  /// Raw JSON stream for `user_stopped_typing` events.
  Stream<Map<String, dynamic>> get userStoppedTyping =>
      _stoppedTypingController.stream;

  /// Raw JSON stream for `message_edited` events.
  Stream<Map<String, dynamic>> get messageEdited =>
      _messageEditedController.stream;

  /// Raw JSON stream for `message_deleted_everyone` events.
  Stream<Map<String, dynamic>> get messageDeletedEveryone =>
      _messageDeletedEveryoneController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Reads the current JWT from UserSession and opens the socket.
  /// No-op if already connected. Safe to call multiple times.
  void connect() {
    if (_socket?.connected ?? false) return;
    UserSession.getAccessToken().then((token) {
      if (token == null || token.isEmpty) {
        debugPrint('[SocketService] connect() skipped — no token');
        return;
      }
      _initSocket(token);
    });
  }

  /// Cleanly closes the socket and nulls the reference.
  void disconnect() {
    if (_socket == null) return;
    _socket!.disconnect();
    _socket!.dispose();
    _socket = null;
    debugPrint('[SocketService] Disconnected');
  }

  /// Emits `mark_as_delivered` so the backend upgrades message statuses and
  /// notifies the sender via the `messages_delivered` event.
  void markAsDelivered(String conversationId) {
    _socket?.emit('mark_as_delivered', {'conversationId': conversationId});
    debugPrint('[SocketService] mark_as_delivered: $conversationId');
  }

  /// Emits `join_chat` so the backend scopes message delivery to this client.
  void joinChat(String conversationId) {
    _socket?.emit('join_chat', {'conversationId': conversationId});
    debugPrint('[SocketService] join_chat: $conversationId');
  }

  /// Emits `leave_chat` when the user navigates away from a conversation.
  void leaveChat(String conversationId) {
    _socket?.emit('leave_chat', {'conversationId': conversationId});
    debugPrint('[SocketService] leave_chat: $conversationId');
  }

  /// Emits `typing` to notify the receiver that the current user is typing.
  void sendTyping(String receiverId) {
    _socket?.emit('typing', {'receiverId': receiverId});
  }

  /// Emits `stop_typing` to notify the receiver that the current user stopped.
  void stopTyping(String receiverId) {
    _socket?.emit('stop_typing', {'receiverId': receiverId});
  }

  /// Disconnects and reconnects with the latest token.
  /// Call this after a token refresh if the socket reports auth failure.
  void reconnectWithNewToken() {
    disconnect();
    connect();
  }

  void _initSocket(String token) {
    // Listeners must be registered before connect() is called
    _socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          // websocket first, polling as fallback (per socket documentation)
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          // Method A: raw JWT only — no 'Bearer' prefix (that's for extraHeaders)
          .setAuth({'token': token})
          .build(),
    );
    _registerListeners();
    _socket!.connect();
    debugPrint('[SocketService] Connecting to $_socketUrl');
  }

  void _registerListeners() {
    _socket!
      ..onConnect((_) => debugPrint('[SocketService] Connected'))
      ..onDisconnect((_) => debugPrint('[SocketService] Server disconnected'))
      ..onConnectError((err) =>
          debugPrint('[SocketService] Connection error: $err'))
      ..on('receive_message', _onReceiveMessage)
      ..on('messages_delivered', _onMessageDelivered)
      ..on('messages_read', _onMessageRead)
      ..on('user_typing', _onUserTyping)
      ..on('user_stopped_typing', _onUserStoppedTyping)
      ..on('message_edited', _onMessageEdited)
      ..on('message_deleted_everyone', _onMessageDeletedEveryone);
  }

  void _onReceiveMessage(dynamic data) {
    try {
      _newMessageController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] receive_message parse error: $e');
    }
  }

  void _onMessageDelivered(dynamic data) {
    try {
      _deliveryReceiptController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] message_delivered parse error: $e');
    }
  }

  void _onMessageRead(dynamic data) {
    try {
      _readReceiptController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] message_read parse error: $e');
    }
  }

  void _onUserTyping(dynamic data) {
    try {
      _typingController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] user_typing parse error: $e');
    }
  }

  void _onUserStoppedTyping(dynamic data) {
    try {
      _stoppedTypingController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] user_stopped_typing parse error: $e');
    }
  }

  void _onMessageEdited(dynamic data) {
    try {
      _messageEditedController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] message_edited parse error: $e');
    }
  }

  void _onMessageDeletedEveryone(dynamic data) {
    try {
      _messageDeletedEveryoneController
          .add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] message_deleted_everyone parse error: $e');
    }
  }

  void dispose() {
    disconnect();
    _newMessageController.close();
    _deliveryReceiptController.close();
    _readReceiptController.close();
    _typingController.close();
    _stoppedTypingController.close();
    _messageEditedController.close();
    _messageDeletedEveryoneController.close();
  }
}
