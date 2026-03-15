import 'package:flutter/material.dart';

import '../../../../../core/themes/app_theme.dart';

// TODO: Module 2 — Ahmed Hassan Bahr
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Text(
          'Your Profile',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
