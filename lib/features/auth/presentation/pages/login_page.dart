import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';

class LoginPage extends StatefulWidget {
  final String email;
  const LoginPage({super.key, this.email = ''});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _passwordController = TextEditingController();
  bool _isPasswordValid = false;
  bool _isPasswordVisible = false;
  String? _fieldError;
  bool _isLoading = false;

  final _dio = dioClient.dio;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_isPasswordValid || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _dio.post('/auth/login', data: {
        'email': widget.email,
        'password': _passwordController.text.trim(),
      });

      if (mounted) context.go('/home');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final message = status == 401
          ? 'Wrong password. Please try again.'
          : status == 404
              ? 'No account found with this email.'
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
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black12,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 90,
        leadingWidth: 90,
        leading: Padding(
          padding: const EdgeInsets.only(left: 17, top: 30, bottom: 10),
          child: CircleAvatar(
            backgroundColor: Colors.grey[850],
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_sharp, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        backgroundColor: Colors.black12,
        title: const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Text(
            'Welcome back!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.01,
          vertical: screenHeight * 0.01,
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 40, right: 50),
              child: const Text(
                'Your email address or profile URL',
                textAlign: TextAlign.start,
                style: TextStyle(color: Colors.grey, fontSize: 17),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 30, bottom: 35),
              child: Text(
                widget.email.isNotEmpty ? widget.email : 'Enter your email on the previous screen',
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Password field
            SizedBox(
              width: 380,
              child: TextField(
                controller: _passwordController,
                textAlignVertical: TextAlignVertical.top,
                obscureText: !_isPasswordVisible,
                cursorColor: Colors.orange,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      _isPasswordValid = false;
                      _fieldError = null;
                    } else if (value.length < 8) {
                      _isPasswordValid = false;
                      _fieldError = 'Password must contain min 8 characters';
                    } else {
                      _isPasswordValid = true;
                      _fieldError = null;
                    }
                  });
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
                  labelText: 'Your Password (min. 8 characters)',
                  labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  errorText: _fieldError,
                  errorStyle: const TextStyle(color: Colors.white, fontSize: 16),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      size: 30,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  filled: true,
                  fillColor: Colors.white24,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Colors.white54, width: 1.5),
                  ),
                ),
              ),
            ),

            // Continue button
            SizedBox(
              width: 400,
              child: ElevatedButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF888888),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _isPasswordValid && !_isLoading ? _onContinue : null,
                child: Container(
                  height: 55,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: _isPasswordValid ? Colors.white : Colors.grey[400],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            'Continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isPasswordValid ? Colors.black : Colors.grey[700],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // Forgot password
            GestureDetector(
              onTap: () => context.push('/forgot-password'),
              child: Container(
                margin: const EdgeInsets.only(right: 180, top: 20),
                child: const Text(
                  'Forgot your password?',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 18,
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
