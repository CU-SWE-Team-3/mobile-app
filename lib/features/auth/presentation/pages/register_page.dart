import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundcloud_clone/features/auth/presentation/providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _displayNameController = TextEditingController();

  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedYear;
  String? _selectedGender;
  bool _isCaptchaChecked = false;

  late final AnimationController _captchaAnimController;
  late final Animation<double> _captchaScaleAnim;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> _days = List.generate(31, (i) => '${i + 1}');
  final List<String> _years = List.generate(
    100, (i) => '${DateTime.now().year - i}');
  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

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
    _displayNameController.dispose();
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

  Future<void> _onContinue() async {
    if (!_isCaptchaChecked ||
        _displayNameController.text.isEmpty ||
        _selectedMonth == null ||
        _selectedDay == null ||
        _selectedYear == null ||
        _selectedGender == null) return;

    final age = DateTime.now().year - int.parse(_selectedYear!);

    await ref.read(authProvider.notifier).register(
      email: 'temp@email.com',
      password: 'temppassword',
      displayName: _displayNameController.text.trim(),
      age: age,
      gender: _selectedGender,
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 14)),
          dropdownColor: const Color(0xFF2A2A2A),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          isExpanded: width == null,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
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
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (previous?.user == null && next.user != null) {
        context.go('/email-verification');
      }
    });

    final canContinue = _isCaptchaChecked && !authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display name field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                controller: _displayNameController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  labelStyle: TextStyle(color: Color(0xFF999999), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
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

            // Month Day Year dropdowns
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildDropdown(
                    hint: 'Month',
                    value: _selectedMonth,
                    items: _months,
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
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 24),

            // Mock CAPTCHA
            _buildMockCaptcha(),
            const SizedBox(height: 24),

            // Error
            if (authState.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  authState.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),

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
                child: authState.isLoading
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
          ],
        ),
      ),
    );
  }
}
