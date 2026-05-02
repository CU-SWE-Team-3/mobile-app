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
import 'core/themes/app_theme.dart';
import 'features/feed/data/services/resource_resolver_service.dart';
import 'features/messaging/presentation/providers/messaging_providers.dart';
import 'features/notifications/presentation/providers/notification_fcm_lifecycle_provider.dart';
import 'features/notifications/presentation/providers/notification_socket_lifecycle_provider.dart';
import 'features/player/presentation/providers/player_provider.dart';
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
  late final ResourceResolverService _resourceResolver;
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<void>? _authInvalidatedSub;

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
    _resourceResolver = ResourceResolverService(dioClient.dio);
    _initDeepLinks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _onResume() async {
    try {
      await ref.read(subscriptionProvider.notifier).refreshFromProfile();
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool('pendingCheckout') ?? false;
      if (!pending) return;
      final sub = ref.read(subscriptionProvider);
      if (sub.isPremium) {
        await prefs.setBool('pendingCheckout', false);
        try {
          appRouter.go('/payment-success');
        } catch (_) {
          // Ignore navigation errors during resume.
        }
      }
    } catch (_) {
      // Ignore errors during resume refresh.
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    final initial = await _appLinks.getInitialLink();
    if (initial != null) await _handleLink(initial);

    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
  }

  Future<void> _handleLink(Uri uri) async {
    final paymentTarget = uri.scheme == 'biobeats' ? uri.host : uri.path;
    if (paymentTarget == 'payment-success' ||
        paymentTarget == '/payment-success') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pendingCheckout', false);
      await ref.read(subscriptionProvider.notifier).refreshFromProfile();
      appRouter.go('/payment-success');
      return;
    }
    if (paymentTarget == 'payment-cancel' ||
        paymentTarget == 'payment-cancelled' ||
        paymentTarget == '/payment-cancel' ||
        paymentTarget == '/payment-cancelled') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pendingCheckout', false);
      appRouter.go('/upgrade');
      return;
    }

    final token = uri.queryParameters['token'];
    if (token != null && token.isNotEmpty && uri.path == '/verify-email') {
      try {
        await dioClient.dio.post('/auth/verify-email', data: {'token': token});
        appRouter.go('/login-screen');
      } catch (_) {
        appRouter.go('/start');
      }
      return;
    }

    if (token != null && token.isNotEmpty && uri.path == '/reset-password') {
      appRouter.go('/reset-password', extra: token);
      return;
    }

    final resolved = await _resourceResolver.resolve(uri);
    if (!mounted) return;

    switch (resolved.kind) {
      case ResolvedResourceKind.user:
        final permalink = resolved.userPermalink;
        if (permalink != null && permalink.isNotEmpty) {
          appRouter.go('/user/${Uri.encodeComponent(permalink)}');
        }
        return;
      case ResolvedResourceKind.track:
        final trackId = resolved.trackId;
        final title = resolved.title;
        final artistName = resolved.artistName;
        if (trackId == null ||
            trackId.isEmpty ||
            title == null ||
            title.isEmpty ||
            artistName == null ||
            artistName.isEmpty) {
          _showDeepLinkMessage('We could not open that track link.');
          return;
        }

        final track = PlayerTrack(
          id: trackId,
          title: title,
          artist: artistName,
          audioUrl: '',
          coverUrl: resolved.artworkUrl,
          duration: resolved.durationSeconds != null
              ? Duration(seconds: resolved.durationSeconds!)
              : null,
          artistId: resolved.artistId,
          artistPermalink: resolved.artistPermalink,
          trackPermalink: resolved.trackPermalink,
        );

        await ref.read(playerProvider.notifier).playTrack(track);
        ref.read(playerProvider.notifier).setQueueContext(
              'track',
              contextId: trackId,
            );
        appRouter.go('/player');
        return;
      case ResolvedResourceKind.playlist:
        final playlistId = resolved.playlistId;
        if (playlistId == null || playlistId.isEmpty) {
          _showDeepLinkMessage('We could not open that playlist link.');
          return;
        }
        appRouter.go('/playlist', extra: {'playlistId': playlistId});
        return;
      case ResolvedResourceKind.notFound:
        _showDeepLinkMessage(
          resolved.message ?? 'We could not open that shared link.',
        );
        return;
      case ResolvedResourceKind.ignored:
        return;
    }
  }

  void _showDeepLinkMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _authInvalidatedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(socketLifecycleProvider);
    ref.watch(socketMessageLifecycleProvider);
    ref.watch(notificationSocketLifecycleProvider);
    ref.watch(notificationFcmLifecycleProvider);

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
