import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/themes/app_theme.dart';
import '../providers/upload_provider.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  late TextEditingController _albumCtrl;
  late TextEditingController _genreCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _tagsCtrl;

  final List<String> _selectedTags = [];
  DateTime? _selectedDate;

  static const _bg = AppTheme.background;
  static const _surface = AppTheme.surface;
  static const _orange = AppTheme.primary;
  static final _textSecondary = Colors.white.withValues(alpha: 0.6);
  static final _divider = Colors.white.withValues(alpha: 0.1);

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _artistCtrl = TextEditingController();
    _albumCtrl = TextEditingController();
    _genreCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _tagsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _genreCtrl.dispose();
    _descriptionCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          ref
              .read(uploadProvider.notifier)
              .updateTrackField(audioFilePath: filePath);
          ref.read(uploadProvider.notifier).setWaveformLoaded(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          ref
              .read(uploadProvider.notifier)
              .updateTrackField(coverImagePath: filePath);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickReleaseDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _orange,
              surface: _surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
      ref
          .read(uploadProvider.notifier)
          .updateTrackField(releaseDate: pickedDate);
    }
  }

  void _addTag() {
    final tag = _tagsCtrl.text.trim();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() => _selectedTags.add(tag));
      ref.read(uploadProvider.notifier).updateTrackField(tags: _selectedTags);
      _tagsCtrl.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() => _selectedTags.remove(tag));
    ref.read(uploadProvider.notifier).updateTrackField(tags: _selectedTags);
  }

  void _updateTrackFields() {
    ref.read(uploadProvider.notifier).updateTrackField(
          title: _titleCtrl.text.trim(),
          artist: _artistCtrl.text.trim(),
          album: _albumCtrl.text.trim(),
          genre: _genreCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
        );
  }

  bool _isFormValid() {
    final state = ref.read(uploadProvider);
    return state.track.audioFilePath != null &&
        state.track.title.isNotEmpty &&
        state.track.artist.isNotEmpty;
  }

  void _submitUpload() {
    _updateTrackFields();

    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please fill in all required fields and select an audio file'),
          backgroundColor: _orange,
        ),
      );
      return;
    }

    // Navigate to progress page immediately, then start simulation in background
    context.push('/upload/progress');
    ref.read(uploadProvider.notifier).simulateUpload();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Upload Track',
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
            // ── AUDIO FILE SELECTION ────────────────────────────────
            _buildSectionTitle('Select Audio File'),
            const SizedBox(height: 12),
            _buildAudioSelectionArea(),
            const SizedBox(height: 24),

            // ── WAVEFORM PREVIEW ────────────────────────────────
            if (uploadState.track.audioFilePath != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Waveform Preview'),
                  const SizedBox(height: 12),
                  _buildWaveformPreview(),
                  const SizedBox(height: 24),
                ],
              ),

            // ── COVER IMAGE ─────────────────────────────────
            _buildSectionTitle('Cover Image (Optional)'),
            const SizedBox(height: 12),
            _buildCoverImageArea(),
            const SizedBox(height: 24),

            // ── METADATA INPUT ───────────────────────────────
            _buildSectionTitle('Track Details'),
            const SizedBox(height: 12),
            _buildMetadataInput(),
            const SizedBox(height: 24),

            // ── GENRE & DESCRIPTION ──────────────────────────
            _buildSectionTitle('Additional Info'),
            const SizedBox(height: 12),
            _buildAdditionalInfo(),
            const SizedBox(height: 24),

            // ── TAGS INPUT ───────────────────────────────
            _buildSectionTitle('Tags'),
            const SizedBox(height: 12),
            _buildTagsInput(),
            const SizedBox(height: 24),

            // ── RELEASE DATE ─────────────────────────────
            _buildSectionTitle('Release Date'),
            const SizedBox(height: 12),
            _buildReleaseDate(),
            const SizedBox(height: 24),

            // ── PUBLIC/PRIVATE TOGGLE ───────────────────
            _buildSectionTitle('Privacy'),
            const SizedBox(height: 12),
            _buildPrivacyToggle(),
            const SizedBox(height: 32),

            // ── SUBMIT BUTTON ────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: uploadState.isUploading ? null : _submitUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: uploadState.isUploading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Upload Track',
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

  Widget _buildAudioSelectionArea() {
    final uploadState = ref.watch(uploadProvider);
    final hasAudio = uploadState.track.audioFilePath != null;

    return GestureDetector(
      onTap: _pickAudioFile,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasAudio ? _orange : _divider,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.audio_file,
              size: 48,
              color: hasAudio ? _orange : _textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              hasAudio
                  ? 'Audio: ${uploadState.track.audioFilePath?.split('/').last ?? 'file selected'}'
                  : 'Tap to select audio file',
              style: TextStyle(
                color: hasAudio ? Colors.white : _textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Placeholder waveform visualization
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  20,
                  (index) => Container(
                    width: 2,
                    height: 20 + (index % 5) * 10.0,
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Waveform Preview',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImageArea() {
    final uploadState = ref.watch(uploadProvider);
    final hasImage = uploadState.track.coverImagePath != null;

    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 40,
              color: hasImage ? _orange : _textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              hasImage ? 'Cover image selected' : 'Tap to select cover image',
              style: TextStyle(
                color: hasImage ? Colors.white : _textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataInput() {
    return Column(
      children: [
        _buildTextField(
          controller: _titleCtrl,
          label: 'Track Title *',
          onChanged: (_) => _updateTrackFields(),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _artistCtrl,
          label: 'Artist Name *',
          onChanged: (_) => _updateTrackFields(),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _albumCtrl,
          label: 'Album (Optional)',
          onChanged: (_) => _updateTrackFields(),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo() {
    return Column(
      children: [
        _buildTextField(
          controller: _genreCtrl,
          label: 'Genre (Optional)',
          onChanged: (_) => _updateTrackFields(),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _descriptionCtrl,
          label: 'Description (Optional)',
          maxLines: 4,
          onChanged: (_) => _updateTrackFields(),
        ),
      ],
    );
  }

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _tagsCtrl,
                label: 'Add tags',
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _addTag,
                  borderRadius: BorderRadius.circular(8),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedTags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _removeTag(tag),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildReleaseDate() {
    return GestureDetector(
      onTap: _pickReleaseDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate != null
                  ? DateFormat('MMM d, y').format(_selectedDate!)
                  : 'Select release date',
              style: TextStyle(
                color: _selectedDate != null ? Colors.white : _textSecondary,
                fontSize: 14,
              ),
            ),
            Icon(Icons.calendar_today, color: _textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyToggle() {
    final uploadState = ref.watch(uploadProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Make track public',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                uploadState.track.isPublic
                    ? 'Anyone can listen'
                    : 'Only you can listen',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
          Transform.scale(
            scale: 1.2,
            child: Switch(
              value: uploadState.track.isPublic,
              onChanged: (value) {
                ref
                    .read(uploadProvider.notifier)
                    .updateTrackField(isPublic: value);
              },
              activeThumbColor: _orange,
              inactiveThumbColor: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
