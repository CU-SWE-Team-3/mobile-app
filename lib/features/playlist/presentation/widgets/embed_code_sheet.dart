import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playlists_provider.dart';

/// Bottom sheet that fetches and displays the embeddable iframe code for a
/// playlist. Handles loading, success, and error states.
///
/// Shown by tapping "Embed" in [SharePlaylistSheet].
class EmbedCodeSheet extends ConsumerStatefulWidget {
  final String playlistId;

  const EmbedCodeSheet({super.key, required this.playlistId});

  @override
  ConsumerState<EmbedCodeSheet> createState() => _EmbedCodeSheetState();
}

class _EmbedCodeSheetState extends ConsumerState<EmbedCodeSheet> {
  bool _loading = true;
  String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEmbed();
  }

  Future<void> _fetchEmbed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(playlistRepositoryProvider);
      final code = await repo.getEmbedCode(widget.playlistId);
      if (mounted) setState(() { _loading = false; _code = code; });
    } catch (e) {
      if (!mounted) return;
      String msg = 'Failed to load embed code. Please try again.';
      if (e is DioException && e.response?.statusCode == 403) {
        msg = 'Embed unavailable — only the playlist owner can embed a private playlist.';
      }
      setState(() { _loading = false; _error = msg; });
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Embed code copied'),
        backgroundColor: Color(0xFF1F1F1F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'EMBED CODE',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Paste this iframe into any webpage to embed the playlist.',
              style: TextStyle(color: Color(0xFF666666), fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF5555), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _fetchEmbed,
                    child: const Text(
                      'Try again',
                      style: TextStyle(color: Color(0xFFFF5500)),
                    ),
                  ),
                ],
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _code!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy embed code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5500),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
