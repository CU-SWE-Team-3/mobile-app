import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/dio_client.dart';
import 'core/providers/session_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/audio_handler_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/socket/socket_service.dart';
import 'core/themes/app_theme.dart';
import 'features/messaging/presentation/providers/messaging_providers.dart';
import 'features/notifications/presentation/providers/notification_provider.dart';
import 'features/player/presentation/widgets/mock_audio_ad_overlay.dart';
import 'features/premium/presentation/providers/subscription_provider.dart';
import 'injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FcmService.initializeCore();
  await initAudioHandler();
  await initDependencies();
  await dioClient.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<void>? _authInvalidatedSub;
  SocketService? _socketSvc;

  @override
  void initState() {
    super.initState();
    unawaited(LocalNotificationService.initialize());
    unawaited(FcmService.initialize());
    unawaited(FcmService.handleInitialMessageAfterFirstFrame());
    _authInvalidatedSub = dioClient.authInvalidated.listen((_) {
      if (!mounted) return;
      ref.read(sessionUserIdProvider.notifier).state = '';
      appRouter.go('/login-screen');
    });
    WidgetsBinding.instance.addObserver(this);
    _wireNotificationSocketCallbacks();
    _initDeepLinks();
  }

  void _wireNotificationSocketCallbacks() {
    final socketSvc = ref.read(socketServiceProvider);
    _socketSvc = socketSvc;
    socketSvc.onNewNotification = (data) {
      if (!mounted) return;
      ref.read(notificationProvider.notifier).socketAddNotification(data);
    };
    socketSvc.onNotificationRead = (id) {
      if (!mounted) return;
      ref.read(notificationProvider.notifier).socketMarkNotificationRead(id);
    };
    socketSvc.onAllNotificationsRead = () {
      if (!mounted) return;
      ref.read(notificationProvider.notifier).socketMarkAllRead();
    };
    socketSvc.onNotificationDeleted = (id) {
      if (!mounted) return;
      ref.read(notificationProvider.notifier).socketRemoveNotification(id);
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh subscription when user returns from background (e.g., from Stripe browser)
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _onResume() async {
    try {
      await ref.read(subscriptionProvider.notifier).refreshFromProfile();
      // Only navigate to PaymentSuccessPage when a checkout was explicitly
      // started from this app (pendingCheckout flag). Without this gate every
      // app-resume event — file picker close, login, keyboard dismiss — would
      // wrongly open PaymentSuccessPage for any already-subscribed user.
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool('pendingCheckout') ?? false;
      if (!pending) return;
      await prefs.setBool('pendingCheckout', false); // consume — one-shot
      final sub = ref.read(subscriptionProvider);
      if (sub.isPremium) {
        try {
          appRouter.go('/payment-success');
        } catch (_) {
          // ignore navigation errors during resume
        }
      }
    } catch (_) {
      // Ignore errors during resume refresh
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Cold start — app launched via a link
    final initial = await _appLinks.getInitialLink();
    if (initial != null) await _handleLink(initial);

    // Warm start — link received while app is already running
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
  }

  Future<void> _handleLink(Uri uri) async {
    // Payment return paths — no token required
    if (uri.path == '/payment-success') {
      appRouter.go('/payment-success');
      return;
    }
    if (uri.path == '/payment-cancel') {
      appRouter.go('/upgrade');
      return;
    }

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;

    if (uri.path == '/verify-email') {
      try {
        await dioClient.dio.post('/auth/verify-email', data: {'token': token});
        // Navigate to login so user can sign in with their verified account
        appRouter.go('/login-screen');
      } catch (_) {
        // Token invalid/expired — send to start so user can request a new one
        appRouter.go('/start');
      }
    } else if (uri.path == '/reset-password') {
      appRouter.go('/reset-password', extra: token);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketSvc?.onNewNotification = null;
    _socketSvc?.onNotificationRead = null;
    _socketSvc?.onAllNotificationsRead = null;
    _socketSvc?.onNotificationDeleted = null;
    _linkSub?.cancel();
    _authInvalidatedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(socketLifecycleProvider);
    ref.watch(socketMessageLifecycleProvider);

    return MaterialApp.router(
      title: 'BioBeats',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            const MockAudioAdOverlay(),
          ],
        );
      },
    );
  }
}
