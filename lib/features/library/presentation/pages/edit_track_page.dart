import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/upload_provider.dart';

class EditTrackPage extends ConsumerStatefulWidget {
  const EditTrackPage({super.key});

  @override
  ConsumerState<EditTrackPage> createState() => _EditTrackPageState();
}

class _EditTrackPageState extends ConsumerState<EditTrackPage> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagInputController;

  List<String> _selectedTags = [];
  String? _selectedGenre;
  bool _isScheduleEnabled = false;
  DateTime? _scheduleDate;
  TimeOfDay? _scheduleTime;

  static const List<String> _genreList = [
    'All Music Genres',
    'Alternative Rock',
    'Ambient',
    'Classical',
    'Country',
    'Dance & EDM',
    'Deep House',
    'Drum & Bass',
    'Electronic',
    'Hip-hop & Rap',
    'House',
    'Indie',
    'Jazz & Blues',
    'Latin',
    'Metal',
    'Pop',
    'R&B & Soul',
    'Reggae',
    'Rock',
    'Soundtrack',
    'Techno',
    'Trance',
    'Trap',
    'Arabic',
    'Islamic',
  ];

  @override
  void initState() {
    super.initState();
    final uploadState = ref.read(uploadProvider);

    _titleController = TextEditingController(text: uploadState.track.title);
    _artistController = TextEditingController(text: uploadState.track.artist);
    _descriptionController =
        TextEditingController(text: uploadState.track.description ?? '');
    _tagInputController = TextEditingController();

    _selectedTags = List.from(uploadState.track.tags);
    _selectedGenre = uploadState.track.genre;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _descriptionController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  int _getChecklistProgress() {
    int count = 0;
    if (_titleController.text.trim().isNotEmpty) count++;
    if (_selectedGenre != null && _selectedGenre != 'All Music Genres') count++;
    if (_descriptionController.text.trim().isNotEmpty) count++;
    final uploadState = ref.read(uploadProvider);
    if (uploadState.track.coverImagePath != null &&
        uploadState.track.coverImagePath!.isNotEmpty) {
      count++;
    }
    return count;
  }

  Future<void> _pickCoverImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ref.read(uploadProvider.notifier).updateTrackField(
            coverImagePath: image.path,
          );
    }
  }

  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
      });
      _tagInputController.clear();
      ref.read(uploadProvider.notifier).updateTrackField(tags: _selectedTags);
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
    ref.read(uploadProvider.notifier).updateTrackField(tags: _selectedTags);
  }

  void _showGenrePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Genre',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _genreList.length,
                    itemBuilder: (context, index) {
                      final genre = _genreList[index];
                      final isSelected = _selectedGenre == genre;
                      return ListTile(
                        title: Text(
                          genre,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF1A7A6E))
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedGenre =
                                genre == 'All Music Genres' ? null : genre;
                          });
                          ref.read(uploadProvider.notifier).updateTrackField(
                                genre: _selectedGenre,
                              );
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    if (!_isScheduleEnabled) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduleDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1A7A6E),
              surface: Color(0xFF2A2A2A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _scheduleDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    if (!_isScheduleEnabled) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduleTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1A7A6E),
              surface: Color(0xFF2A2A2A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _scheduleTime = time;
      });
    }
  }

  void _saveTrack() {
    ref.read(uploadProvider.notifier).updateTrackField(
          title: _titleController.text.trim(),
          artist: _artistController.text.trim(),
          description: _descriptionController.text.trim(),
          genre: _selectedGenre,
          tags: _selectedTags,
          isPublic: ref.read(uploadProvider).track.isPublic,
        );

    // Navigate back to library uploads page
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Amplify Promo Card
            _buildAmplifyCard(),

            const SizedBox(height: 20),

            // Track Info Checklist Card
            _buildChecklistCard(uploadState),

            const SizedBox(height: 20),

            // Artwork + File Row
            _buildArtworkFileRow(uploadState),

            const SizedBox(height: 20),

            // Form Card
            _buildFormCard(),

            const SizedBox(height: 20),

            // Genre Section
            _buildGenreSection(),

            const SizedBox(height: 20),

            // Tags Section
            _buildTagsSection(),

            const SizedBox(height: 20),

            // Description Section
            _buildDescriptionSection(),

            const SizedBox(height: 20),

            // Privacy Section
            _buildPrivacySection(uploadState),

            const SizedBox(height: 20),

            // Schedule Promo Card
            _buildSchedulePromoCard(),

            const SizedBox(height: 20),

            // Schedule Section
            _buildScheduleSection(),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  Widget _buildAmplifyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF9B3FFF), Color(0xFF7030A0)],
              ),
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Get your track analyzed and recommended to the right audience.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Amplify with Artist Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(UploadState uploadState) {
    final progress = _getChecklistProgress();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Track info checklist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fans play more when your track info is complete. Tap to learn more.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress / 4,
                  backgroundColor: const Color(0xFF3A3A3C),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF9B3FFF)),
                  strokeWidth: 3,
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$progress',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '/4',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkFileRow(UploadState uploadState) {
    final filename =
        uploadState.track.audioFilePath?.split('/').last ?? 'No file selected';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: uploadState.track.coverImagePath != null
                ? Image.file(
                    File(uploadState.track.coverImagePath!),
                    fit: BoxFit.cover,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.graphic_eq,
                        color: Colors.white.withOpacity(0.5),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File name',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filename,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text(
                  'Replace file',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildFormField(
            label: 'Title',
            isRequired: true,
            controller: _titleController,
            maxLines: 3,
          ),
          Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
          _buildFormField(
            label: 'Track link',
            isReadOnly: true,
            initialValue: 'https://soundcloud.com/[artist-slug]',
          ),
          Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
          _buildFormField(
            label: 'Artist',
            isRequired: true,
            controller: _artistController,
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    bool isRequired = false,
    TextEditingController? controller,
    String? initialValue,
    bool isReadOnly = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            readOnly: isReadOnly,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: isReadOnly ? initialValue : null,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genre',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildGenreChip(
                label: 'PICK GENRE',
                icon: Icons.search,
                onTap: _showGenrePicker,
              ),
              const SizedBox(width: 8),
              _buildGenreChip(
                label: _selectedGenre?.toUpperCase() ?? 'ALL MUSIC GENRES',
                isSelected: true,
                onTap: () {},
              ),
              if (_selectedGenre != null) const SizedBox(width: 8),
              if (_selectedGenre != null)
                _buildGenreChip(
                  label: 'ALTERNATIVE',
                  onTap: () {
                    setState(() => _selectedGenre = 'Alternative Rock');
                    ref.read(uploadProvider.notifier).updateTrackField(
                          genre: 'Alternative Rock',
                        );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenreChip({
    required String label,
    IconData? icon,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedTags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeTag(tag),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagInputController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: 'Add tags to describe track for reachability',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addTag,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5500),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Description',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${4000 - _descriptionController.text.length}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
            ),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 5,
            maxLength: 4000,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: 'Add a description...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(UploadState uploadState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        _buildPrivacyOption(
          title: 'Public',
          subtitle: 'Anyone can find this',
          isSelected: uploadState.track.isPublic,
          onTap: () {
            ref.read(uploadProvider.notifier).updateTrackField(isPublic: true);
          },
        ),
        const SizedBox(height: 16),
        _buildPrivacyOption(
          title: 'Unlisted (Private)',
          subtitle: 'Anyone with private link can access',
          isSelected: !uploadState.track.isPublic,
          onTap: () {
            ref.read(uploadProvider.notifier).updateTrackField(isPublic: false);
          },
        ),
      ],
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.8),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePromoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1A7A6E),
            ),
            child: const Icon(Icons.schedule, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Schedule your release with Artist Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set date and time to make your track public.',
                    style: TextStyle(
                      color: _isScheduleEnabled
                          ? Colors.white
                          : const Color(0xFF636366),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your track stays private until release.',
                    style: TextStyle(
                      color: _isScheduleEnabled
                          ? Colors.white.withOpacity(0.5)
                          : const Color(0xFF48484A),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () =>
                  setState(() => _isScheduleEnabled = !_isScheduleEnabled),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 50,
                height: 28,
                decoration: BoxDecoration(
                  color: _isScheduleEnabled
                      ? const Color(0xFFFF5500)
                      : const Color(0xFF3A3A3C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Align(
                  alignment: _isScheduleEnabled
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _scheduleDate != null
                        ? '${_scheduleDate!.day} ${[
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec'
                          ][_scheduleDate!.month - 1]} ${_scheduleDate!.year}'
                        : '21 Mar 2026',
                    style: TextStyle(
                      color: _isScheduleEnabled
                          ? Colors.white
                          : const Color(0xFF636366),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _scheduleTime != null
                        ? '${_scheduleTime!.hour.toString().padLeft(2, '0')}:${_scheduleTime!.minute.toString().padLeft(2, '0')}'
                        : '12:00',
                    style: TextStyle(
                      color: _isScheduleEnabled
                          ? Colors.white
                          : const Color(0xFF636366),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saveTrack,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Save',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
