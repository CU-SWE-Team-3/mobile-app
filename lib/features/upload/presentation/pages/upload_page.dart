import 'package:flutter/material.dart';

import '../../../../../core/themes/app_theme.dart';

// TODO: Module 4 — Ziad Farghal / Ahmed Hassan Bahr
class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Text(
          'Upload Track',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
