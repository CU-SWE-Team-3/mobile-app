import 'package:flutter/material.dart';

import '../../../../../core/themes/app_theme.dart';

// TODO: Module 8 — Ziad Farghal
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Text(
          'Search & Discover',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
