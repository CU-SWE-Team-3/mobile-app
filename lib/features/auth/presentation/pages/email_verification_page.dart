import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isResending = false;
  bool _isVerifying = false;
  bool _showTokenField = false;
  final _tokenController = TextEditingController();
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _tokenController.dispose();
    super.dispose();
  }

  // Extracts the token whether the user pastes the full URL or just the token
  String _extractToken(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri != null && uri.queryParameters.containsKey('token')) {
      return uri.queryParameters['token']!;
    }
    return input.trim();
  }

  Future<void> _onVerify() async {
    final token = _extractToken(_tokenController.text);
    if (token.isEmpty) return;
    setState(() => _isVerifying = true);
    try {
      await dioClient.dio.post('/auth/verify-email', data: {'token': token});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified! Please log in.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login-screen');
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['message'] as String? ??
            'Invalid or expired token.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _onResend() async {
    if (_isResending || _cooldown > 0) return;

    setState(() => _isResending = true);
    try {
      await dioClient.dio.post(
        '/auth/resend-verification',
        data: {'email': widget.email},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent!'),
            backgroundColor: Colors.green,
          ),
        );
        _startCooldown();
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + title
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2A2A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Check your inbox',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),

              const Spacer(),

              // Envelope icon
              const Center(
                child: Icon(
                  Icons.mail_outline,
                  color: Color(0xFFFF5500),
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),

              // Subtitle
              const Center(
                child: Text(
                  'We sent a verification link to',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF999999), fontSize: 15),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Helper text
              const Center(
                child: Text(
                  'Click the link in the email to verify your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              // Resend row
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Didn't receive an email?  ",
                      style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: _onResend,
                      child: _isResending
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFFFF5500),
                              ),
                            )
                          : Text(
                              _cooldown > 0
                                  ? 'Resend email ($_cooldown s)'
                                  : 'Resend email',
                              style: TextStyle(
                                color: _cooldown > 0
                                    ? const Color(0xFF999999)
                                    : const Color(0xFFFF5500),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Manual token entry (copy link from email, paste here)
              GestureDetector(
                onTap: () => setState(() => _showTokenField = !_showTokenField),
                child: const Center(
                  child: Text(
                    "Can't open the link? Paste it here instead",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFF5500),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_showTokenField) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _tokenController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Paste the full link or just the token',
                    hintStyle: const TextStyle(
                        color: Color(0xFF666666), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _onVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5500),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
