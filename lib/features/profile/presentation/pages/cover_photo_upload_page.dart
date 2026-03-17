import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class CoverPhotoUploadPage extends StatefulWidget {
  const CoverPhotoUploadPage({super.key});

  @override
  State<CoverPhotoUploadPage> createState() => _CoverPhotoUploadPageState();
}

class _CoverPhotoUploadPageState extends State<CoverPhotoUploadPage> {
  File? _pickedImage;
  final _picker = ImagePicker();

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

  void _handleSave() {
    // TODO: dispatch save cover photo event with _pickedImage
    context.canPop() ? context.pop() : context.go('/profile/edit');
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
                      onTap: _handleSave,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
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