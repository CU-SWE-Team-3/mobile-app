import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/features/notifications/presentation/providers/notification_provider.dart';

class InboxSettingsPage extends ConsumerStatefulWidget {
  const InboxSettingsPage({super.key});

  @override
  ConsumerState<InboxSettingsPage> createState() => _InboxSettingsPageState();
}

class _InboxSettingsPageState extends ConsumerState<InboxSettingsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationPreferencesProvider.notifier).fetchPreferences(),
    );
  }

  void _toggleMessagePermission(bool allowEveryone) {
    final current = ref.read(notificationPreferencesProvider).preferences;
    ref
        .read(notificationPreferencesProvider.notifier)
        .updatePreferences(
          current.copyWith(
            messagePermission: allowEveryone ? 'Everyone' : 'Following',
          ),
        )
        .then((success) {
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save settings. Please try again.'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationPreferencesProvider);
    final allowEveryone = state.preferences.messagePermission == 'Everyone';

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Inbox',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            )
          : Column(
              children: [
                if (state.isSaving)
                  const LinearProgressIndicator(
                    color: Color(0xFFFF5500),
                    backgroundColor: Color(0xFF222222),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: const Text(
                          'Receive messages from anyone',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        subtitle: const Text(
                          'If you turn this setting off, only people you follow will be able to send you messages.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: Switch(
                          value: allowEveryone,
                          onChanged: _toggleMessagePermission,
                          activeThumbColor: const Color(0xFFFF5500),
                          activeTrackColor: const Color(0x4DFF5500),
                          inactiveThumbColor: Colors.white30,
                          inactiveTrackColor: Colors.white12,
                        ),
                      ),
                      const Divider(color: Color(0xFF222222), height: 1),
                      InkWell(
                        onTap: () => context.push('/settings/notifications'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Notification settings',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white54,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
