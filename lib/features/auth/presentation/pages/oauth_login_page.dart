import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';

class OAuthLoginPage extends ConsumerStatefulWidget {
  const OAuthLoginPage({super.key});

  @override
  ConsumerState<OAuthLoginPage> createState() => _OAuthLoginPageState();
}

class _OAuthLoginPageState extends ConsumerState<OAuthLoginPage> {
  bool _isLoading = false;

  // Create GoogleSignIn instance once at class level
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '718123581836-3irovdt2ugmqejp33htbt9i2clpufi4p.apps.googleusercontent.com',
  );

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // ✅ Force account picker every time
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('Unable to get Google ID token');
      }

      final response = await dioClient.dio.post(
        '/auth/google/mobile',
        data: {'idToken': idToken},
      );

      final token = response.data['data']['token'] as String? ?? '';
      final refreshToken = response.data['data']['refreshToken'] as String? ?? '';
      final user = response.data['data']['user'] as Map<String, dynamic>? ?? {};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', token);
      await prefs.setString('refreshToken', refreshToken);
      await prefs.setString('userId', user['_id'] as String? ?? '');
      await prefs.setString('displayName', user['displayName'] as String? ?? '');
      await prefs.setString('role', user['role'] as String? ?? '');
      dioClient.setAuthToken(token);

      if (mounted) {
        context.go('/home');
      }
   } catch (error) {
      if (mounted) {
        String message = 'Google sign-in failed: ${error.toString()}';

        if (error is DioException && error.response?.statusCode == 429) {
          message = 'Too many attempts. Please wait a moment and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Container(
        margin: const EdgeInsets.only(top: 128),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Image.asset('assets/images/soundcloud_logo.png',
                    width: 100, height: 100),
                Container(width: 2, height: 100, color: Colors.white),
                Image.asset('assets/icons/Google_Icon.png',
                    width: 100, height: 100),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 75),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              width: 500,
              height: 75,
              child: const Text(
                'Connect with Google to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  fontFamily: 'modern sans-serif font',
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              width: 500,
              height: 50,
              child: const Text(
                'Tap Continue to use your Google account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  fontFamily: 'modern sans-serif font',
                ),
              ),
            ),
            GestureDetector(
              onTap: _isLoading ? null : _signInWithGoogle,
              child: Container(
                margin: const EdgeInsets.only(top: 35),
                width: 200,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 16,
                            fontFamily: 'modern sans-serif font',
                          ),
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
