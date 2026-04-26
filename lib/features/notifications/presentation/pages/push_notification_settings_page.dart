import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';

class PushNotificationSettingsPage extends ConsumerStatefulWidget {
  const PushNotificationSettingsPage({super.key});

  @override
  ConsumerState<PushNotificationSettingsPage> createState() =>
      _PushNotificationSettingsPageState();
}

class _PushNotificationSettingsPageState
    extends ConsumerState<PushNotificationSettingsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(notificationPreferencesProvider.notifier).fetchPreferences(),
    );
  }

  // Optimistic toggle: applies the updater immediately and reverts on API
  // failure, showing a snackbar to the user.
  void _toggle(
      NotificationPreferences Function(NotificationPreferences) updater) {
    final current = ref.read(notificationPreferencesProvider).preferences;
    ref
        .read(notificationPreferencesProvider.notifier)
        .updatePreferences(updater(current))
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
    final prefs = state.preferences;
    final globalOn = prefs.pushEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Notification Settings',
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
                      // Global kill switch in a visually distinct card
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _ToggleTile(
                          icon: Icons.notifications_active,
                          label: 'Push Notifications',
                          subtitle: 'Master switch for all push notifications',
                          value: globalOn,
                          onChanged: (v) =>
                              _toggle((p) => p.copyWith(pushEnabled: v)),
                        ),
                      ),

                      _SectionLabel('Activity'),
                      _ToggleTile(
                        icon: Icons.favorite,
                        label: 'Likes',
                        value: prefs.allowLikes,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowLikes: v)),
                      ),
                      _ToggleTile(
                        icon: Icons.repeat,
                        label: 'Reposts',
                        value: prefs.allowReposts,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowReposts: v)),
                      ),
                      _ToggleTile(
                        icon: Icons.chat_bubble,
                        label: 'Comments',
                        value: prefs.allowComments,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowComments: v)),
                      ),
                      _ToggleTile(
                        icon: Icons.alternate_email,
                        label: 'Mentions',
                        value: prefs.allowMentions,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowMentions: v)),
                      ),

                      const Divider(color: Color(0xFF222222), height: 1),
                      _SectionLabel('People'),
                      _ToggleTile(
                        icon: Icons.person_add,
                        label: 'New Followers',
                        value: prefs.allowFollows,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowFollows: v)),
                      ),
                      _ToggleTile(
                        icon: Icons.message,
                        label: 'Messages',
                        value: prefs.allowMessages,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowMessages: v)),
                      ),

                      const Divider(color: Color(0xFF222222), height: 1),
                      _SectionLabel('Content'),
                      _ToggleTile(
                        icon: Icons.music_note,
                        label: 'New Tracks',
                        value: prefs.allowNewTracks,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowNewTracks: v)),
                      ),
                      _ToggleTile(
                        icon: Icons.queue_music,
                        label: 'New Playlists',
                        value: prefs.allowNewPlaylists,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowNewPlaylists: v)),
                      ),

                      const Divider(color: Color(0xFF222222), height: 1),
                      _SectionLabel('System'),
                      _ToggleTile(
                        icon: Icons.info_outline,
                        label: 'System Notifications',
                        value: prefs.allowSystem,
                        enabled: globalOn,
                        onChanged: (v) =>
                            _toggle((p) => p.copyWith(allowSystem: v)),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        enabled ? const Color(0xFFFF5500) : Colors.white24;
    final textColor = enabled ? Colors.white : Colors.white30;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: accent, size: 22),
      title: Text(label, style: TextStyle(color: textColor, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: const Color(0xFFFF5500),
        activeTrackColor: const Color(0x4DFF5500),
        inactiveThumbColor: Colors.white30,
        inactiveTrackColor: Colors.white12,
      ),
    );
  }
}
