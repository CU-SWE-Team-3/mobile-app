import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_client.dart';

class LoginScreen extends StatefulWidget {
  final String email;
  const LoginScreen({super.key, this.email = ''});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool get _canContinue =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      !_isLoading;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    setState(() => _isLoading = true);
    try {
      final response = await dioClient.dio.post('/auth/login', data: {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });
      final user = (response.data?['data']?['user'] ?? response.data?['user']) as Map<String, dynamic>?;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Please try again.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user['_id'] as String? ?? '');
      await prefs.setString('displayName', user['displayName'] as String? ?? '');
      await prefs.setString('role', user['role'] as String? ?? '');
      await prefs.setString('permalink', user['permalink'] as String? ?? '');
      // Extract accessToken and refreshToken from Set-Cookie header
      String? refreshToken;
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        for (final cookie in setCookie) {
          if (cookie.startsWith('accessToken=')) {
            final token = cookie.split(';')[0].split('=')[1];
            dioClient.setAuthToken(token);
            await prefs.setString('accessToken', token);
          } else if (cookie.startsWith('refreshToken=')) {
            refreshToken = cookie.split(';')[0].split('=')[1];
            await prefs.setString('refreshToken', refreshToken);
          }
        }
      }
      // Call /auth/refresh to get full user data (including permalink)
      if (refreshToken != null) {
        try {
          final refreshResponse = await dioClient.dio.post('/auth/refresh',
              data: {'refreshToken': refreshToken});
          final fullUser = refreshResponse.data['data']?['user'] as Map<String, dynamic>?;
          if (fullUser != null) {
            await prefs.setString('permalink', fullUser['permalink'] as String? ?? '');
          }
        } catch (_) {}
      }
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final message = status == 401
          ? 'Wrong password. Please try again.'
          : status == 429
              ? 'Too many attempts. Please wait a moment and try again.'
              : 'Something went wrong. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          key: const ValueKey('auth_back_button'),
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Welcome back!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Social buttons ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: const ValueKey('auth_facebook_button'),
                onPressed: () {},
                icon: const Icon(Icons.facebook, color: Colors.white),
                label: const Text('Continue with Facebook',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('auth_google_button'),
                onPressed: () => context.push('/oauth-login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.google.com/favicon.ico',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.g_mobiledata, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text('Continue with Google',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: const ValueKey('auth_apple_button'),
                onPressed: () {},
                icon: const Icon(Icons.apple, color: Colors.white),
                label: const Text('Continue with Apple',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: Color(0xFF444444)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Or with email ─────────────────────────────────────────
            const Text('Or with email',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Email field
            TextField(
              key: const ValueKey('auth_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Email address',
                labelStyle: TextStyle(color: Color(0xFF999999), fontSize: 14),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Password field
            TextField(
              key: const ValueKey('auth_password_field'),
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              cursorColor: Colors.orange,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle:
                    const TextStyle(color: Color(0xFF999999), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                suffixIcon: IconButton(
                  key: const ValueKey('auth_password_toggle_button'),
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: const Color(0xFF999999),
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
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('auth_continue_button'),
                onPressed: _canContinue ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canContinue ? Colors.white : const Color(0xFF888888),
                  disabledBackgroundColor: const Color(0xFF888888),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        'Continue',
                        style: TextStyle(
                          color: _canContinue ? Colors.black : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Forgot password
            GestureDetector(
              key: const ValueKey('auth_forgot_password_button'),
              onTap: () => context.push('/forgot-password'),
              child: const Text(
                'Forgot your password?',
                style: TextStyle(color: Color(0xFF2196F3), fontSize: 14),
              ),
            ),
            const SizedBox(height: 32),

            // Don't have an account?
            Center(
              child: GestureDetector(
                key: const ValueKey('auth_signup_button'),
                onTap: () => context.push('/register-screen'),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Color(0xFF999999), fontSize: 14),
                    children: [
                      TextSpan(text: "Don't have an account?  "),
                      TextSpan(
                        text: 'Sign up',
                        style: TextStyle(
                          color: Color(0xFFFF5500),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Need help
            Center(
              child: GestureDetector(
                key: const ValueKey('auth_help_button'),
                onTap: () => launchUrl(
                  Uri.parse(
                      'https://help.soundcloud.com/hc/en-us/sections/46266771825691'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text(
                  'Need help?',
                  style: TextStyle(color: Color(0xFF2196F3), fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
