import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundcloud_clone/main.dart' as app;

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';

// ─────────────────────────────────────────────────────────────────
// Module 1: Authentication & User Management
// Owner: Omar Walid
// ─────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login page', () {

    testWidgets('should show Welcome back title', (tester) async {
      // Arrange
      app.main();
      await tester.pumpAndSettle();

      // Navigate to login — tap sign in from start page
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Enter email to get to LoginPage
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Welcome back!'), findsOneWidget);
    });

    testWidgets('should show password field', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.widgetWithText(
            TextField, 'Your Password (min. 8 characters)'),
        findsOneWidget,
      );
    });

    testWidgets('should show Forgot your password link', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot your password?'), findsOneWidget);
    });

    testWidgets('should show error for password under 8 characters',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Act — type short password
      await tester.enterText(
        find.widgetWithText(
            TextField, 'Your Password (min. 8 characters)'),
        '1234',
      );
      await tester.pumpAndSettle();

      // Assert — inline error shown
      expect(
        find.text('Password must contain min 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('should show error for wrong password', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, 'WrongPass999!');

      // Assert — snackbar error
      expect(
        find.text('Wrong password. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('should show error for non-existent email', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, 'ghost@nowhere.com', validPassword);

      // Assert
      expect(
        find.text('No account found with this email.'),
        findsOneWidget,
      );
    });

    testWidgets('should login successfully with valid credentials',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);

      // Assert — home page visible after login
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Welcome back!'), findsNothing);
    });

    testWidgets('should navigate to forgot password page', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();

      // Assert — no longer on login page
      expect(find.text('Welcome back!'), findsNothing);
    });

  });

  group('Registration page', () {

    testWidgets('should show Tell us more about you title', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to register
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Tell us more about you'), findsOneWidget);
    });

    testWidgets('should show Display name field', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'Display name'),
        findsOneWidget,
      );
    });

    testWidgets('should show Date of birth section', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Date of birth (required)'), findsOneWidget);
    });

    testWidgets('should show password field', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField,
            'Password (min. 8 chars, letter, number, symbol)'),
        findsOneWidget,
      );
    });

    testWidgets('should show error for password under 8 characters',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(
        find.widgetWithText(TextField,
            'Password (min. 8 chars, letter, number, symbol)'),
        '123',
      );
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.text(
            'Must be 8+ characters with a letter, number, and symbol'),
        findsOneWidget,
      );
    });

    testWidgets('should show Passwords do not match error', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Act — fill password and different confirm
      await tester.enterText(
        find.widgetWithText(TextField,
            'Password (min. 8 chars, letter, number, symbol)'),
        validPassword,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'DifferentPass1!',
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('should show display name length error for short name',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first, validEmail);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Act — type 1 char name then submit
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'), 'A');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.text('Display name must be 2–25 characters'),
        findsOneWidget,
      );
    });

  });
}
