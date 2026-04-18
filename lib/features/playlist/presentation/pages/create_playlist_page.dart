import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/library/presentation/pages/library_playlists_page.dart';
import '../../../../features/playlist/domain/entities/playlist.dart';

final _avatarUrlProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('avatarUrl') ?? '';
});

// Standalone full-page version of the create playlist flow,
// kept as a thin wrapper around the shared provider.
class CreatePlaylistPage extends ConsumerStatefulWidget {
  const CreatePlaylistPage({super.key});

  @override
  ConsumerState<CreatePlaylistPage> createState() => _CreatePlaylistPageState();
}

class _CreatePlaylistPageState extends ConsumerState<CreatePlaylistPage> {
  late final TextEditingController _ctrl;
  bool _isPublic = true;

  static const _bg = Color(0xFF111111);
  static const _surface = Color(0xFF1F1F1F);
  static const _primary = Color(0xFFFF5500);
  static const _secondary = Color(0xFF999999);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: 'Untitled Playlist')
      ..selection = const TextSelection(baseOffset: 0, extentOffset: 17);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _placeholder() => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.music_note, color: Colors.white24, size: 48),
        ),
      );

  void _save() {
    final title =
        _ctrl.text.trim().isEmpty ? 'Untitled Playlist' : _ctrl.text.trim();
    ref.read(playlistsProvider.notifier).add(
          Playlist(title: title, ownerName: 'You', isPublic: _isPublic),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create playlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _save,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Artwork preview — shows avatar when no playlist artwork exists
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: ref.watch(_avatarUrlProvider).maybeWhen(
                    data: (url) {
                      final isValid =
                          url.isNotEmpty && !url.contains('default-avatar');
                      return isValid
                          ? CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder();
                    },
                    orElse: _placeholder,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: _primary,
              decoration: InputDecoration(
                labelText: 'Playlist title',
                labelStyle: const TextStyle(color: _secondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _primary),
                ),
                filled: true,
                fillColor: _surface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Make public',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const Spacer(),
                Switch(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeThumbColor: _primary,
                  activeTrackColor: _primary.withValues(alpha: 0.5),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFF3A3A3A),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
