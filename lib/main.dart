import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/themes/app_theme.dart';
import 'injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  await dioClient.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
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
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SoundCloud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
