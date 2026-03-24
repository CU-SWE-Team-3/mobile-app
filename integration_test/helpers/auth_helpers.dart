import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────
// Auth Helpers
// loginAs() works on LoginScreen (/login-screen):
//   Email address + Password are both on the SAME page.
// ─────────────────────────────────────────────────────────────────

Future<void> loginAs(
    WidgetTester tester, String email, String password) async {
  // ── Determine current screen ──────────────────────────────────
  final onStartPage =
      find.text('Log in').evaluate().isNotEmpty &&
      find.text('Create an account').evaluate().isNotEmpty;

  final onLoginScreen =
      find.text('Welcome back!').evaluate().isNotEmpty ||
      find.widgetWithText(TextField, 'Email address').evaluate().isNotEmpty;

  final onForgotPasswordScreen =
      find.text('Reset password').evaluate().isNotEmpty;

  // ── If on forgot-password, navigate back first ────────────────
  // FIX 9: ForgotPasswordPage uses Icons.arrow_back_ios_sharp.
  if (onForgotPasswordScreen) {
    if (find.byIcon(Icons.arrow_back_ios_sharp).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.arrow_back_ios_sharp));
    } else if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.arrow_back));
    } else if (find.byIcon(Icons.arrow_back_ios).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.arrow_back_ios));
    }
    await tester.pumpAndSettle();
  }

  // ── Navigate from start page to LoginScreen ───────────────────
  if (onStartPage && !onLoginScreen) {
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
  } else if (!onLoginScreen) {
    throw Exception(
      'loginAs(): expected start page or login screen, but found neither.',
    );
  }

  // ── Fill Email address field ──────────────────────────────────
  await tester.enterText(
    find.widgetWithText(TextField, 'Email address'),
    email,
  );
  await tester.pumpAndSettle();

  // ── Fill Password field ───────────────────────────────────────
  await tester.enterText(
    find.widgetWithText(TextField, 'Password'),
    password,
  );
  await tester.pumpAndSettle();

  // ── Tap Continue ──────────────────────────────────────────────
  await tester.tap(find.text('Continue'));
  // Use a timeout-safe pump to let the async login + navigation settle.
  await tester.pumpAndSettle(const Duration(seconds: 5));
}