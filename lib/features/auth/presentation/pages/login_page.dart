import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isCaptchaChecked = false;

  late final AnimationController _captchaAnimController;
  late final Animation<double> _captchaScaleAnim;

  // Mock — in the real flow this comes from the onboarding/email step
  static const String _displayEmail = 'soundcloud1234567es@gmail.com';

  @override
  void initState() {
    super.initState();
    _captchaAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _captchaScaleAnim = CurvedAnimation(
      parent: _captchaAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _captchaAnimController.dispose();
    super.dispose();
  }

  void _onCaptchaTap() {
    setState(() => _isCaptchaChecked = !_isCaptchaChecked);
    if (_isCaptchaChecked) {
      _captchaAnimController.forward();
    } else {
      _captchaAnimController.reverse();
    }
  }

  void _onContinue() {
    if (!_isCaptchaChecked || _passwordController.text.isEmpty) return;
    // TODO: wire to login use case
  }

  Widget _buildMockCaptcha() {
    return GestureDetector(
      onTap: _onCaptchaTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF3A3A3A)),
        ),
        child: Row(
          children: [
            // Animated checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isCaptchaChecked
                      ? const Color(0xFFFF5500)
                      : const Color(0xFF999999),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: _isCaptchaChecked
                  ? ScaleTransition(
                      scale: _captchaScaleAnim,
                      child: const Icon(
                        Icons.check,
                        color: Color(0xFFFF5500),
                        size: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // "I'm not a robot"
            const Expanded(
              child: Text(
                "I'm not a robot",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),

            // reCAPTCHA branding
            const Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'reCAPTCHA',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Privacy - Terms',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword = _passwordController.text.isNotEmpty;
    final canContinue = _isCaptchaChecked && hasPassword;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + title row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/start'),
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
                      'Welcome back!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Invisible balance widget so title stays centered
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 36),

              // Email display
              const Text(
                'Your email address or profile URL',
                style: TextStyle(color: Color(0xFF999999), fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                _displayEmail,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),

              // Password field
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: !_isPasswordVisible,
                cursorColor: const Color(0xFFFF5500),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Your Password (min. 6 characters)',
                  hintStyle: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF5500),
                      width: 1.5,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF999999),
                      size: 22,
                    ),
                    onPressed: () =>
                        setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              // Forgot password
              GestureDetector(
                onTap: () => context.go('/forgot-password'),
                child: const Text(
                  'Forgot your password?',
                  style: TextStyle(
                    color: Color(0xFF3D7EFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Mock CAPTCHA
              _buildMockCaptcha(),
            ],
          ),
        ),
      ),
    );
  }
}
