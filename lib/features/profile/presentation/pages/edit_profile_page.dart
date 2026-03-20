import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';

class EditProfilePage extends StatefulWidget {
  // Initial values passed from ProfilePage via route extra
  final Map<String, String>? initialData;

  const EditProfilePage({super.key, this.initialData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // ── initial values (from ProfilePage) ────────────────────────────────
  late String _initUsername;
  late String _initCity;
  late String _initCountry;
  late String _initBio;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;

  String _country = '';
  String _bio = '';
  bool _isLoading = false;

  // ── colors ──────────────────────────────────────────────────────────
  static const _bg = Color(0xFF111111);
  static const _orange = Color(0xFFFF5500);
  static final _sub = Colors.white.withOpacity(0.55);
  static final _dividerColor = Colors.white.withOpacity(0.12);

  // ── dirty check ──────────────────────────────────────────────────────
  bool get _isDirty =>
      _nameCtrl.text != _initUsername ||
      _cityCtrl.text != _initCity ||
      _country != _initCountry ||
      _bio != _initBio;

  @override
  void initState() {
    super.initState();
    // Read initial values passed from ProfilePage
    final d = widget.initialData ?? {};
    _initUsername = d['displayName'] ?? 'SUNDER';
    _initCity = d['city'] ?? '';
    _initCountry = d['country'] ?? '';
    _initBio = d['bio'] ?? '';

    _nameCtrl = TextEditingController(text: _initUsername);
    _cityCtrl = TextEditingController(text: _initCity);
    _country = _initCountry;
    _bio = _initBio;

    _nameCtrl.addListener(() => setState(() {}));
    _cityCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  // ── discard dialog ───────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    return await _showDiscardDialog() ?? false;
  }

  Future<bool?> _showDiscardDialog() => showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have unsaved changes that will be lost',
                  style:
                      TextStyle(color: _sub, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 24),
                // DISCARD
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: const Text(
                      'DISCARD CHANGES',
                      style: TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
                Divider(color: _dividerColor, height: 1),
                // CONTINUE EDITING
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: const Text(
                      'CONTINUE EDITING',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );

  // ── save: PATCH /profile/me ───────────────────────────────────────────
  Future<void> _save() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await dioClient.dio.patch('/profile/update', data: {
        'displayName': _nameCtrl.text.trim().isEmpty
            ? _initUsername
            : _nameCtrl.text.trim(),
        'bio': _bio,
        'country': _country,
        'city': _cityCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── country picker ───────────────────────────────────────────────────
  Future<void> _pickCountry() async {
    final countries = [
      'Egypt', 'United States', 'United Kingdom', 'Canada',
      'Germany', 'France', 'Japan', 'Brazil', 'Australia', 'India',
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: countries
            .map((c) => ListTile(
                  title: Text(c,
                      style: const TextStyle(color: Colors.white)),
                  trailing: _country == c
                      ? const Icon(Icons.check, color: _orange)
                      : null,
                  onTap: () => Navigator.pop(context, c),
                ))
            .toList(),
      ),
    );
    if (picked != null) setState(() => _country = picked);
  }

  // ── bio editor ───────────────────────────────────────────────────────
  Future<void> _editBio() async {
    final ctrl = TextEditingController(text: _bio);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Bio',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, ctrl.text),
                  child: const Text('Done',
                      style: TextStyle(color: _orange, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 5,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Tell the world about yourself…',
                hintStyle:
                    const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                counterStyle: TextStyle(color: _sub),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _bio = result);
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final should = await _onWillPop();
        if (should && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _coverAndAvatar(),
                      const SizedBox(height: 24),
                      _fieldSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── top bar ──────────────────────────────────────────────────────────
  Widget _topBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                final should = await _onWillPop();
                if (should && mounted) context.pop();
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 14),
            const Text('Edit profile',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: _isLoading ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30)),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Save',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
              ),
            ),
          ],
        ),
      );

  // ── cover + avatar ───────────────────────────────────────────────────
  Widget _coverAndAvatar() => SizedBox(
        height: 184,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover photo
            GestureDetector(
              onTap: () => context.push('/profile/cover'),
              child: Container(
                height: 140,
                width: double.infinity,
                color: const Color(0xFF888888),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.photo_camera_outlined,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ),
            // Avatar
            Positioned(
              left: 20,
              bottom: 0,
              child: GestureDetector(
                onTap: () => context.push('/profile/avatar'),
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _bg, width: 3)),
                      child: const CircleAvatar(
                        radius: 44,
                        backgroundColor: Color(0xFF6699BB),
                        child: Icon(Icons.person,
                            size: 52, color: Colors.white70),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.35)),
                        child: const Icon(Icons.photo_camera_outlined,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // ── fields ───────────────────────────────────────────────────────────
  Widget _fieldSection() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Display Name
            _inlineField(
                label: 'Display Name',
                controller: _nameCtrl,
                maxLength: 50),
            Divider(color: _dividerColor, height: 1),
            _counter(_nameCtrl.text.length, 50),

            // City
            _inlineField(
                label: 'City', controller: _cityCtrl, maxLength: 35),
            Divider(color: _dividerColor, height: 1),
            _counter(_cityCtrl.text.length, 35),

            // Country
            GestureDetector(
              onTap: _pickCountry,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _country.isEmpty ? 'Country' : _country,
                        style: TextStyle(
                          color:
                              _country.isEmpty ? _sub : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: _sub, size: 22),
                  ],
                ),
              ),
            ),
            Divider(color: _dividerColor, height: 1),

            // Bio
            GestureDetector(
              onTap: _editBio,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bio',
                              style: TextStyle(
                                  color: _sub,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            _bio.isEmpty ? 'Add a bio' : _bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  _bio.isEmpty ? _sub : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: _sub, size: 22),
                  ],
                ),
              ),
            ),
            Divider(color: _dividerColor, height: 1),
            const SizedBox(height: 80),
          ],
        ),
      );

  Widget _inlineField({
    required String label,
    required TextEditingController controller,
    required int maxLength,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: _sub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            TextField(
              controller: controller,
              maxLength: maxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding:
                    EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ],
        ),
      );

  Widget _counter(int current, int max) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text('$current/$max',
              style: TextStyle(color: _sub, fontSize: 12)),
        ),
      );
}