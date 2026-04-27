import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/dio_client.dart';

class CoverPhotoUploadPage extends StatefulWidget {
  const CoverPhotoUploadPage({super.key});

  @override
  State<CoverPhotoUploadPage> createState() => _CoverPhotoUploadPageState();
}

class _CoverPhotoUploadPageState extends State<CoverPhotoUploadPage> {
  File? _pickedImage;
  final _picker = ImagePicker();
  bool _isUploading = false;

  static const Color _bg = Color(0xFF111111);
  static const Color _orange = Color(0xFFFF5500);
  static const Color _grey = Color(0xFF888888);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  Future<void> _pickImage() async {
    final XFile? xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile != null) {
      setState(() => _pickedImage = File(xFile.path));
    } else {
      if (_pickedImage == null && mounted) {
        context.canPop() ? context.pop() : context.go('/profile/edit');
      }
    }
  }

  void _handleClose() {
    context.canPop() ? context.pop() : context.go('/profile/edit');
  }

  Future<void> _handleSave() async {
    if (_pickedImage == null || _isUploading) return;
    setState(() => _isUploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final formData = FormData.fromMap({
        'cover': await MultipartFile.fromFile(
          _pickedImage!.path,
          filename: 'cover.jpg',
        ),
      });
      await dioClient.dio.patch('/profile/upload-images', data: formData);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cover photo updated!'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) context.canPop() ? context.pop() : context.go('/profile/edit');
    } on DioException {
      setState(() => _isUploading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to upload cover photo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('profile_cover_close_button'),
                    onTap: _handleClose,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Cover photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_pickedImage != null)
                    GestureDetector(
                      key: const ValueKey('profile_cover_save_button'),
                      onTap: _isUploading ? null : _handleSave,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: _isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── cover preview ─────────────────────────────────────────
            GestureDetector(
              key: const ValueKey('profile_cover_preview_button'),
              onTap: _pickImage,
              child: SizedBox(
                width: double.infinity,
                height: 200,
                child: _pickedImage != null
                    ? Image.file(
                        _pickedImage!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 200,
                            color: _grey,
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.camera_alt_outlined,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: Colors.white60, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to choose a cover photo',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // ── action buttons ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  GestureDetector(
                    key: const ValueKey('profile_cover_choose_button'),
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _pickedImage != null
                            ? 'Choose different photo'
                            : 'Choose photo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (_pickedImage != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      key: const ValueKey('profile_cover_remove_button'),
                      onTap: () => setState(() => _pickedImage = null),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Remove cover photo',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),  
      ),
    );
  }
}