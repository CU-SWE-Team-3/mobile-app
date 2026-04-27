import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsSettingsPage extends ConsumerStatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  ConsumerState<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState
    extends ConsumerState<NotificationsSettingsPage> {
  bool _pushEnabled = true;

  final Map<String, bool> _toggles = {
    'likes': true,
    'comments': true,
    'reposts': true,
    'new_followers': true,
    'messages': true,
  };

  static const _items = [
    _NotifItem(
      key: 'likes',
      title: 'Likes',
      subtitle: 'When someone likes your track',
      icon: Icons.favorite,
    ),
    _NotifItem(
      key: 'comments',
      title: 'Comments',
      subtitle: 'When someone comments on your track',
      icon: Icons.chat_bubble,
    ),
    _NotifItem(
      key: 'reposts',
      title: 'Reposts',
      subtitle: 'When someone reposts your track',
      icon: Icons.repeat,
    ),
    _NotifItem(
      key: 'new_followers',
      title: 'New Followers',
      subtitle: 'When someone follows you',
      icon: Icons.person_add,
    ),
    _NotifItem(
      key: 'messages',
      title: 'Messages',
      subtitle: 'When you receive a new message',
      icon: Icons.mail,
    ),
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
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Notification Types'),
          ..._items.map(_buildToggleTile),
          const Divider(color: Color(0xFF2A2A2A), indent: 16, endIndent: 16, height: 32),
          const _SectionHeader(title: 'Push Notifications'),
          SwitchListTile(
            activeColor: const Color(0xFFFF5500),
            secondary: Icon(
              Icons.notifications,
              color: _pushEnabled ? Colors.white : Colors.grey[700],
            ),
            title: Text(
              'Enable push notifications',
              style: TextStyle(
                color: _pushEnabled ? Colors.white : Colors.grey[700],
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              'Receive notifications on your device',
              style: TextStyle(
                color: _pushEnabled ? Colors.white54 : Colors.grey[800],
                fontSize: 13,
              ),
            ),
            value: _pushEnabled,
            onChanged: (val) => setState(() => _pushEnabled = val),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildToggleTile(_NotifItem item) {
    final enabled = _toggles[item.key]!;
    return SwitchListTile(
      activeColor: const Color(0xFFFF5500),
      secondary: Icon(
        item.icon,
        color: _pushEnabled ? Colors.white : Colors.grey[700],
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: _pushEnabled ? Colors.white : Colors.grey[700],
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: TextStyle(
          color: _pushEnabled ? Colors.white54 : Colors.grey[800],
          fontSize: 13,
        ),
      ),
      value: _pushEnabled && enabled,
      onChanged: _pushEnabled
          ? (val) => setState(() => _toggles[item.key] = val)
          : null,
    );
  }
}

class _NotifItem {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  const _NotifItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
