import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist.dart';
import '../providers/playlists_provider.dart';

const _bg = Color(0xFF111111);
const _surface = Color(0xFF1F1F1F);
const _secondary = Color(0xFF999999);

class EditPlaylistPage extends ConsumerStatefulWidget {
  final Playlist? playlist;

  const EditPlaylistPage({super.key, this.playlist});

  @override
  ConsumerState<EditPlaylistPage> createState() => _EditPlaylistPageState();
}

class _EditPlaylistPageState extends ConsumerState<EditPlaylistPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late bool _isPrivate;
  bool _submitting = false;
  String? _errorMessage;

  static const int _maxTitle = 100;
  static const int _maxDesc = 1000;

  @override
  void initState() {
    super.initState();
    final p = widget.playlist;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descController = TextEditingController();
    _isPrivate = !(p?.isPublic ?? true);
    _titleController.addListener(_onChanged);
    _descController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onChanged);
    _descController.removeListener(_onChanged);
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _titleValid {
    final v = _titleController.text.trim();
    return v.isNotEmpty && v.length <= _maxTitle;
  }

  bool get _descValid => _descController.text.length <= _maxDesc;

  bool get _canSave => _titleValid && _descValid && !_submitting;

  Future<void> _save() async {
    if (!_canSave || widget.playlist == null) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(playlistsProvider.notifier).updateMetadata(
            widget.playlist!.id,
            title: _titleController.text.trim(),
            isPublic: !_isPrivate,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'Failed to save changes. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlist == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('Playlist not found',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Edit Playlist',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            key: const Key('saveButton'),
            onPressed: _canSave ? _save : null,
            child: Text(
              _submitting ? 'Saving…' : 'Save',
              style: TextStyle(
                color: _canSave ? const Color(0xFFFF5500) : Colors.white38,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            MaterialBanner(
              backgroundColor: const Color(0xFF3A1A1A),
              content: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  child: const Text('Dismiss',
                      style: TextStyle(color: Color(0xFFFF5500))),
                ),
              ],
            ),
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                _sectionLabel('TITLE'),
                const SizedBox(height: 8),
                _buildTextField(
                  key: const Key('titleField'),
                  controller: _titleController,
                  hint: 'Playlist title',
                  error: _titleController.text.trim().isNotEmpty &&
                          _titleController.text.trim().length > _maxTitle
                      ? 'Max $_maxTitle characters'
                      : null,
                ),
                const SizedBox(height: 24),
                _sectionLabel('DESCRIPTION (OPTIONAL)'),
                const SizedBox(height: 8),
                _buildTextField(
                  key: const Key('descField'),
                  controller: _descController,
                  hint: 'Add a description…',
                  maxLines: 5,
                  error: _descController.text.length > _maxDesc
                      ? 'Max $_maxDesc characters'
                      : null,
                ),
                const SizedBox(height: 24),
                _sectionLabel('PRIVACY'),
                const SizedBox(height: 8),
                _privacyRow(),
                const SizedBox(height: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: _secondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      );

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? error,
  }) =>
      TextField(
        key: key,
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          errorText: error,
          errorStyle: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFFF5500), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _privacyRow() => GestureDetector(
        onTap: () => setState(() => _isPrivate = !_isPrivate),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _isPrivate ? Icons.lock_outline : Icons.public_outlined,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPrivate ? 'Private' : 'Public',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPrivate
                          ? 'Only you can see this playlist'
                          : 'Everyone can see this playlist',
                      style:
                          const TextStyle(color: _secondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPrivate,
                onChanged: (_) => setState(() => _isPrivate = !_isPrivate),
                activeTrackColor: const Color(0xFFFF5500),
              ),
            ],
          ),
        ),
      );
}
