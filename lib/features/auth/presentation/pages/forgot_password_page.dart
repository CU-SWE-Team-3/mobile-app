import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      await dioClient.dio.post('/auth/forgot-password', data: {'email': email});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      final message = e.response?.statusCode == 404
          ? 'No account found with this email'
          : 'Something went wrong. Please try again';
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
        backgroundColor: Colors.black12,
        appBar: AppBar(
            centerTitle: true,
            toolbarHeight: 80,
            leadingWidth: 90,
            leading: Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 5),
              child: CircleAvatar(
                backgroundColor: Colors.grey[850],
                child: IconButton(
                  key: const ValueKey('auth_forgot_back_button'),
                  icon: const Icon(Icons.arrow_back_ios_sharp, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            backgroundColor: Colors.black12,
            title: const Padding(
              padding: EdgeInsets.only(top: 23),
              child: Text(
                'Reset password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )),
        body: Column(
          children: [
            SizedBox(
              width: 380,
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                child: TextField(
                  key: const ValueKey('auth_forgot_email_field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: Colors.orange,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                    labelText: 'Your email address',
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                    filled: true,
                    fillColor: Colors.white24,
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
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
            ),
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 20, left: 15, right: 15),
                  child: const Text(
                    'If the email address is in our database, '
                    'we will send you an email to reset your password. Need help?',
                    textAlign: TextAlign.left,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 228),
                  child: Text(
                    'visit our Help Center.',
                    style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('auth_send_reset_link_button'),
                  onTap: _onSendResetLink,
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    width: 380,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'Send reset link',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ));
  }
}
