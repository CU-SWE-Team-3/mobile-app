import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/features/settings/presentation/pages/basic_settings_page.dart';
import 'package:soundcloud_clone/features/settings/presentation/pages/legal_page.dart';

class SettingsMainPage extends ConsumerWidget {
  const SettingsMainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Icon(Icons.cast, color: Colors.white),
          ),
        ],
      ),
      body: ListView(
        children: [

          const SizedBox(height: 8),

          _SettingsMenuItem(title: 'Import my music', onTap: () {}),
          _SettingsMenuItem(title: 'Account', onTap: () {}),
          _SettingsMenuItem(title: 'Upload', onTap: () {}),
          _SettingsMenuItem(
            title: 'Basic settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BasicSettingsPage()),
            ),
          ),
          _SettingsMenuItem(title: 'Social settings', onTap: () {}),
          _SettingsMenuItem(title: 'Inbox', onTap: () {}),
          _SettingsMenuItem(title: 'Notifications', onTap: () {}),
          _SettingsMenuItem(title: 'Add widgets', onTap: () {}),
          _SettingsMenuItem(title: 'Analytics', onTap: () {}),
          _SettingsMenuItem(title: 'Communications', onTap: () {}),
          _SettingsMenuItem(title: 'Advertising', onTap: () {}),
          _SettingsMenuItem(title: 'Support', onTap: () {}),
          _SettingsMenuItem(
            title: 'Legal',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage()),
            ),
          ),

          const SizedBox(height: 32),

          // ── Sign out button ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _showSignOutDialog(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(30),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Sign out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── App version ──────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  'App version 2026.03.05-release (345050)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'Troubleshooting id',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  '60a71353-82cb-4266-b292-4cdaf17334cb',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ── Sign out dialog ───────────────────────────────────────────────────────
  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Clear user data?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'You will have to reconnect your SoundCloud account.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            // ✅ uses dialogContext — only closes dialog, stays on settings
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // close dialog
              context.go('/splash');        // sign out
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings menu item ────────────────────────────────────────────────────────

class _SettingsMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}