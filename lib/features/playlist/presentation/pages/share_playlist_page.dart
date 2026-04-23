import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/playlist.dart';

// ── Stub page (router entry /playlist/share kept alive) ──────────────────────

class SharePlaylistPage extends ConsumerWidget {
  const SharePlaylistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text('Share Playlist',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text('Share Playlist',
            style: TextStyle(color: Colors.white54, fontSize: 18)),
      ),
    );
  }
}

// ── Reusable share bottom sheet ───────────────────────────────────────────────

class SharePlaylistSheet extends StatelessWidget {
  final Playlist playlist;

  const SharePlaylistSheet({super.key, required this.playlist});

  static const _base = 'https://biobeats.duckdns.org';

  String get _url {
    final op = playlist.ownerPermalink;
    final pp = playlist.permalink;
    final st = playlist.secretToken;

    final path = (op != null && op.isNotEmpty && pp != null && pp.isNotEmpty)
        ? '$_base/$op/sets/$pp'
        : '$_base/playlists/${playlist.id}';

    if (!playlist.isPublic && st != null && st.isNotEmpty) {
      return '$path?secret_token=$st';
    }
    return path;
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Color(0xFF1F1F1F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final encoded = Uri.encodeComponent(
      'Listen to ${playlist.title}, a playlist by ${playlist.ownerName}'
      ' on #BioBeats\n$_url',
    );
    await launchUrl(
      Uri.parse('whatsapp://send?text=$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header: artwork + title + owner + privacy badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: playlist.artworkUrl != null &&
                              playlist.artworkUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: playlist.artworkUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const _ArtworkFallback(),
                              errorWidget: (_, __, ___) =>
                                  const _ArtworkFallback(),
                            )
                          : const _ArtworkFallback(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          playlist.ownerName,
                          style: const TextStyle(
                              color: Color(0xFF999999), fontSize: 13),
                        ),
                        if (!playlist.isPublic) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline,
                                    color: Colors.white54, size: 10),
                                SizedBox(width: 3),
                                Text('Private',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 28),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SHARE',
                  style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ShareButton(
                    icon: Icons.link_rounded,
                    label: 'Copy Link',
                    bgColor: const Color(0xFF2A2A2A),
                    onTap: () => _copyLink(context),
                  ),
                  _ShareButton(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    bgColor: const Color(0xFF25D366),
                    onTap: _openWhatsApp,
                  ),
                  _ShareButton(
                    icon: Icons.message_rounded,
                    label: 'Message',
                    bgColor: const Color(0xFF2A2A2A),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.music_note, color: Colors.white38, size: 32),
        ),
      );
}
