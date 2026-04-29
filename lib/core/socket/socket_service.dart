import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';
import '../network/dio_client.dart';
import '../network/user_session.dart';
import '../services/local_notification_service.dart';

class SocketService {
  static String get _socketUrl => AppConstants.socketBaseUrl;

  io.Socket? _socket;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _currentToken;
  bool _isConnecting = false;
  bool _isRecoveringAuthError = false;
  bool _authBlocked = false;
  int _authRecoveryAttempts = 0;
  String? _lastRecoveredTokenFingerprint;
  String? _blockedTokenFingerprint;
  final Set<String> _recentLocalNotificationMessageIds = {};
  final Set<String> _activeConversationIds = {};

  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _deliveryReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _readReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();
  // ── NEW ──────────────────────────────────────────────────────────────────
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _stoppedTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageEditedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedEveryoneController =
      StreamController<Map<String, dynamic>>.broadcast();
  // ─────────────────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> get newMessages => _newMessageController.stream;
  Stream<Map<String, dynamic>> get deliveryReceipts =>
      _deliveryReceiptController.stream;
  Stream<Map<String, dynamic>> get readReceipts =>
      _readReceiptController.stream;
  // ── NEW ──────────────────────────────────────────────────────────────────
  Stream<Map<String, dynamic>> get userTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get userStoppedTyping =>
      _stoppedTypingController.stream;
  Stream<Map<String, dynamic>> get messageEdited =>
      _messageEditedController.stream;
  Stream<Map<String, dynamic>> get messageDeletedEveryone =>
      _messageDeletedEveryoneController.stream;
  // ─────────────────────────────────────────────────────────────────────────

  void Function(Map<String, dynamic>)? onNewNotification;
  void Function(String id)? onNotificationRead;
  void Function()? onAllNotificationsRead;
  void Function(String id)? onNotificationDeleted;

  bool get isConnected => _socket?.connected ?? false;

  SocketService() {
    _tokenRefreshSub = dioClient.tokenRefreshes.listen(reconnectWithToken);
  }

  Future<void> connect({String? token}) async {
    var resolvedToken = token ?? await UserSession.getAccessToken();
    if (resolvedToken == null || resolvedToken.isEmpty) {
      debugPrint('[SocketService] connect skipped - no token');
      return;
    }
    if (_expiresWithin(resolvedToken, const Duration(minutes: 1))) {
      debugPrint(
        '[SocketService] Saved token is expired/stale - refreshing before connect',
      );
      final refreshedToken = await dioClient.refreshAccessToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        debugPrint('[SocketService] connect skipped - token refresh failed');
        return;
      }
      resolvedToken = refreshedToken;
    }
    if (_authBlocked) {
      final fingerprint = _tokenFingerprint(resolvedToken);
      if (fingerprint == _blockedTokenFingerprint) {
        debugPrint('[SocketService] connect skipped - socket auth is blocked');
        return;
      }
      _authBlocked = false;
      _blockedTokenFingerprint = null;
      _resetAuthRecovery();
    }
    if (_socket != null &&
        _currentToken == resolvedToken &&
        (_isConnecting || (_socket?.connected ?? false))) {
      return;
    }
    _initSocket(resolvedToken);
  }

  void disconnect({bool clearRooms = true}) {
    if (_socket == null) {
      if (clearRooms) {
        _activeConversationIds.clear();
      }
      return;
    }
    _socket!.disconnect();
    _socket!.dispose();
    _socket = null;
    _currentToken = null;
    _isConnecting = false;
    if (clearRooms) {
      _activeConversationIds.clear();
    }
    _resetAuthRecovery();
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

  /// Returns true while the user has that conversation's chat page open.
  bool isViewingConversation(String conversationId) =>
      _activeConversationIds.contains(conversationId);

  // ── NEW ──────────────────────────────────────────────────────────────────
  void sendTyping(String conversationId) {
    _socket?.emit('typing', {'conversationId': conversationId});
  }

  void sendStoppedTyping(String conversationId) {
    _socket?.emit('stop_typing', {'conversationId': conversationId});
  }
  // ─────────────────────────────────────────────────────────────────────────

  void reconnectWithNewToken() {
    disconnect(clearRooms: false);
    connect();
  }

  void reconnectWithToken(String token) {
    if (_authBlocked && token != _currentToken) {
      final fingerprint = _tokenFingerprint(token);
      if (fingerprint == _blockedTokenFingerprint) return;
      _authBlocked = false;
      _blockedTokenFingerprint = null;
      _resetAuthRecovery();
    }
    if (token.isEmpty || token == _currentToken) return;
    debugPrint('[SocketService] Token refreshed - reconnecting');
    _initSocket(token);
  }

  void _initSocket(String token) {
    _socket?.disconnect();
    _socket?.dispose();
    _currentToken = token;
    _isConnecting = true;

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
    debugPrint(
      '[SocketService] Connecting to $_socketUrl ${_jwtSummary(token)}',
    );
  }

  void _registerListeners() {
    _socket!
      ..onConnect((_) {
        debugPrint('[SocketService] Connected');
        _isConnecting = false;
        _resetAuthRecovery();
        for (final conversationId in _activeConversationIds) {
          _socket?.emit('join_chat', {'conversationId': conversationId});
        }
      })
      ..onDisconnect(
        (reason) {
          _isConnecting = false;
          debugPrint('[SocketService] Disconnected: $reason');
        },
      )
      ..onConnectError(_onConnectError)
      ..on('receive_message', _onReceiveMessage)
      ..on('message_edited', _onMessageEdited) // ← NEW dedicated handler
      ..on('message_deleted_everyone',
          _onMessageDeletedEveryone) // ← NEW dedicated handler
      ..on('messages_delivered', _onMessageDelivered)
      ..on('messages_read', _onMessageRead)
      ..on('user_typing', _onTyping) // ← NEW
      ..on('user_stopped_typing', _onStoppedTyping) // ← NEW
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
    _isConnecting = false;

    if (_isRecoveringAuthError || !_isAuthError(message)) return;

    final fingerprint = _tokenFingerprint(_currentToken);
    final isExpired = message.toLowerCase().contains('expired');
    if ((!isExpired && _authRecoveryAttempts >= 1) ||
        fingerprint == _lastRecoveredTokenFingerprint) {
      debugPrint(
        '[SocketService] Auth recovery stopped. '
        'Refresh succeeded but socket still rejects the token. '
        'Please log in again; if it repeats, backend socket JWT verification '
        'does not match REST token refresh.',
      );
      _authBlocked = true;
      _blockedTokenFingerprint = fingerprint;
      disconnect();
      return;
    }

    _isRecoveringAuthError = true;
    _authRecoveryAttempts += 1;
    _lastRecoveredTokenFingerprint = fingerprint;
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
        lower.contains('jwt expired') ||
        lower.contains('expired token') ||
        lower.contains('expired') ||
        lower.contains('authentication error') ||
        lower.contains('unauthorized');
  }

  void _resetAuthRecovery() {
    _isRecoveringAuthError = false;
    _authRecoveryAttempts = 0;
    _lastRecoveredTokenFingerprint = null;
  }

  String? _tokenFingerprint(String? token) {
    if (token == null || token.length < 12) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }

  String _jwtSummary(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return '';
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final id = payload['id'] ?? payload['sub'] ?? payload['userId'];
      final iat = payload['iat'];
      final exp = payload['exp'];
      return '(id=$id iat=$iat exp=$exp)';
    } catch (_) {
      return '';
    }
  }

  bool _expiresWithin(String token, Duration threshold) {
    final expiresAt = _jwtExpiresAt(token);
    if (expiresAt == null) return false;
    return expiresAt.isBefore(DateTime.now().add(threshold));
  }

  DateTime? _jwtExpiresAt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
          isUtc: true,
        ).toLocal();
      }
    } catch (_) {}
    return null;
  }

  void _onReceiveMessage(dynamic data) {
    try {
      final message = Map<String, dynamic>.from(data as Map);
      final conversationId = _conversationIdFrom(message);
      if (conversationId.isNotEmpty) {
        message['conversationId'] = conversationId;
      }
      final messageId = message['_id']?.toString() ?? message['id']?.toString();
      final senderId = _senderIdFrom(message);
      debugPrint(
        '[SocketService] receive_message: '
        'conversationId=$conversationId messageId=$messageId senderId=$senderId',
      );
      _newMessageController.add(message);
      _showMessageNotificationIfNeeded(message);
    } catch (e) {
      debugPrint('[SocketService] receive_message parse error: $e');
    }
  }

  // ── NEW ──────────────────────────────────────────────────────────────────
  void _onMessageEdited(dynamic data) {
    try {
      final message = Map<String, dynamic>.from(data as Map);
      final conversationId = _conversationIdFrom(message);
      if (conversationId.isNotEmpty) {
        message['conversationId'] = conversationId;
      }
      _messageEditedController.add(message);
      _newMessageController.add(message); // keep existing listeners working
    } catch (e) {
      debugPrint('[SocketService] message_edited parse error: $e');
    }
  }

  void _onMessageDeletedEveryone(dynamic data) {
    try {
      final message = Map<String, dynamic>.from(data as Map);
      final conversationId = _conversationIdFrom(message);
      if (conversationId.isNotEmpty) {
        message['conversationId'] = conversationId;
      }
      _messageDeletedEveryoneController.add(message);
      _newMessageController.add(message); // keep existing listeners working
    } catch (e) {
      debugPrint('[SocketService] message_deleted_everyone parse error: $e');
    }
  }

  void _onTyping(dynamic data) {
    try {
      _typingController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] user_typing parse error: $e');
    }
  }

  void _onStoppedTyping(dynamic data) {
    try {
      _stoppedTypingController.add(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('[SocketService] user_stopped_typing parse error: $e');
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  void _showMessageNotificationIfNeeded(Map<String, dynamic> message) {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final conversationId = _conversationIdFrom(message);
    if (conversationId.isEmpty ||
        _activeConversationIds.contains(conversationId)) {
      return;
    }

    final messageId = message['_id']?.toString() ?? message['id']?.toString();
    if (messageId != null &&
        messageId.isNotEmpty &&
        !_recentLocalNotificationMessageIds.add(messageId)) {
      return;
    }
    if (_recentLocalNotificationMessageIds.length > 80) {
      _recentLocalNotificationMessageIds.clear();
      if (messageId != null && messageId.isNotEmpty) {
        _recentLocalNotificationMessageIds.add(messageId);
      }
    }

    final content = message['content']?.toString().trim();
    final body =
        (content == null || content.isEmpty || _looksLikeObjectId(content))
            ? 'Tap to open chat'
            : content;
    unawaited(
      LocalNotificationService.showNotification(
        title: 'New message',
        body: body,
        payload: '/messages/chat/$conversationId',
      ),
    );
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
      final notification = Map<String, dynamic>.from(data as Map);
      onNewNotification?.call(notification);
      if ((notification['type']?.toString().toUpperCase() ?? '') == 'MESSAGE') {
        return;
      }
      unawaited(
        LocalNotificationService.showNotification(
          title: _notificationTitle(notification),
          body: _notificationBody(notification),
          payload:
              notification['_id']?.toString() ?? notification['id']?.toString(),
        ),
      );
    } catch (e) {
      debugPrint('[SocketService] new_notification parse error: $e');
    }
  }

  String _notificationTitle(Map<String, dynamic> json) {
    final actor = _notificationActor(json);
    switch ((json['type'] as String? ?? '').toUpperCase()) {
      case 'FOLLOW':
        return '$actor started following you';
      case 'LIKE':
        return '$actor liked your track';
      case 'REPOST':
        return '$actor reposted your track';
      case 'COMMENT':
        return '$actor commented on your track';
      case 'MESSAGE':
        return 'New message from $actor';
      case 'NEW_TRACK':
        return '$actor posted a new track';
      case 'NEW_PLAYLIST':
        return '$actor posted a new playlist';
      case 'MENTION':
        return '$actor mentioned you';
      default:
        return 'BioBeats notification';
    }
  }

  String _notificationBody(Map<String, dynamic> json) {
    final target = json['target'];
    final targetMap =
        target is Map ? Map<String, dynamic>.from(target) : <String, dynamic>{};
    final trackTitle = targetMap['title']?.toString();
    final snippet = json['contentSnippet']?.toString();

    if (snippet != null && snippet.trim().isNotEmpty) return snippet;
    if (trackTitle != null && trackTitle.trim().isNotEmpty) return trackTitle;
    return 'Tap to open BioBeats';
  }

  String _notificationActor(Map<String, dynamic> json) {
    final actors = json['actors'];
    if (actors is! List || actors.isEmpty) return 'Someone';

    final first = actors.first;
    final firstMap =
        first is Map ? Map<String, dynamic>.from(first) : <String, dynamic>{};
    final name = firstMap['displayName']?.toString();
    final actorName = (name == null || name.trim().isEmpty) ? 'Someone' : name;
    final actorCount = json['actorCount'] is int
        ? json['actorCount'] as int
        : int.tryParse(json['actorCount']?.toString() ?? '') ?? actors.length;

    if (actorCount > 1) {
      return '$actorName and ${actorCount - 1} other${actorCount == 2 ? '' : 's'}';
    }
    return actorName;
  }

  bool _looksLikeObjectId(String value) {
    return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value);
  }

  String _conversationIdFrom(Map<String, dynamic> message) {
    final direct = message['conversationId'] ?? message['chatId'];
    final directValue = _idValue(direct);
    if (directValue.isNotEmpty) return directValue;

    final conversation = message['conversation'];
    final conversationValue = _idValue(conversation);
    if (conversationValue.isNotEmpty) return conversationValue;

    return '';
  }

  String _senderIdFrom(Map<String, dynamic> message) {
    return _idValue(message['senderId']).isNotEmpty
        ? _idValue(message['senderId'])
        : _idValue(message['sender']);
  }

  String _idValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return (map['_id'] ?? map['id'] ?? '').toString();
    }
    return value.toString();
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
    _typingController.close();
    _stoppedTypingController.close();
    _messageEditedController.close();
    _messageDeletedEveryoneController.close();
  }
}
