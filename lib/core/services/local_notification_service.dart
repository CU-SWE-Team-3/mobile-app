import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../router/app_router.dart';

class LocalNotificationService {
  static const MethodChannel _channel =
      MethodChannel('biobeats/local_notifications');

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('initialize');
      _channel.setMethodCallHandler(_handleMethodCall);
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
    if (uri == null || uri.path.isEmpty) return;
    appRouter.go(uri.path);
  }
}
