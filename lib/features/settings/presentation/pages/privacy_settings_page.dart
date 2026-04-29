import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  bool _isPrivate = false;
  bool _isLoading = true;
  bool _isSaving = false;

  static const _bg = Color(0xFF111111);
  static const _surface = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final permalink = prefs.getString('permalink') ?? '';
      if (permalink.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final response = await dioClient.dio.get('/profile/$permalink');
      final data =
          response.data['data']['user'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _isPrivate = data['isPrivate'] as bool? ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrivacy(bool value) async {
    if (_isSaving) return;
    setState(() {
      _isPrivate = value;
      _isSaving = true;
    });
    try {
      await dioClient.dio.patch(
        '/profile/privacy',
        data: {'isPrivate': value},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings saved'),
            backgroundColor: Color(0xFF333333),
          ),
        );
      }
    } on DioException catch (e) {
      // Roll back toggle on failure
      if (mounted) {
        setState(() => _isPrivate = !value);
        final msg = e.response?.statusCode == 401
            ? 'Not authorised. Please sign in again.'
            : 'Failed to save. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Privacy',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5500)),
            )
          : ListView(
              children: [
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Private account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Only your approved followers can see your tracks and likes.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF5500),
                                  strokeWidth: 2,
                                ),
                              )
                            : Switch(
                                value: _isPrivate,
                                onChanged: _savePrivacy,
                                activeThumbColor: const Color(0xFFFF5500),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
