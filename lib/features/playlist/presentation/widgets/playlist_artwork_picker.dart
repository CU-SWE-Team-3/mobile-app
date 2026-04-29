import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/playlist_repository.dart';

/// A tappable artwork square that allows the user to pick a new cover image
/// from the device gallery and upload it via [PlaylistRepository.uploadArtwork].
///
/// **Usage** (Awad's Edit page will drop this in):
/// ```dart
/// PlaylistArtworkPicker(
///   playlistId: playlist.id,
///   currentArtworkUrl: playlist.artworkUrl,
///   repository: ref.read(playlistRepositoryProvider),
///   onArtworkChanged: (newUrl) {
///     // update local state / provider with newUrl
///   },
/// )
/// ```
///
/// The widget manages its own upload state (spinner overlay while uploading).
/// On error it shows a [SnackBar] and leaves the artwork unchanged.
/// The caller is notified of success via [onArtworkChanged].
class PlaylistArtworkPicker extends StatefulWidget {
  final String playlistId;
  final String? currentArtworkUrl;
  final PlaylistRepository repository;
  final void Function(String newUrl) onArtworkChanged;

  // Injectable for widget tests — defaults to the real ImagePicker.
  @visibleForTesting
  final Future<XFile?> Function()? onPickImage;

  const PlaylistArtworkPicker({
    super.key,
    required this.playlistId,
    this.currentArtworkUrl,
    required this.repository,
    required this.onArtworkChanged,
    this.onPickImage,
  });

  @override
  State<PlaylistArtworkPicker> createState() => _PlaylistArtworkPickerState();
}

class _PlaylistArtworkPickerState extends State<PlaylistArtworkPicker> {
  bool _uploading = false;
  String? _uploadedUrl;

  Future<void> _pick() async {
    if (_uploading) return;

    final Future<XFile?> Function() pickFn = widget.onPickImage ??
        () => ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
              maxWidth: 1000,
              maxHeight: 1000,
            );

    final file = await pickFn();
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await widget.repository.uploadArtwork(
        widget.playlistId,
        bytes,
        file.name,
      );
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadedUrl = url;
      });
      widget.onArtworkChanged(url);
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not upload artwork. Please try again.'),
          backgroundColor: Color(0xFF3A1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = _uploadedUrl ?? widget.currentArtworkUrl;
    return GestureDetector(
      key: const Key('artwork_picker_tap_target'),
      onTap: _uploading ? null : _pick,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 120,
              height: 120,
              child: displayUrl != null && displayUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: displayUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _ArtworkPlaceholder(),
                      errorWidget: (_, __, ___) => const _ArtworkPlaceholder(),
                    )
                  : const _ArtworkPlaceholder(),
            ),
          ),
          if (_uploading)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.music_note, color: Colors.white38, size: 40),
        ),
      );
}
