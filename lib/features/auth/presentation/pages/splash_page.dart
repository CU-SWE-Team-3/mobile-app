import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/deep_link_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && !deepLinkHandled) {
      context.go('/start');
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
