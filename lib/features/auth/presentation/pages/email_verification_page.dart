import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends ConsumerState<EmailVerificationPage> {
  static const String _displayEmail = 'test@example.com';
  static const int _otpLength = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (i) {
      final node = FocusNode();
      // Move back to previous box on backspace when current box is empty
      node.onKeyEvent = (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[i].text.isEmpty &&
            i > 0) {
          _focusNodes[i - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
      return node;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  bool get _isOtpComplete =>
      _controllers.every((c) => c.text.isNotEmpty);

  void _onContinue() {
    if (!_isOtpComplete) return;
    // TODO: wire to verifyEmail use case
    context.go('/home');
  }

  Widget _buildOtpBox(int index) {
    return Expanded(
      child: Container(
        height: 56,
        margin: EdgeInsets.only(right: index < _otpLength - 1 ? 8 : 0),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          keyboardType: TextInputType.number,
          maxLength: 1,
          cursorColor: const Color(0xFFFF5500),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF1F1F1F),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFFF5500),
                width: 1.5,
              ),
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < _otpLength - 1) {
              _focusNodes[index + 1].requestFocus();
            }
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _isOtpComplete;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + centered title
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/register'),
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
              const SizedBox(height: 36),

              // Subtitle
              const Text(
                'We sent a verification email to',
                style: TextStyle(color: Color(0xFF999999), fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                _displayEmail,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // OTP boxes
              Row(
                children: List.generate(_otpLength, _buildOtpBox),
              ),
              const SizedBox(height: 20),

              // Resend row
              Row(
                children: [
                  const Text(
                    "Didn't receive an email?  ",
                    style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      // TODO: wire to resend verification use case
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

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: canContinue ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canContinue
                        ? Colors.white
                        : const Color(0xFF3A3A3A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      color: canContinue
                          ? Colors.black
                          : const Color(0xFF666666),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
