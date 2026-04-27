import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../widgets/recaptcha_webview.dart';

class RegisterPage extends StatefulWidget {
  final String email;
  const RegisterPage({super.key, required this.email});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _displayNameController = TextEditingController();
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

  final _dio = dioClient.dio;

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  final List<String> _days = List.generate(31, (i) => '${i + 1}');
  final List<String> _years = List.generate(100, (i) => '${2019 - i}');
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say'
  ];

  @override
  void dispose() {
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isDisplayNameValid(String name) {
    final trimmed = name.trim();
    return trimmed.length >= 2 && trimmed.length <= 25;
  }

  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[a-zA-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'))) return false;
    return true;
  }

  Future<void> _onContinue() async {
    setState(() => _attempted = true);

    final nameValid = _isDisplayNameValid(_displayNameController.text);
    final passwordValid = _isPasswordValid(_passwordController.text);
    final passwordsMatch =
        _passwordController.text == _confirmPasswordController.text;
    final dobComplete =
        _selectedMonth != null && _selectedDay != null && _selectedYear != null;
    final genderSelected = _selectedGender != null;

    if (!nameValid ||
        !passwordValid ||
        !passwordsMatch ||
        _confirmPasswordController.text.isEmpty ||
        !dobComplete ||
        !genderSelected) {
      return;
    }

    // Show reCAPTCHA sheet and wait for token
    final token = await showRecaptchaBottomSheet(context);
    if (token == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final age = DateTime.now().year - int.parse(_selectedYear!);
      await _dio.post('/auth/register', data: {
        'email': widget.email,
        'password': _passwordController.text.trim(),
        'displayName': _displayNameController.text.trim(),
        'age': age,
        'gender': _selectedGender,
        'captchaToken': token,
      });

      if (mounted) context.go('/email-verification', extra: widget.email);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final errorMessage = e.response?.data['error'] ?? '';

      if (status == 400 && errorMessage.toString().contains('already registered')) {
        if (mounted) context.push('/login', extra: widget.email);
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
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
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
    final passwordInvalid =
        _attempted && !_isPasswordValid(_passwordController.text);
    final confirmInvalid = _attempted &&
        (_confirmPasswordController.text.isEmpty ||
            _passwordController.text != _confirmPasswordController.text);
    final monthInvalid = _attempted && _selectedMonth == null;
    final dayInvalid = _attempted && _selectedDay == null;
    final yearInvalid = _attempted && _selectedYear == null;
    final genderInvalid = _attempted && _selectedGender == null;

    final canContinue = !_isLoading &&
        _isPasswordValid(_passwordController.text) &&
        _passwordController.text == _confirmPasswordController.text &&
        _confirmPasswordController.text.isNotEmpty &&
        _isDisplayNameValid(_displayNameController.text) &&
        _selectedMonth != null &&
        _selectedDay != null &&
        _selectedYear != null &&
        _selectedGender != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('auth_register_back_button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Tell us more about you',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display name field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
                border: nameInvalid
                    ? Border.all(color: Colors.red, width: 1.5)
                    : Border.all(color: Colors.transparent),
              ),
              child: TextField(
                key: const ValueKey('auth_display_name_field'),
                controller: _displayNameController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  labelStyle: TextStyle(color: Color(0xFF999999), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            if (nameInvalid)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Display name must be 2–25 characters',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Your display name can be anything you like. Your name\nor artist name are good choices.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Date of birth
            const Text(
              'Date of birth (required)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
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
              'Your date of birth is used to verify your age and is not\nshared publicly.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Gender dropdown
            _buildDropdown(
              hint: 'Gender (required)',
              value: _selectedGender,
              items: _genders,
              showError: genderInvalid,
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 24),

            // Password field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
                border: passwordInvalid
                    ? Border.all(color: Colors.red, width: 1.5)
                    : Border.all(color: Colors.transparent),
              ),
              child: TextField(
                key: const ValueKey('auth_register_password_field'),
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Password (min. 8 chars, letter, number, symbol)',
                  labelStyle:
                      const TextStyle(color: Color(0xFF999999), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: IconButton(
                    key: const ValueKey('auth_register_password_toggle_button'),
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

            // Confirm password field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
                border: confirmInvalid
                    ? Border.all(color: Colors.red, width: 1.5)
                    : Border.all(color: Colors.transparent),
              ),
              child: TextField(
                key: const ValueKey('auth_confirm_password_field'),
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  labelStyle:
                      const TextStyle(color: Color(0xFF999999), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: IconButton(
                    key: const ValueKey('auth_confirm_password_toggle_button'),
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
                child: Text(
                  'Passwords do not match',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),

            // Continue button — tapping opens reCAPTCHA sheet if fields are valid
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                key: const ValueKey('auth_register_submit_button'),
                onPressed: _onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canContinue ? Colors.white : const Color(0xFF3A3A3A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
