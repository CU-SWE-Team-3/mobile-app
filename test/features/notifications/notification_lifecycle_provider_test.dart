import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/providers/session_provider.dart';
import 'package:soundcloud_clone/core/services/fcm_service.dart';
import 'package:soundcloud_clone/core/socket/socket_service.dart';
import 'package:soundcloud_clone/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:soundcloud_clone/features/notifications/presentation/providers/notification_fcm_lifecycle_provider.dart';
import 'package:soundcloud_clone/features/notifications/presentation/providers/notification_provider.dart';
import 'package:soundcloud_clone/features/notifications/presentation/providers/notification_socket_lifecycle_provider.dart';

class _MockDioClient extends Mock implements DioClient {}

Map<String, dynamic> _notificationJson(String id) => {
      '_id': id,
      'type': 'LIKE',
      'actors': [
        {
          '_id': 'u1',
          'displayName': 'Mona',
          'permalink': '@mona',
        }
      ],
      'target': {'title': 'Night Drive'},
      'isRead': false,
      'createdAt': DateTime(2026, 5, 3).toIso8601String(),
    };

ProviderContainer _container({
  required String userId,
  SocketService? socketService,
}) {
  final client = _MockDioClient();
  when(() => client.dio).thenReturn(Dio());

  return ProviderContainer(
    overrides: [
      dioClientProvider.overrideWithValue(client),
      sessionUserIdProvider.overrideWith((ref) => userId),
      if (socketService != null)
        socketServiceProvider.overrideWithValue(socketService),
    ],
  );
}

void main() {
  tearDown(() {
    FcmService.onForegroundMessage = null;
  });

  group('notificationFcmLifecycleProvider', () {
    test('registers foreground callback while logged in and clears on dispose',
        () {
      final container = _container(userId: 'user-1');
      addTearDown(container.dispose);

      container.read(notificationFcmLifecycleProvider);
      FcmService.onForegroundMessage!(_notificationJson('fcm-1'));

      expect(
        container.read(notificationProvider).notifications.map((n) => n.id),
        ['fcm-1'],
      );

      container.dispose();
      expect(FcmService.onForegroundMessage, isNull);
    });

    test('keeps foreground callback null while logged out', () {
      final container = _container(userId: '');
      addTearDown(container.dispose);

      container.read(notificationFcmLifecycleProvider);

      expect(FcmService.onForegroundMessage, isNull);
    });
  });

  group('notificationSocketLifecycleProvider', () {
    test('bridges socket callbacks into notification state while logged in', () {
      final socketService = SocketService();
      final container = _container(
        userId: 'user-1',
        socketService: socketService,
      );
      addTearDown(() {
        socketService.disconnect();
        container.dispose();
      });

      container.read(notificationSocketLifecycleProvider);

      socketService.onNewNotification!(_notificationJson('socket-1'));
      socketService.onNewNotification!(_notificationJson('socket-2'));
      socketService.onNotificationRead!('socket-1');
      socketService.onNotificationDeleted!('socket-2');

      final state = container.read(notificationProvider);
      expect(state.notifications.map((n) => n.id), ['socket-1']);
      expect(state.notifications.single.isRead, isTrue);

      socketService.onAllNotificationsRead!();
      expect(
        container
            .read(notificationProvider)
            .notifications
            .every((n) => n.isRead),
        isTrue,
      );
    });

    test('clears socket callbacks while logged out and on dispose', () {
      final socketService = SocketService();
      final container = _container(
        userId: '',
        socketService: socketService,
      );

      container.read(notificationSocketLifecycleProvider);

      expect(socketService.onNewNotification, isNull);
      expect(socketService.onNotificationRead, isNull);
      expect(socketService.onAllNotificationsRead, isNull);
      expect(socketService.onNotificationDeleted, isNull);

      container.dispose();

      expect(socketService.onNewNotification, isNull);
      expect(socketService.onNotificationRead, isNull);
      expect(socketService.onAllNotificationsRead, isNull);
      expect(socketService.onNotificationDeleted, isNull);
      socketService.disconnect();
    });
  });
}
