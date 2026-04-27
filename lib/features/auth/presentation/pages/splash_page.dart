import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/deep_link_state.dart';
import '../../../../core/network/user_session.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../injection_container.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('[Splash] deepLinkHandled=$deepLinkHandled');
    if (!mounted || deepLinkHandled) return;

    final accessToken = await UserSession.getAccessToken();
    final userId = await UserSession.getUserId();
    debugPrint('[Splash] token=$accessToken userId=$userId');
    final hasSession = accessToken != null &&
        accessToken.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty;

    if (mounted) {
      if (hasSession) {
        final notifier = ref.read(notificationProvider.notifier);
        final socketSvc = sl<SocketService>();
        socketSvc.onNewNotification = notifier.socketAddNotification;
        socketSvc.onNotificationRead = notifier.socketMarkNotificationRead;
        socketSvc.onAllNotificationsRead = notifier.socketMarkAllRead;
        socketSvc.onNotificationDeleted = notifier.socketRemoveNotification;
        await socketSvc.connect(token: accessToken);
        if (!mounted) return;
        ref.read(sessionUserIdProvider.notifier).state = userId;
        context.go('/home');
        await Future.delayed(const Duration(milliseconds: 500));
        notifier.fetchUnreadCount();
        notifier.registerFcmToken('stub-fcm-token-replace-with-firebase');
      } else {
        context.go('/start');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Image.asset(
          'assets/images/soundcloud_logo.png',
          width: 180,
        ),
      ),
    );
  }
}
