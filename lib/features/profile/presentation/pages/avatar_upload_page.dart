import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class AvatarUploadPage extends StatefulWidget {
  const AvatarUploadPage({super.key});

  @override
  State<AvatarUploadPage> createState() => _AvatarUploadPageState();
}

class _AvatarUploadPageState extends State<AvatarUploadPage> {
  File? _pickedImage;
  final _picker = ImagePicker();

  static const _bg = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    // Auto-open picker when page loads so user can immediately choose a photo
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  Future<void> _pickImage() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile != null) {
      setState(() => _pickedImage = File(xFile.path));
    } else {
      // User cancelled picker with no existing image → go back
      if (_pickedImage == null && mounted) {
        context.canPop() ? context.pop() : context.go('/profile/edit');
      }
    }
  }

  void _handleClose() {
    context.canPop() ? context.pop() : context.go('/profile/edit');
  }

  void _handleSave() {
    // TODO: dispatch save avatar event with _pickedImage
    context.canPop() ? context.pop() : context.go('/profile/edit');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.78;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── main content ───────────────────────────────────────────
            Column(
              children: [
                // top spacing
                SizedBox(height: size.height * 0.12),

                // circle avatar preview
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _pickedImage != null
                          ? Image.file(
                              _pickedImage!,
                              fit: BoxFit.cover,
                            )
                          : const _PlaceholderAvatar(),
                    ),
                  ),
                ),

                const Spacer(),

                // ── bottom action buttons ──────────────────────────────
                if (_pickedImage != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Row(
                      children: [
                        // Choose different photo
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white38),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Choose photo',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Save
                        Expanded(
                          child: GestureDetector(
                            onTap: _handleSave,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5500),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // No image yet — show a choose button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5500),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Choose photo',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // ── X close button (top-left) ──────────────────────────────
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: _handleClose,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── placeholder when no image selected ──────────────────────────────────
class _PlaceholderAvatar extends StatelessWidget {
  const _PlaceholderAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF6699BB),
      child: const Icon(Icons.person, size: 120, color: Colors.white70),
    );
  }
}