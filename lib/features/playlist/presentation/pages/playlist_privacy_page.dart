import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist.dart';
import '../providers/playlists_provider.dart';
import '../widgets/playlist_url_builder.dart';

class PlaylistPrivacyPage extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistPrivacyPage({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistPrivacyPage> createState() =>
      _PlaylistPrivacyPageState();
}

class _PlaylistPrivacyPageState extends ConsumerState<PlaylistPrivacyPage> {
  static const _bg = Color(0xFF111111);
  static const _surface = Color(0xFF1F1F1F);
  static const _primary = Color(0xFFFF5500);
  static const _secondary = Color(0xFF999999);

  late bool _isPublic;
  late String? _secretToken;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.playlist.isPublic;
    _secretToken = widget.playlist.secretToken;
  }

  Future<void> _toggle(bool newIsPublic) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(playlistsProvider.notifier)
          .updateVisibility(widget.playlist.id, newIsPublic);
      if (mounted) {
        setState(() {
          _isPublic = newIsPublic;
          // Backend clears the secret token when toggling to public.
          if (newIsPublic) _secretToken = null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to update privacy. Please try again.';
        });
      }
    }
  }

  /// Builds the private-link URL using current local state for isPublic/secretToken.
  String get _privateUrl => buildPlaylistUrl(Playlist(
        id: widget.playlist.id,
        title: widget.playlist.title,
        ownerName: widget.playlist.ownerName,
        isPublic: false,
        permalink: widget.playlist.permalink,
        ownerPermalink: widget.playlist.ownerPermalink,
        secretToken: _secretToken,
      ));

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _privateUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Private link copied'),
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Privacy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          key: const ValueKey('playlist_back_button'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: _loading ? null : () => Navigator.maybePop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Playlist identifier
          Text(
            widget.playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.playlist.ownerName,
            style: const TextStyle(color: _secondary, fontSize: 13),
          ),
          const SizedBox(height: 28),

          // Toggle card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Public playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Anyone can find and listen to this playlist.',
                        style: TextStyle(color: _secondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_loading)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  )
                else
                  Switch(
                    key: const ValueKey('playlist_privacy_toggle'),
                    value: _isPublic,
                    onChanged: _toggle,
                    activeThumbColor: _primary,
                    activeTrackColor: _primary.withValues(alpha: 0.5),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFF3A3A3A),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Context card (changes with state)
          _InfoCard(
            icon: _isPublic ? Icons.public : Icons.lock_outline,
            title: _isPublic ? 'Public' : 'Private',
            description: _isPublic
                ? 'Your playlist appears in search results and on your profile. Anyone with the link can listen.'
                : 'Your playlist is hidden from search and your profile. Only people you share the secret link with can listen.',
            accent: _isPublic ? _secondary : _primary,
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFF4444), fontSize: 13),
            ),
          ],

          // Private link section — only shown when playlist is private
          if (!_isPublic) ...[
            const SizedBox(height: 28),
            const Text(
              'PRIVATE LINK',
              style: TextStyle(
                color: _secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _privateUrl,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _copyLink,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy private link'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Share this link with people you want to give access. '
              'The secret token in the URL grants listen access without making the playlist public.',
              style: TextStyle(color: _secondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
