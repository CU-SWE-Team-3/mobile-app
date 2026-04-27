import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';
import '../network/dio_client.dart';
import '../network/user_session.dart';

class SocketService {
  static String get _socketUrl => AppConstants.socketBaseUrl;

  io.Socket? _socket;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _currentToken;
  bool _isRecoveringAuthError = false;
  final Set<String> _activeConversationIds = {};

  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _deliveryReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _readReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get newMessages => _newMessageController.stream;
  Stream<Map<String, dynamic>> get deliveryReceipts =>
      _deliveryReceiptController.stream;
  Stream<Map<String, dynamic>> get readReceipts =>
      _readReceiptController.stream;

  void Function(Map<String, dynamic>)? onNewNotification;
  void Function(String id)? onNotificationRead;
  void Function()? onAllNotificationsRead;
  void Function(String id)? onNotificationDeleted;

  bool get isConnected => _socket?.connected ?? false;

  SocketService() {
    _tokenRefreshSub = dioClient.tokenRefreshes.listen(reconnectWithToken);
  }

  Future<void> connect({String? token}) async {
    final resolvedToken = token ?? await UserSession.getAccessToken();
    if (resolvedToken == null || resolvedToken.isEmpty) {
      debugPrint('[SocketService] connect skipped - no token');
      return;
    }
    if ((_socket?.connected ?? false) && _currentToken == resolvedToken) return;
    _initSocket(resolvedToken);
  }

  void disconnect() {
    if (_socket == null) return;
    _socket!.disconnect();
    _socket!.dispose();
    _socket = null;
    _currentToken = null;
    debugPrint('[SocketService] Disconnected');
  }

  void markAsDelivered(String conversationId) {
    _socket?.emit('mark_as_delivered', {'conversationId': conversationId});
    debugPrint('[SocketService] mark_as_delivered: $conversationId');
  }

  void joinChat(String conversationId) {
    _activeConversationIds.add(conversationId);
    _socket?.emit('join_chat', {'conversationId': conversationId});
    debugPrint('[SocketService] join_chat: $conversationId');
  }

  void leaveChat(String conversationId) {
    _activeConversationIds.remove(conversationId);
    _socket?.emit('leave_chat', {'conversationId': conversationId});
    debugPrint('[SocketService] leave_chat: $conversationId');
  }

  void reconnectWithNewToken() {
    disconnect();
    connect();
  }

  void reconnectWithToken(String token) {
    if (token.isEmpty || token == _currentToken) return;
    debugPrint('[SocketService] Token refreshed - reconnecting');
    _initSocket(token);
  }

  void _initSocket(String token) {
    _socket?.disconnect();
    _socket?.dispose();
    _currentToken = token;

    _socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _registerListeners();
    _socket!.connect();
    debugPrint('[SocketService] Connecting to $_socketUrl');
  }

  void _registerListeners() {
    _socket!
      ..onConnect((_) {
        debugPrint('[SocketService] Connected');
        for (final conversationId in _activeConversationIds) {
          _socket?.emit('join_chat', {'conversationId': conversationId});
        }
      })
      ..onDisconnect(
        (reason) => debugPrint('[SocketService] Disconnected: $reason'),
      )
      ..onConnectError(_onConnectError)
      ..on('receive_message', _onReceiveMessage)
      ..on('message_edited', _onReceiveMessage)
      ..on('message_deleted_everyone', _onReceiveMessage)
      ..on('messages_delivered', _onMessageDelivered)
      ..on('messages_read', _onMessageRead)
      ..on('new_notification', _onNewNotification)
      ..on('notification_read', _onNotificationRead)
      ..on('all_notifications_read', (_) => onAllNotificationsRead?.call())
      ..on('notification_deleted', _onNotificationDeleted)
      ..on('error', _onSocketError);
  }

  Future<void> _onConnectError(dynamic err) async =>
      _handleSocketAuthError(err, logPrefix: 'Connection error');

  Future<void> _onSocketError(dynamic err) async =>
      _handleSocketAuthError(err, logPrefix: 'Error');

  Future<void> _handleSocketAuthError(
    dynamic err, {
    required String logPrefix,
  }) async {
    final message = _socketErrorMessage(err);
    debugPrint('[SocketService] $logPrefix: $message');

    if (_isRecoveringAuthError || !_isAuthError(message)) return;

    _isRecoveringAuthError = true;
    try {
      final token = await dioClient.refreshAccessToken();
      if (token != null && token.isNotEmpty) {
        reconnectWithToken(token);
      }
    } finally {
      _isRecoveringAuthError = false;
    }
  }

  String _socketErrorMessage(dynamic err) {
    if (err is Map) {
      return (err['message'] ?? err['error'] ?? err).toString();
    }
    return err?.toString() ?? '';
  }

  bool _isAuthError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('invalid token') ||
        lower.contains('authentication error') ||
        lower.contains('unauthorized');
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
      debugPrint('[SocketService] messages_delivered parse error: $e');
    }
  }

  void _onMessageRead(dynamic data) {
    try {
      _readReceiptController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] messages_read parse error: $e');
    }
  }

  void _onNewNotification(dynamic data) {
    try {
      onNewNotification?.call(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] new_notification parse error: $e');
    }
  }

  void _onNotificationRead(dynamic data) {
    try {
      final map = Map<String, dynamic>.from(data as Map);
      final id = map['notificationId'] as String? ??
          map['id'] as String? ??
          map['_id'] as String? ??
          '';
      if (id.isNotEmpty) onNotificationRead?.call(id);
    } catch (e) {
      debugPrint('[SocketService] notification_read parse error: $e');
    }
  }

  void _onNotificationDeleted(dynamic data) {
    try {
      final map = Map<String, dynamic>.from(data as Map);
      final id = map['notificationId'] as String? ??
          map['id'] as String? ??
          map['_id'] as String? ??
          '';
      if (id.isNotEmpty) onNotificationDeleted?.call(id);
    } catch (e) {
      debugPrint('[SocketService] notification_deleted parse error: $e');
    }
  }

  void dispose() {
    disconnect();
    _tokenRefreshSub?.cancel();
    _newMessageController.close();
    _deliveryReceiptController.close();
    _readReceiptController.close();
  }
}
