import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../messaging/presentation/providers/messaging_providers.dart';
import 'notification_provider.dart';

/// Bridges the four SocketService notification callbacks into NotificationNotifier.
///
/// Mirrors the [socketMessageLifecycleProvider] pattern. Must be kept alive
/// for the full authenticated session — watch it in the root widget build().
///
/// Re-runs automatically when [sessionUserIdProvider] changes so callbacks are
/// cleared on logout and re-assigned on login without any manual intervention.
final notificationSocketLifecycleProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  final service = ref.watch(socketServiceProvider);

  if (userId.isNotEmpty) {
    service.onNewNotification = (data) =>
        ref.read(notificationProvider.notifier).socketAddNotification(data);
    service.onNotificationRead = (id) =>
        ref.read(notificationProvider.notifier).socketMarkNotificationRead(id);
    service.onAllNotificationsRead = () =>
        ref.read(notificationProvider.notifier).socketMarkAllRead();
    service.onNotificationDeleted = (id) =>
        ref.read(notificationProvider.notifier).socketRemoveNotification(id);
  } else {
    service.onNewNotification = null;
    service.onNotificationRead = null;
    service.onAllNotificationsRead = null;
    service.onNotificationDeleted = null;
  }

  ref.onDispose(() {
    service.onNewNotification = null;
    service.onNotificationRead = null;
    service.onAllNotificationsRead = null;
    service.onNotificationDeleted = null;
  });
});
