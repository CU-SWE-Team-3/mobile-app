import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/fcm_service.dart';
import 'notification_provider.dart';

/// Bridges FcmService.onForegroundMessage into NotificationNotifier.
///
/// Mirrors the pattern of [notificationSocketLifecycleProvider]. Must be kept
/// alive for the full authenticated session — watch it in the root widget
/// build() alongside the socket lifecycle providers.
///
/// Clears the callback on logout so foreground FCM messages arriving after
/// sign-out are not forwarded to the previous user's notification state.
final notificationFcmLifecycleProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(sessionUserIdProvider);

  if (userId.isNotEmpty) {
    FcmService.onForegroundMessage = (data) =>
        ref.read(notificationProvider.notifier).socketAddNotification(data);
  } else {
    FcmService.onForegroundMessage = null;
  }

  ref.onDispose(() => FcmService.onForegroundMessage = null);
});
