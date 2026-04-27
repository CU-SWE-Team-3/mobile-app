import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';

enum _Status { loading, success, error }

class ConfirmEmailUpdatePage extends StatefulWidget {
  final String token;
  const ConfirmEmailUpdatePage({super.key, required this.token});

  @override
  State<ConfirmEmailUpdatePage> createState() =>
      _ConfirmEmailUpdatePageState();
}

class _ConfirmEmailUpdatePageState extends State<ConfirmEmailUpdatePage> {
  _Status _status = _Status.loading;
  String _errorMessage = 'Invalid or expired link.';

  @override
  void initState() {
    super.initState();
    _confirm();
  }

  Future<void> _confirm() async {
    try {
      await dioClient.dio.post('/auth/confirm-email-update',
          data: {'token': widget.token});
      if (mounted) setState(() => _status = _Status.success);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Invalid or expired link.';
      if (mounted) {
        setState(() {
          _status = _Status.error;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_status) {
      case _Status.loading:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF5500)),
            SizedBox(height: 24),
            Text(
              'Updating your email...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        );

      case _Status.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
              child:
                  const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Email Successfully Updated',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your email address has been updated.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('auth_email_update_success_profile_button'),
                onPressed: () => context.go('/profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text(
                  'Go to Profile',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );

      case _Status.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child:
                  const Icon(Icons.close, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Update Failed',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('auth_email_update_error_profile_button'),
                onPressed: () => context.go('/profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text(
                  'Go to Profile',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
    }
  }
}
