import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationPage extends ConsumerWidget {
  const EmailVerificationPage({super.key});

  static const String _displayEmail = 'test@example.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const Center(
                child: Text(
                  _displayEmail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email resent!')),
                        );
                      },
                      child: const Text(
                        'Resend email',
                        style: TextStyle(
                          color: Color(0xFFFF5500),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // TODO: deep link handler — when user taps verification link in email,
              // the app will be re-opened and navigate to /home automatically
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
