import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restart_app/restart_app.dart'; // 👈 change import
import 'package:path_provider/path_provider.dart';

class BasicSettingsPage extends ConsumerWidget {
  const BasicSettingsPage({super.key});

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
          'Basic settings',
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
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),

          // ── Clear application cache ───────────────────────────
          GestureDetector(
            onTap: () => _showClearCacheDialog(context),
            child: const _BasicSettingItem(
              title: 'Clear application cache',
              subtitle:
                  'Clear the application cache to free up memory on your device',
            ),
          ),

          const SizedBox(height: 24),

          // ── Change app icon ───────────────────────────────────
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppIconPage(),
                ),
              );
            },
            child: const _BasicSettingItem(
              title: 'Change app icon',
              subtitle: 'Custom app icons to match your style',
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to clear\nthe app cache?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will restart the app and stop any ongoing playback.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // NO button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'NO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context); // close confirm dialog

                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => Dialog(
                          backgroundColor: const Color(0xFF2A2A2A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Clearing cache',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 20),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      'Deleting cached files...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      // Clear cache
                      await _clearCache();

                      // Wait a moment so user sees the loading
                      await Future.delayed(const Duration(seconds: 2));

                      // Restart app
                      Restart.restartApp();
                    },
                    child: const Text(
                      'YES',
                      style: TextStyle(
                        color: Color(0xFFFF5500),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _clearCache() async {
  try {
    // Clear temp directory
    final tempDir = await getTemporaryDirectory();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    // Clear app cache directory
    final cacheDir = await getApplicationCacheDirectory();
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  } catch (e) {
    debugPrint('Error clearing cache: $e');
  }
}

// ── Basic setting item ────────────────────────────────────────────────────────

class _BasicSettingItem extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BasicSettingItem({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ── App Icon Page ─────────────────────────────────────────────────────────────

class AppIconPage extends StatefulWidget {
  const AppIconPage({super.key});

  @override
  State<AppIconPage> createState() => _AppIconPageState();
}

class _AppIconPageState extends State<AppIconPage> {
  String _selectedIcon = 'Default';

  final List<Map<String, dynamic>> _icons = [
    {
      "name": "Default",
      "color": Colors.transparent,
      "locked": false,
      "isDefault": true
    },
    {
      "name": "OG",
      "color": const Color(0xFFFF5500),
      "locked": false,
      "isDefault": false
    },
    {
      "name": "Chrome",
      "color": Colors.blueGrey,
      "locked": true,
      "isDefault": false
    },
    {
      "name": "Rose Gold",
      "color": const Color(0xFFB76E79),
      "locked": true,
      "isDefault": false
    },
    {
      "name": "Silver",
      "color": Colors.grey,
      "locked": true,
      "isDefault": false
    },
    {
      "name": "Soft Purple",
      "color": const Color(0xFF9B7FD4),
      "locked": true,
      "isDefault": false
    },
    {
      "name": "Hot Pink",
      "color": const Color(0xFFFF0080),
      "locked": true,
      "isDefault": false
    },
    {
      "name": "Tie-Dye",
      "color": Colors.deepOrange,
      "locked": true,
      "isDefault": false
    },
    {
      "name": "Leopard",
      "color": const Color(0xFFD2691E),
      "locked": true,
      "isDefault": false
    },
  ];

  @override
  Widget build(BuildContext context) {
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
          'App icon',
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
      body: ListView.builder(
        itemCount: _icons.length,
        itemBuilder: (context, index) {
          final icon = _icons[index];
          final bool isSelected = _selectedIcon == icon["name"];
          final bool isLocked = icon["locked"];

          return InkWell(
            onTap: () {
              if (!isLocked) {
                setState(() => _selectedIcon = icon["name"]);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Icon preview
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: icon["isDefault"] ? Colors.black : icon["color"],
                      borderRadius: BorderRadius.circular(12),
                      border: icon["isDefault"]
                          ? Border.all(color: Colors.grey[800]!, width: 1)
                          : null,
                    ),
                    child: Icon(
                      Icons.cloud,
                      color: icon["isDefault"] ? Colors.white : Colors.white,
                      size: 32,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Name
                  Expanded(
                    child: Text(
                      icon["name"],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Lock or checkmark
                  if (isLocked)
                    Icon(Icons.lock_outline, color: Colors.grey[600], size: 20)
                  else if (isSelected)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
