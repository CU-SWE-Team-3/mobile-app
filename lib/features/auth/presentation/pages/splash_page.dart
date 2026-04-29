import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/deep_link_state.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/user_session.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    if (_started) return;
    _started = true;
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('[Splash] deepLinkHandled=$deepLinkHandled');
    if (!mounted || deepLinkHandled) return;

    var accessToken = await UserSession.getAccessToken();
    final userId = await UserSession.getUserId();
    final savedUserId = userId ?? '';
    debugPrint('[Splash] token=${_jwtSummary(accessToken)} userId=$userId');
    var hasSession =
        accessToken != null && accessToken.isNotEmpty && savedUserId.isNotEmpty;

    if (hasSession && _isExpiredOrStale(accessToken)) {
      debugPrint('[Splash] saved token is expired/stale - refreshing');
      accessToken = await dioClient.refreshAccessToken();
      hasSession = accessToken != null &&
          accessToken.isNotEmpty &&
          savedUserId.isNotEmpty;
    }

    if (mounted) {
      if (hasSession) {
        ref.read(sessionUserIdProvider.notifier).state = savedUserId;
        context.go('/home');
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        ref.read(notificationProvider.notifier).fetchUnreadCount();
        unawaited(FcmService.registerCurrentToken());
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

  String _jwtSummary(String? token) {
    if (token == null || token.isEmpty) return 'none';
    try {
      final parts = token.split('.');
      if (parts.length < 2) return 'present';
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final id = payload['id'] ?? payload['sub'] ?? payload['userId'];
      final iat = payload['iat'];
      final exp = payload['exp'];
      return '(id=$id iat=$iat exp=$exp)';
    } catch (_) {
      return 'present';
    }
  }

  bool _isExpiredOrStale(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return false;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
      return expiresAt.isBefore(DateTime.now().toUtc().add(
            const Duration(minutes: 1),
          ));
    } catch (_) {
      return false;
    }
  }
}
