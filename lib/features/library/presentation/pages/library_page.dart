import 'package:flutter/material.dart';

import '../../../../../core/themes/app_theme.dart';

// TODO: Module 2/4 — Khaled Mostafa / Ziad Farghal / Ziad Awad
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Text(
          'Library',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
