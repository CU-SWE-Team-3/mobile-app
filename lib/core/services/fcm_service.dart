import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';
import '../router/app_router.dart';

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
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    });
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
        previousToken != token) {
      try {
        await dioClient.dio.delete(
          '/notifications/fcm-token',
          data: {'token': previousToken},
        );
        debugPrint('[FCM] previous token unregistered: '
            '${_fingerprint(previousToken)}');
      } catch (e) {
        debugPrint('[FCM] previous token unregister failed: $e');
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

  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? data['notificationType'] ?? '').toString();
    final targetModel = (data['targetModel'] ?? '').toString();
    final actionLink = (data['actionLink'] ?? '').toString();
    final conversationId = _messageConversationId(data);
    final targetPermalink =
        (data['targetPermalink'] ?? data['permalink'] ?? '').toString();

    debugPrint('[FCM] notification tap: type=$type data=$data');

    if (type.toUpperCase() == 'MESSAGE') {
      if (conversationId.isNotEmpty) {
        appRouter.go('/messages/chat/$conversationId');
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

  static String _messageConversationId(Map<String, dynamic> data) {
    for (final key in const [
      'conversationId',
      'targetConversationId',
      'chatId',
      'conversation',
    ]) {
      final value = _idValue(data[key]);
      if (value.isNotEmpty) return value;
    }

    final target = data['target'];
    if (target is Map) {
      final value = _idValue(
        target['conversationId'] ?? target['conversation'] ?? target['chatId'],
      );
      if (value.isNotEmpty) return value;
      final idValue = _idValue(target);
      if (idValue.isNotEmpty) return idValue;
    }

    final targetId = _idValue(data['targetId']);
    if (targetId.isNotEmpty) return targetId;

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
          final idValue = _idValue(parsedMap);
          if (idValue.isNotEmpty) return idValue;
        }
      } catch (_) {}
    }

    return '';
  }

  static String _idValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final id = (map['_id'] ?? map['id'] ?? '').toString();
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  static String _fingerprint(String token) {
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }
}
