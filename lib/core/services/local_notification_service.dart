import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../router/app_router.dart';

class LocalNotificationService {
  static const MethodChannel _channel =
      MethodChannel('biobeats/local_notifications');
  static bool _handlerRegistered = false;

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('initialize');
      // Register the handler exactly once. setMethodCallHandler replaces any
      // existing handler, so calling it again would silently discard subsequent
      // native taps that arrive while the previous handler was active.
      if (!_handlerRegistered) {
        _channel.setMethodCallHandler(_handleMethodCall);
        _handlerRegistered = true;
      }
      await _channel.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      // Local notifications are only implemented for Android right now.
    } catch (e) {
      debugPrint('[LocalNotifications] initialize failed: $e');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('showNotification', {
        'title': title,
        'body': body,
        'payload': payload,
      });
    } on MissingPluginException {
      // Local notifications are only implemented for Android right now.
    } catch (e) {
      debugPrint('[LocalNotifications] showNotification failed: $e');
    }
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'notificationTap') return;
    final payload = call.arguments?.toString();
    if (payload == null || payload.isEmpty) return;
    _openPayload(payload);
  }

  static void _openPayload(String payload) {
    final uri = Uri.tryParse(payload);
    final path = uri?.path ?? '';
    final segments = uri?.pathSegments ?? const <String>[];

    // Valid chat route: /messages/chat/{id}
    if (segments.length == 3 &&
        segments[0] == 'messages' &&
        segments[1] == 'chat' &&
        segments[2].isNotEmpty) {
      _navigateToChat(segments[2]);
      return;
    }

    // Malformed /messages/chat with no ID → go to inbox
    if (path == '/messages/chat') {
      appRouter.go('/messages');
      return;
    }

    if (path.isEmpty ||
        path == '/' ||
        !path.startsWith('/') ||
        RegExp(r'^/?[a-fA-F0-9]{20,32}$').hasMatch(path)) {
      appRouter.go('/notifications');
      return;
    }
    appRouter.go(path);
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
}
