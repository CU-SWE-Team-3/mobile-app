import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';
import '../router/app_router.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

class FcmService {
  static const _lastRegisteredTokenKey = 'lastRegisteredFcmToken';

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static bool _initialized = false;
  static bool _backgroundHandlerRegistered = false;
  static Future<void>? _initializing;
  static Future<void>? _registeringCurrentToken;
  static String? _lastRegisteredToken;
  static String? _lastRegisteredAuth;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _openedAppSub;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  /// Assigned by the notification lifecycle provider so foreground FCM messages
  /// update the in-app notification feed. Cleared on logout.
  static void Function(Map<String, dynamic>)? onForegroundMessage;

  static void registerBackgroundHandler() {
    if (kIsWeb || _backgroundHandlerRegistered) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _backgroundHandlerRegistered = true;
  }

  static Future<void> initializeCore() async {
    if (kIsWeb) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    registerBackgroundHandler();
  }

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    final initializing = _initializing;
    if (initializing != null) return initializing;

    _initializing = _initialize();
    return _initializing!;
  }

  static Future<void> _initialize() async {
    try {
      await initializeCore();
      await _createAndroidChannel();
      await _requestPermission();

      await _openedAppSub?.cancel();
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationTap,
      );

      await _foregroundMessageSub?.cancel();
      _foregroundMessageSub =
          FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
        unawaited(_registerToken(token));
      });

      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> handleInitialMessageAfterFirstFrame() async {
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initialize();
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage == null) return;
      // The splash page runs its own async auth check before calling
      // context.go('/home'). If we navigate immediately, that go('/home')
      // fires after us and overwrites our target route. Waiting until the
      // router leaves /splash guarantees we fire after the auth redirect.
      await _waitForRouterSettled();
      _handleNotificationTap(initialMessage);
    });
  }

  /// Waits until the router has navigated away from the splash screen.
  ///
  /// Subscribes to [appRouter.routerDelegate] (a [ChangeNotifier]) which fires
  /// on every route change. Falls back to completing after 5 s so a failed
  /// auth flow never leaves this suspended indefinitely.
  static Future<void> _waitForRouterSettled() async {
    bool hasSplashLeft() {
      try {
        final path =
            appRouter.routerDelegate.currentConfiguration.uri.path;
        return path.isNotEmpty && path != '/splash';
      } catch (_) {
        return false;
      }
    }

    if (hasSplashLeft()) return;

    final completer = Completer<void>();
    late VoidCallback listener;
    listener = () {
      if (!completer.isCompleted && hasSplashLeft()) {
        completer.complete();
        appRouter.routerDelegate.removeListener(listener);
      }
    };
    appRouter.routerDelegate.addListener(listener);

    final timer = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        appRouter.routerDelegate.removeListener(listener);
        completer.complete();
      }
    });

    await completer.future;
    timer.cancel();
  }

  static Future<void> registerCurrentToken() async {
    if (kIsWeb) return;
    final registering = _registeringCurrentToken;
    if (registering != null) return registering;
    _registeringCurrentToken = _registerCurrentToken();
    try {
      await _registeringCurrentToken;
    } finally {
      _registeringCurrentToken = null;
    }
  }

  static Future<void> _registerCurrentToken() async {
    try {
      await initialize();
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (e) {
      debugPrint('[FCM] registerCurrentToken failed: $e');
    }
  }

  static Future<void> unregisterCurrentToken() async {
    if (kIsWeb) return;
    try {
      await initialize();
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_lastRegisteredTokenKey);
      final currentToken = await _messaging.getToken();
      final token =
          storedToken?.isNotEmpty == true ? storedToken : currentToken;
      if (token == null || token.isEmpty) return;
      await dioClient.dio.delete(
        '/notifications/fcm-token',
        data: {'token': token},
      );
      await prefs.remove(_lastRegisteredTokenKey);
      if (_lastRegisteredToken == token) {
        _lastRegisteredToken = null;
        _lastRegisteredAuth = null;
      }
      debugPrint('[FCM] token unregistered: ${_fingerprint(token)}');
    } catch (e) {
      debugPrint('[FCM] token unregister failed: $e');
    }
  }

  static Future<void> _registerToken(String token) async {
    final auth = dioClient.dio.options.headers['Authorization']?.toString();
    if (auth == null || auth.isEmpty) {
      debugPrint('[FCM] token registration skipped - no auth token');
      return;
    }
    if (_lastRegisteredToken == token && _lastRegisteredAuth == auth) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final previousToken = prefs.getString(_lastRegisteredTokenKey);
    if (previousToken != null &&
        previousToken.isNotEmpty &&
        (previousToken != token || _lastRegisteredAuth != auth)) {
      try {
        await dioClient.dio.delete(
          '/notifications/fcm-token',
          data: {'token': previousToken},
        );
        debugPrint('[FCM] previous token cleared before register: '
            '${_fingerprint(previousToken)}');
      } catch (e) {
        debugPrint('[FCM] previous token pre-clear failed: $e');
      }
    }

    await dioClient.dio.post(
      '/notifications/fcm-token',
      data: {'token': token},
    );
    await prefs.setString(_lastRegisteredTokenKey, token);
    _lastRegisteredToken = token;
    _lastRegisteredAuth = auth;
    debugPrint('[FCM] token registered: ${_fingerprint(token)}');
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');
  }

  static Future<void> _createAndroidChannel() async {
    // The native MainActivity channel uses the same ID. Firebase uses this
    // default channel for background/killed notification payloads.
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;

    // Forward to the in-app notification provider if a listener is registered.
    onForegroundMessage?.call(data);

    // Show a system-tray notification for foreground messages that carry a
    // visible notification payload (data-only messages have no notification).
    final notif = message.notification;
    if (notif == null) return;
    final type = (data['type'] ?? data['notificationType'] ?? '').toString();
    final isMessage = type.toUpperCase() == 'MESSAGE';
    if (isMessage) {
      debugPrint('[FCM] foreground MESSAGE ignored; socket owns in-app popup');
      return;
    }
    final actionLink = data['actionLink']?.toString() ?? '';
    final payload = actionLink.isNotEmpty ? actionLink : '/notifications';
    final title = notif.title ?? 'BioBeats';
    final body = _safeBody(notif.body, fallback: 'Tap to open BioBeats');
    unawaited(LocalNotificationService.showNotification(
      title: title,
      body: body,
      payload: payload,
    ));
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? data['notificationType'] ?? '').toString();
    final targetModel = (data['targetModel'] ?? '').toString();
    final actionLink = (data['actionLink'] ?? '').toString();
    final payloadConversationId = _messageConversationId(data);
    final actionLinkConversationId = _conversationIdFromActionLink(actionLink);
    final conversationId = payloadConversationId.isNotEmpty
        ? payloadConversationId
        : actionLinkConversationId;
    final targetPermalink =
        (data['targetPermalink'] ?? data['permalink'] ?? '').toString();

    debugPrint('[FCM] notification tap: type=$type data=$data');

    if (type.toUpperCase() == 'MESSAGE') {
      if (conversationId.isNotEmpty) {
        _navigateToChat(conversationId);
      } else {
        debugPrint(
          '[FCM] MESSAGE tap missing conversationId. '
          'Opening inbox instead of trusting actionLink=$actionLink',
        );
        appRouter.go('/messages');
      }
      return;
    }

    if (type.toUpperCase() == 'FOLLOW' && targetPermalink.isNotEmpty) {
      appRouter.go('/user/$targetPermalink');
      return;
    }

    if (targetModel.toLowerCase() == 'user' && targetPermalink.isNotEmpty) {
      appRouter.go('/user/$targetPermalink');
      return;
    }

    if (actionLink.isNotEmpty) {
      final uri = Uri.tryParse(actionLink);
      if (uri != null && uri.path.isNotEmpty) {
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
        final path = uri.path;
        if (validPrefixes.any((p) => path.startsWith(p))) {
          appRouter.go(path);
          return;
        }
      }
    }

    appRouter.go('/notifications');
  }

  /// Navigates to the chat room for [conversationId].
  ///
  /// Uses [GoRouter.replace] when already on that route so the page
  /// re-initializes (re-joins socket, reloads messages) instead of silently
  /// no-op-ing. Uses [GoRouter.go] for all other navigation origins.
  static void _navigateToChat(String conversationId) {
    final target = '/messages/chat/$conversationId';
    try {
      final currentPath =
          appRouter.routerDelegate.currentConfiguration.uri.path;
      if (currentPath == target) {
        appRouter.replace(target);
        return;
      }
    } catch (_) {}
    appRouter.go(target);
  }

  static String _messageConversationId(Map<String, dynamic> data) {
    for (final map in _payloadMaps(data)) {
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

    final target = data['target'];
    if (target is Map) {
      final value = _idValue(
        target['conversationId'] ?? target['conversation'] ?? target['chatId'],
      );
      if (value.isNotEmpty) return value;
    }

    final targetString = target?.toString() ?? data['targetJson']?.toString();
    if (targetString != null && targetString.isNotEmpty) {
      try {
        final parsed = jsonDecode(targetString);
        if (parsed is Map) {
          final parsedMap = Map<String, dynamic>.from(parsed);
          final value = _idValue(
            parsedMap['conversationId'] ??
                parsedMap['conversation'] ??
                parsedMap['chatId'],
          );
          if (value.isNotEmpty) return value;
        }
      } catch (_) {}
    }

    return '';
  }

  static List<Map<String, dynamic>> _payloadMaps(Map<String, dynamic> data) {
    final maps = <Map<String, dynamic>>[data];
    for (final key in const ['extraData', 'target', 'targetJson', 'payload', 'data']) {
      final map = _mapValue(data[key]);
      if (map != null) maps.add(map);
    }
    return maps;
  }

  static Map<String, dynamic>? _mapValue(dynamic value) {
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

  static String _conversationIdFromActionLink(String actionLink) {
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

  static String _idValue(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.startsWith('{')) {
        try {
          final parsed = jsonDecode(trimmed);
          if (parsed is Map) {
            final map = Map<String, dynamic>.from(parsed);
            return (map['_id'] ??
                    map['id'] ??
                    map['conversationId'] ??
                    map['chatId'] ??
                    '')
                .toString()
                .trim();
          }
        } catch (_) {}
      }
      return trimmed;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final id = (map['_id'] ??
              map['id'] ??
              map['conversationId'] ??
              map['chatId'] ??
              '')
          .toString()
          .trim();
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  static String _messageSenderName(Map<String, dynamic> data) {
    for (final key in const ['senderName', 'senderDisplayName', 'displayName']) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && !_looksLikeObjectId(value)) {
        return value;
      }
    }
    for (final key in const ['sender', 'senderId', 'from', 'user', 'actor']) {
      final value = data[key];
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final nameKey in const ['displayName', 'username', 'name']) {
          final name = map[nameKey]?.toString().trim();
          if (name != null && name.isNotEmpty && !_looksLikeObjectId(name)) {
            return name;
          }
        }
      } else {
        final jsonValue = value?.toString();
        if (jsonValue == null || jsonValue.isEmpty) continue;
        try {
          final parsed = jsonDecode(jsonValue);
          if (parsed is Map) {
            final map = Map<String, dynamic>.from(parsed);
            for (final nameKey in const ['displayName', 'username', 'name']) {
              final name = map[nameKey]?.toString().trim();
              if (name != null && name.isNotEmpty && !_looksLikeObjectId(name)) {
                return name;
              }
            }
          }
        } catch (_) {}
      }
    }
    return 'Someone';
  }

  static String _messageBody(Map<String, dynamic> data, String? notificationBody) {
    for (final key in const ['contentSnippet', 'content', 'messageText', 'text']) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && !_looksLikeObjectId(value)) {
        return value;
      }
    }
    return _safeBody(notificationBody, fallback: 'Tap to open chat');
  }

  static String _safeBody(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || _looksLikeObjectId(trimmed)) {
      return fallback;
    }
    return trimmed;
  }

  static bool _looksLikeObjectId(String value) {
    return RegExp(r'^[a-fA-F0-9]{20,32}$').hasMatch(value);
  }

  static String _fingerprint(String token) {
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }
}
