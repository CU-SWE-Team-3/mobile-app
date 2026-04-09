import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Stack(
        children: [
          // Abstract art background
          Positioned.fill(
            child: CustomPaint(
              painter: _AbstractArtPainter(),
            ),
          ),

          // Blue bottom sheet with jagged top
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.47,
            child: CustomPaint(
              painter: _BlueSheetPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo black
                    Image.asset(
                      'assets/icons/SoundCloud_Dark_Icon.png',
                      width: 90,
                      //color: Colors.black,
                    ),
                    const SizedBox(height: 16),

                    // Tagline
                    const Text(
                      'Where artists & fans connect.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Create account
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        key: const ValueKey('auth_create_account_button'),
                        onPressed: () => context.push('/register-screen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: const Text(
                          'Create an account',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Log in
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        key: const ValueKey('auth_login_button'),
                        onPressed: () => context.push('/login-screen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDDDDFF),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueSheetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF4353FF);
    final path = Path();

    // Jagged/spiky top edge
    path.moveTo(0, 40);
    path.lineTo(20, 0);
    path.lineTo(50, 30);
    path.lineTo(80, 5);
    path.lineTo(120, 35);
    path.lineTo(160, 8);
    path.lineTo(200, 38);
    path.lineTo(240, 12);
    path.lineTo(280, 40);
    path.lineTo(size.width - 80, 15);
    path.lineTo(size.width - 40, 38);
    path.lineTo(size.width - 10, 10);
    path.lineTo(size.width, 30);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AbstractArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {

    // ── TEAL ARCS (top right corner) ──────────────
    final tealPaint = Paint()
      ..color = const Color(0xFF00D4C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 14; i++) {
      final path = Path();
      final radius = 60.0 + i * 28.0;
      path.addArc(
        Rect.fromCircle(
          center: Offset(size.width, 0),
          radius: radius,
        ),
        math.pi * 0.5,
        math.pi * 0.75,
      );
      canvas.drawPath(path, tealPaint);
    }

    // ── PURPLE LARGE VASE SHAPE (middle) ──────────
    final purplePaint = Paint()
      ..color = const Color(0xFF7744EE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer vase silhouette
    for (int i = 0; i < 5; i++) {
      final offset = i * 12.0;
      final path = Path();
      // Top opening
      path.moveTo(size.width * 0.15 - offset, size.height * 0.08);
      path.lineTo(size.width * 0.75 + offset, size.height * 0.08);
      // Right side curves down
      path.lineTo(size.width * 0.85 + offset, size.height * 0.2);
      path.lineTo(size.width * 0.65 + offset, size.height * 0.35);
      // Bottom right
      path.lineTo(size.width * 0.7 + offset, size.height * 0.5);
      // Bottom
      path.lineTo(size.width * 0.3 - offset, size.height * 0.5);
      // Bottom left
      path.lineTo(size.width * 0.35 - offset, size.height * 0.35);
      // Left side
      path.lineTo(size.width * 0.15 - offset, size.height * 0.2);
      path.close();
      canvas.drawPath(path, purplePaint);
    }

    // ── ORANGE STAIR STEPS (bottom left) ──────────
    final orangePaint = Paint()
      ..color = const Color(0xFFFF5500)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 7; i++) {
      final path = Path();
      final startX = -20.0 + i * 28.0;
      final startY = size.height * 0.62;
      // Each stair goes up and to the right
      path.moveTo(startX, startY);
      path.lineTo(startX + 40, startY - 60 - i * 10);
      path.lineTo(startX + 80, startY - 30 - i * 5);
      path.lineTo(startX + 130, startY - 80 - i * 8);
      canvas.drawPath(path, orangePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
