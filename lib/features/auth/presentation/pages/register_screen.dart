import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../widgets/recaptcha_webview.dart';

class RegisterScreen extends StatefulWidget {
  final String email;
  const RegisterScreen({super.key, this.email = ''});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _displayNameController = TextEditingController();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedYear;
  String? _selectedGender;
  bool _attempted = false;
  bool _isLoading = false;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final List<String> _days = List.generate(31, (i) => '${i + 1}');
  final List<String> _years = List.generate(100, (i) => '${2010 - i}');
  final List<String> _genders = ['Male', 'Female', 'Custom', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    _displayNameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isDisplayNameValid(String v) {
    final t = v.trim();
    return t.length >= 2 && t.length <= 25;
  }

  bool _isPasswordValid(String v) {
    if (v.length < 8) return false;
    if (!v.contains(RegExp(r'[a-zA-Z]'))) return false;
    if (!v.contains(RegExp(r'[0-9]'))) return false;
    if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'))) return false;
    return true;
  }

  bool get _canContinue =>
      !_isLoading &&
      _isDisplayNameValid(_displayNameController.text) &&
      _emailController.text.trim().isNotEmpty &&
      _isPasswordValid(_passwordController.text) &&
      _passwordController.text == _confirmPasswordController.text &&
      _confirmPasswordController.text.isNotEmpty &&
      _selectedMonth != null &&
      _selectedDay != null &&
      _selectedYear != null &&
      _selectedGender != null;

  Future<void> _onContinue() async {
    setState(() => _attempted = true);

    if (!_canContinue) return;

    final token = await showRecaptchaBottomSheet(context);
    if (token == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final age = DateTime.now().year - int.parse(_selectedYear!);
      await dioClient.dio.post('/auth/register', data: {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'displayName': _displayNameController.text.trim(),
        'age': age,
        'gender': _selectedGender,
        'captchaToken': token,
      });
      if (mounted) context.go('/email-verification', extra: _emailController.text.trim());
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final errorMessage = e.response?.data['message'] ?? e.response?.data['error'] ?? '';

      if (status == 400 &&
          errorMessage.toString().contains('already registered')) {
        if (mounted) context.push('/login-screen', extra: _emailController.text.trim());
        return;
      }

      if (!mounted) return;
      final message = status == 409
          ? 'An account with this email already exists.'
          : 'Something went wrong. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool showError = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(4),
        border: showError
            ? Border.all(color: Colors.red, width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 14)),
          dropdownColor: const Color(0xFF2A2A2A),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameInvalid =
        _attempted && !_isDisplayNameValid(_displayNameController.text);
    final emailInvalid =
        _attempted && _emailController.text.trim().isEmpty;
    final passwordInvalid =
        _attempted && !_isPasswordValid(_passwordController.text);
    final confirmInvalid = _attempted &&
        (_confirmPasswordController.text.isEmpty ||
            _passwordController.text != _confirmPasswordController.text);
    final monthInvalid = _attempted && _selectedMonth == null;
    final dayInvalid = _attempted && _selectedDay == null;
    final yearInvalid = _attempted && _selectedYear == null;
    final genderInvalid = _attempted && _selectedGender == null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          key: const ValueKey('register_screen_back_button'),
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
          'Create your account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
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
            // ── Social buttons ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: const ValueKey('register_screen_facebook_button'),
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
                key: const ValueKey('register_screen_google_button'),
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
                key: const ValueKey('register_screen_apple_button'),
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
            const SizedBox(height: 16),

            // Display name
            _buildTextField(
              controller: _displayNameController,
              label: 'Display name',
              showError: nameInvalid,
            ),
            if (nameInvalid)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Display name must be 2–25 characters',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            const Text(
              'Your display name can be anything you like.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Email
            _buildTextField(
              controller: _emailController,
              label: 'Email address',
              showError: emailInvalid,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),

            // Date of birth
            const Text('Date of birth (required)',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildDropdown(
                    hint: 'Month',
                    value: _selectedMonth,
                    items: _months,
                    showError: monthInvalid,
                    onChanged: (v) => setState(() => _selectedMonth = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildDropdown(
                    hint: 'Day',
                    value: _selectedDay,
                    items: _days,
                    showError: dayInvalid,
                    onChanged: (v) => setState(() => _selectedDay = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: _buildDropdown(
                    hint: 'Year',
                    value: _selectedYear,
                    items: _years,
                    showError: yearInvalid,
                    onChanged: (v) => setState(() => _selectedYear = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your date of birth is used to verify your age.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Gender
            _buildDropdown(
              hint: 'Gender (required)',
              value: _selectedGender,
              items: _genders,
              showError: genderInvalid,
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 24),

            // Password
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
                border: passwordInvalid
                    ? Border.all(color: Colors.red, width: 1.5)
                    : Border.all(color: Colors.transparent),
              ),
              child: TextField(
                key: const ValueKey('register_screen_password_field'),
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Password (min. 8 chars, letter, number, symbol)',
                  labelStyle:
                      const TextStyle(color: Color(0xFF999999), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: IconButton(
                    key: const ValueKey('register_screen_password_toggle_button'),
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFF999999),
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
            ),
            if (_passwordController.text.isNotEmpty &&
                !_isPasswordValid(_passwordController.text))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Must be 8+ characters with a letter, number, and symbol',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),

            // Confirm password
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
                border: confirmInvalid
                    ? Border.all(color: Colors.red, width: 1.5)
                    : Border.all(color: Colors.transparent),
              ),
              child: TextField(
                key: const ValueKey('register_screen_confirm_password_field'),
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  labelStyle:
                      const TextStyle(color: Color(0xFF999999), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: IconButton(
                    key: const ValueKey('register_screen_confirm_password_toggle_button'),
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFF999999),
                    ),
                    onPressed: () => setState(() =>
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),
                ),
              ),
            ),
            if (_confirmPasswordController.text.isNotEmpty &&
                _passwordController.text != _confirmPasswordController.text)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Passwords do not match',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                key: const ValueKey('register_screen_continue_button'),
                onPressed: _onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canContinue ? Colors.white : const Color(0xFF3A3A3A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        'Continue',
                        style: TextStyle(
                          color: _canContinue
                              ? Colors.black
                              : const Color(0xFF666666),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Already have an account?
            Center(
              child: GestureDetector(
                key: const ValueKey('register_screen_login_button'),
                onTap: () => context.push('/login-screen'),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Color(0xFF999999), fontSize: 14),
                    children: [
                      TextSpan(text: 'Already have an account?  '),
                      TextSpan(
                        text: 'Log in',
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool showError = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(4),
        border: showError
            ? Border.all(color: Colors.red, width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(color: Color(0xFF999999), fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
