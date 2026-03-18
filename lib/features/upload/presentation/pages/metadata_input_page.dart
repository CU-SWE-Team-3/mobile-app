import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/themes/app_theme.dart';
import '../providers/upload_provider.dart';

class MetadataInputPage extends ConsumerStatefulWidget {
  const MetadataInputPage({super.key});

  @override
  ConsumerState<MetadataInputPage> createState() => _MetadataInputPageState();
}

class _MetadataInputPageState extends ConsumerState<MetadataInputPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  late TextEditingController _albumCtrl;
  late TextEditingController _genreCtrl;
  late TextEditingController _descriptionCtrl;

  @override
  void initState() {
    super.initState();
    final uploadState = ref.read(uploadProvider);
    _titleCtrl = TextEditingController(text: uploadState.track.title);
    _artistCtrl = TextEditingController(text: uploadState.track.artist);
    _albumCtrl = TextEditingController(text: uploadState.track.album ?? '');
    _genreCtrl = TextEditingController(text: uploadState.track.genre ?? '');
    _descriptionCtrl =
        TextEditingController(text: uploadState.track.description ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _genreCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _saveMetadata() {
    ref.read(uploadProvider.notifier).updateTrackField(
      title: _titleCtrl.text.trim(),
      artist: _artistCtrl.text.trim(),
      album: _albumCtrl.text.trim(),
      genre: _genreCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metadata saved successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'Track Metadata',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildSectionTitle('Essential Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _titleCtrl,
              label: 'Track Title *',
              hint: 'Enter track title',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _artistCtrl,
              label: 'Artist Name *',
              hint: 'Enter artist name',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Additional Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _albumCtrl,
              label: 'Album',
              hint: 'Enter album name (optional)',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _genreCtrl,
              label: 'Genre',
              hint: 'Enter genre (optional)',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Description'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionCtrl,
              label: 'Description',
              hint: 'Add a description about your track (optional)',
              maxLines: 5,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveMetadata,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: const Text(
                  'Save Metadata',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
