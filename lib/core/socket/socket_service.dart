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
  
  final Map<String, DateTime> _recentNotificationPopups = {};

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
  void sendTyping(String receiverId) {
    _socket?.emit('typing', {'receiverId': receiverId});
  }

  void sendStoppedTyping(String receiverId) {
    _socket?.emit('stop_typing', {'receiverId': receiverId});
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
    final conversationId = _conversationIdFrom(message);
    if (conversationId.isEmpty ||
        _activeConversationIds.contains(conversationId)) {
      return;
    }

    final title = _messageNotificationTitle(message);
    final body = _messageNotificationBody(message);
    final senderName = _senderNameFrom(message);
    if (senderName == 'Someone' && title == 'New message') {
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

    unawaited(
      LocalNotificationService.showNotification(
        title: senderName == 'Someone' ? title : 'Message from $senderName',
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
      final isMessage =
          (notification['type']?.toString().toUpperCase() ?? '') == 'MESSAGE';
      final messageId = _messageIdFromNotification(notification);
      if (isMessage &&
          messageId.isNotEmpty &&
          _recentLocalNotificationMessageIds.contains(messageId)) {
        return;
      }
      if (_shouldSuppressNotificationPopup(notification)) {
        return;
      }
      if (isMessage && messageId.isNotEmpty) {
        _recentLocalNotificationMessageIds.add(messageId);
      }
      unawaited(
        LocalNotificationService.showNotification(
          title: _notificationTitle(notification),
          body: _notificationBody(notification),
          payload: _notificationPayload(notification),
        ),
      );
    } catch (e) {
      debugPrint('[SocketService] new_notification parse error: $e');
    }
  }

  bool _shouldSuppressNotificationPopup(Map<String, dynamic> json) {
    final key = _notificationDedupeKey(json);
    if (key.isEmpty) return false;
    final now = DateTime.now();
    _recentNotificationPopups.removeWhere(
      (_, shownAt) => now.difference(shownAt) > const Duration(minutes: 10),
    );
    final lastShown = _recentNotificationPopups[key];
    if (lastShown != null &&
        now.difference(lastShown) < const Duration(minutes: 10)) {
      return true;
    }
    _recentNotificationPopups[key] = now;
    return false;
  }

  String _notificationDedupeKey(Map<String, dynamic> json) {
    final id =
        (json['_id'] ?? json['id'] ?? json['notificationId'])?.toString() ?? '';
    if (id.isNotEmpty) return 'id:$id';
    final type = (json['type'] ?? '').toString().toUpperCase();
    final body = _notificationBody(json).trim().toLowerCase();
    final actor = _notificationActor(json).trim().toLowerCase();
    if (type.isEmpty && body.isEmpty) return '';
    return '$type|$actor|$body';
  }

  String _notificationPayload(Map<String, dynamic> json) {
    final type = (json['type'] as String? ?? '').toUpperCase();
    final actionLink = json['actionLink']?.toString();
    // Skip the actionLink shortcut for MESSAGE notifications. The backend sends
    // actionLink: "/messages" (the inbox root), which passes _isSafeRoutePath
    // because "/messages" is a valid prefix — but it is too broad. The MESSAGE
    // case below correctly extracts the conversationId from the payload and
    // builds the precise /messages/chat/$id path instead.
    if (type != 'MESSAGE' && actionLink != null && _isSafeRoutePath(actionLink)) {
      return actionLink;
    }

    switch (type) {
      case 'FOLLOW':
      case 'NEW_TRACK':
      case 'NEW_PLAYLIST':
        final actor = _firstActor(json);
        final permalink = actor['permalink']?.toString();
        if (permalink != null && permalink.trim().isNotEmpty) {
          return '/user/${permalink.replaceFirst('@', '')}';
        }
        return '/notifications';
      case 'MESSAGE':
        final conversationId = _conversationIdFrom(json);
        if (conversationId.isNotEmpty) return '/messages/chat/$conversationId';
        return '/messages';
      case 'SYSTEM':
        if (_isRecommendationNotification(json)) {
          return '/home/recommended';
        }
        return '/notifications';
      case 'SYSTEM':
        if (_isRecommendationNotification(json)) {
          return '/home/recommended';
        }
        return '/notifications';
      default:
        return '/notifications';
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
        return 'Message from $actor';
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

  bool _isRecommendationNotification(Map<String, dynamic> json) {
    final body = _notificationBody(json).toLowerCase();
    return body.contains('picked for you') ||
        body.contains('recommended') ||
        body.contains('new tracks');
  }

  String _notificationActor(Map<String, dynamic> json) {
    for (final key in const ['actorName', 'senderName', 'senderDisplayName']) {
      final name = json[key]?.toString().trim();
      if (name != null && name.isNotEmpty && !_looksLikeObjectId(name)) {
        return name;
      }
    }

    final firstMap = _firstActor(json);
    if (firstMap.isEmpty) return 'Someone';
    final name =
        (firstMap['displayName'] ?? firstMap['username'] ?? firstMap['name'])
            ?.toString();
    final actorName = (name == null || name.trim().isEmpty) ? 'Someone' : name;
    final actors = json['actors'];
    final actorCount = json['actorCount'] is int
        ? json['actorCount'] as int
        : int.tryParse(json['actorCount']?.toString() ?? '') ??
            (actors is List ? actors.length : 1);

    if (actorCount > 1) {
      return '$actorName and ${actorCount - 1} other${actorCount == 2 ? '' : 's'}';
    }
    return actorName;
  }

  Map<String, dynamic> _firstActor(Map<String, dynamic> json) {
    final actors = json['actors'];
    if (actors is List && actors.isNotEmpty) {
      final first = actors.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    for (final key in const ['actor', 'actorId', 'sender', 'senderId']) {
      final map = _mapValue(json[key]);
      if (map != null) return map;
    }
    return <String, dynamic>{};
  }

  bool _isSafeRoutePath(String value) {
    final uri = Uri.tryParse(value);
    final path = uri?.path ?? '';
    const validPrefixes = [
      '/user/',
      '/player',
      '/notifications',
      '/messages',
      '/playlist',
      '/comments',
      '/likes',
      '/likers',
      '/reposters',
      '/profile',
    ];
    return validPrefixes.any((prefix) => path.startsWith(prefix));
  }

  bool _looksLikeObjectId(String value) {
    return RegExp(r'^[a-fA-F0-9]{20,32}$').hasMatch(value);
  }

  String _messageNotificationTitle(Map<String, dynamic> message) {
    final senderName = _senderDisplayNameFrom(message);
    if (senderName.isEmpty) return 'New message';
    return 'Message from $senderName';
  }

  String _messageNotificationBody(Map<String, dynamic> message) {
    final body = _firstMessageText(message);
    if (body.isNotEmpty) return body;

    if (message['attachment'] != null || message['attachments'] != null) {
      return 'Sent an attachment';
    }

    return 'Tap to open chat';
  }

  String _conversationIdFrom(Map<String, dynamic> message) {
    for (final map in _messageMaps(message)) {
      for (final key in const [
        'conversationId',
        'targetConversationId',
        'chatId',
        'conversation',
      ]) {
        final value = _idValue(map[key]);
        if (value.isNotEmpty) return value;
      }
    }

    return _conversationIdFromActionLink(message['actionLink']?.toString());
  }

  String _senderIdFrom(Map<String, dynamic> message) {
    return _idValue(message['senderId']).isNotEmpty
        ? _idValue(message['senderId'])
        : _idValue(message['sender']);
  }

  String _senderNameFrom(Map<String, dynamic> message) {
    for (final map in _messageMaps(message)) {
      for (final key in const ['sender', 'senderId', 'from', 'user', 'actor', 'actorId']) {
        final value = _mapValue(map[key]);
        if (value != null) {
          for (final nameKey in const ['displayName', 'username', 'name']) {
            final name = value[nameKey]?.toString().trim();
            if (name != null &&
                name.isNotEmpty &&
                !_looksLikeObjectId(name)) {
              return name;
            }
          }
        }
      }
    }
    for (final map in _messageMaps(message)) {
      for (final key in const [
        'senderName',
        'senderDisplayName',
        'actorName',
        'displayName',
      ]) {
        final name = map[key]?.toString().trim();
        if (name != null && name.isNotEmpty && !_looksLikeObjectId(name)) {
          return name;
        }
      }
    }
    return 'Someone';
  }

  String _senderDisplayNameFrom(Map<String, dynamic> message) {
    for (final key in const ['notificationTitle', 'title']) {
      final value = message[key]?.toString().trim();
      if (value != null &&
          value.startsWith('Message from ') &&
          !_looksLikeObjectId(value)) {
        return value.replaceFirst('Message from ', '').trim();
      }
    }

    for (final map in _messageMaps(message)) {
      for (final key in const [
        'senderDisplayName',
        'senderName',
        'actorName',
        'displayName',
      ]) {
        final value = map[key]?.toString().trim();
        if (value != null && value.isNotEmpty && !_looksLikeObjectId(value)) {
          return value;
        }
      }
    }

    for (final map in _messageMaps(message)) {
      for (final key in const ['senderId', 'sender', 'from', 'user', 'actor', 'actorId']) {
        final value = _mapValue(map[key]);
        if (value == null) continue;
        for (final nameKey in const ['displayName', 'username', 'name']) {
          final name = value[nameKey]?.toString().trim();
          if (name != null && name.isNotEmpty && !_looksLikeObjectId(name)) {
            return name;
          }
        }
      }
    }

    final actors = message['actors'];
    if (actors is List && actors.isNotEmpty && actors.first is Map) {
      final first = Map<String, dynamic>.from(actors.first as Map);
      for (final key in const ['displayName', 'username', 'name']) {
        final value = first[key]?.toString().trim();
        if (value != null && value.isNotEmpty && !_looksLikeObjectId(value)) {
          return value;
        }
      }
    }

    return '';
  }

  String _messageIdFromNotification(Map<String, dynamic> notification) {
    for (final key in const ['targetId', 'messageId']) {
      final value = _idValue(notification[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _firstMessageText(Map<String, dynamic> message) {
    for (final map in _messageMaps(message)) {
      for (final key in const [
        'contentSnippet',
        'content',
        'messageText',
        'message',
        'text',
        'body',
      ]) {
        final value = map[key]?.toString().trim();
        if (value != null && value.isNotEmpty && !_looksLikeObjectId(value)) {
          return value;
        }
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _messageMaps(Map<String, dynamic> message) {
    final maps = <Map<String, dynamic>>[message];
    for (final key in const ['extraData', 'target', 'targetJson', 'payload', 'data']) {
      final map = _mapValue(message[key]);
      if (map != null) maps.add(map);
    }
    return maps;
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final trimmed = value.trim();
      if (!trimmed.startsWith('{')) return null;
      try {
        final parsed = jsonDecode(trimmed);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    return null;
  }

  String _conversationIdFromActionLink(String? actionLink) {
    if (actionLink == null || actionLink.trim().isEmpty) return '';
    final uri = Uri.tryParse(actionLink);
    final segments = uri?.pathSegments ?? const <String>[];
    if (segments.length >= 3 &&
        segments[0] == 'messages' &&
        segments[1] == 'chat' &&
        segments[2].trim().isNotEmpty) {
      return segments[2].trim();
    }
    return '';
  }

  String _idValue(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      final map = _mapValue(trimmed);
      if (map != null) {
        return (map['_id'] ??
                map['id'] ??
                map['conversationId'] ??
                map['chatId'] ??
                '')
            .toString()
            .trim();
      }
      return trimmed;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return (map['_id'] ??
              map['id'] ??
              map['conversationId'] ??
              map['chatId'] ??
              '')
          .toString()
          .trim();
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
