import 'package:flutter/material.dart';

import '../../../../../core/themes/app_theme.dart';

// TODO: Module 8 — Kareemeldine Erfan
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Text(
          'Home Feed',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
