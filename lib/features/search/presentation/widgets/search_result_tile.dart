import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/search_result.dart';

class SearchResultTile extends StatelessWidget {
  final String displayName;
  final String subtitle;
  final String? imageUrl;
  final SearchEntityType type;
  final VoidCallback onTap;
  final Key? tileKey;
  final Widget? trailing;

  /// When non-null, renders an × button that calls this callback.
  /// Used in history mode to permanently remove the entry.
  final VoidCallback? onRemove;

  const SearchResultTile({
    super.key,
    required this.displayName,
    required this.subtitle,
    this.imageUrl,
    required this.type,
    required this.onTap,
    this.tileKey,
    this.trailing,
    this.onRemove,
  });

  bool get _isCircle => type == SearchEntityType.user;

  bool get _hasValidImage =>
      imageUrl != null &&
      imageUrl!.isNotEmpty &&
      !imageUrl!.contains('default-avatar') &&
      !imageUrl!.contains('default-artwork') &&
      imageUrl!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withValues(alpha: 0.55);

    return GestureDetector(
      key: tileKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sub, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                key: const ValueKey('search_history_remove_button'),
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(Icons.close, color: sub, size: 18),
                ),
              ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: trailing,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final img = _hasValidImage
        ? CachedNetworkImage(
            imageUrl: imageUrl!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _placeholder(),
          )
        : _placeholder();

    if (_isCircle) {
      return ClipOval(child: SizedBox(width: 48, height: 48, child: img));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: 48, height: 48, child: img),
    );
  }

  Widget _placeholder() {
    final (IconData icon, Color bg) = switch (type) {
      SearchEntityType.user => (Icons.person, const Color(0xFF3A3A5C)),
      SearchEntityType.playlist => (Icons.queue_music, const Color(0xFF2A3A2A)),
      SearchEntityType.track => (Icons.music_note, const Color(0xFF2A2A2A)),
    };
    return Container(
      width: 48,
      height: 48,
      color: bg,
      child: Icon(icon, color: Colors.white38, size: 24),
    );
  }
}
