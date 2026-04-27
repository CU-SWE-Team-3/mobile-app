import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _intentionalDisconnect = false;
  String? _currentToken;

  // Settable callbacks wired by the caller (e.g. splash page).
  void Function(Map<String, dynamic>)? onNewNotification;
  void Function(String id)? onNotificationRead;
  void Function()? onAllNotificationsRead;
  void Function(String id)? onNotificationDeleted;

  void connect(String token) {
    if (token.isEmpty) return;
    _currentToken = token;
    _intentionalDisconnect = false;
    _socket?.disconnect();
    _socket = null;

    final socket = IO.io(
     'https://biobeats.duckdns.org',
     IO.OptionBuilder()
    .setTransports(['polling'])
    .setExtraHeaders({'Authorization': 'Bearer $token'})
    .setPath('/socket.io')
    .enableReconnection()
    .setReconnectionAttempts(3)
    .disableAutoConnect()
    .build(),
    );

    _registerListeners(socket);
    socket.connect();
    _socket = socket;
    debugPrint('[Socket] Connecting...');
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _socket?.disconnect();
    _socket = null;
    debugPrint('[Socket] Disconnected intentionally');
  }

  void _registerListeners(IO.Socket socket) {
    socket.onConnect((_) => debugPrint('[Socket] Connected'));

    socket.onDisconnect(
      (reason) => debugPrint('[Socket] Disconnected: $reason'),
    );

    socket.on('connect_error', (err) async {
      final errMsg = err?.toString() ?? '';
      debugPrint('[Socket] connect_error: $errMsg');
      if (_intentionalDisconnect) return;

      final isTokenError =
          errMsg.toLowerCase().contains('invalid token') ||
          errMsg.toLowerCase().contains('unauthorized');
      if (!isTokenError) return;

      await Future.delayed(const Duration(seconds: 2));
      if (_intentionalDisconnect) return;

      final prefs = await SharedPreferences.getInstance();
      final newToken = prefs.getString('accessToken') ?? '';
      // Only reconnect if the token has actually been refreshed.
      if (newToken.isNotEmpty && newToken != _currentToken) {
        debugPrint('[Socket] Token refreshed — reconnecting');
        connect(newToken);
      } else {
        debugPrint('[Socket] Token unchanged — skipping reconnect');
      }
    });

    socket.on('new_notification', (data) {
      debugPrint('[Socket] new_notification');
      try {
        onNewNotification?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] new_notification parse error: $e');
      }
    });

    socket.on('notification_read', (data) {
      debugPrint('[Socket] notification_read');
      try {
        final map = data as Map<String, dynamic>;
        final id = map['id'] as String? ?? map['_id'] as String? ?? '';
        if (id.isNotEmpty) onNotificationRead?.call(id);
      } catch (e) {
        debugPrint('[Socket] notification_read parse error: $e');
      }
    });

    socket.on('all_notifications_read', (_) {
      debugPrint('[Socket] all_notifications_read');
      onAllNotificationsRead?.call();
    });

    socket.on('notification_deleted', (data) {
      debugPrint('[Socket] notification_deleted');
      try {
        final map = data as Map<String, dynamic>;
        final id = map['id'] as String? ?? map['_id'] as String? ?? '';
        if (id.isNotEmpty) onNotificationDeleted?.call(id);
      } catch (e) {
        debugPrint('[Socket] notification_deleted parse error: $e');
      }
    });
  }
}

final socketServiceProvider = Provider<SocketService>(
  (_) => SocketService(),
);
