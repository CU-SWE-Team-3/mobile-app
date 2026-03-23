import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:soundcloud_clone/main.dart' as app;
import 'package:soundcloud_clone/core/network/dio_client.dart';

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';

// ─────────────────────────────────────────────────────────────────
// MockHttpClientAdapter
//
// FIX 1: Returns 401 when the password does NOT match validPassword.
//         Previously it always returned 200, so the "wrong password"
//         test could never see the error snackbar.
// FIX 2: Safe empty-list responses for all network/follower endpoints
//         so other pages don't throw on startup.
// ─────────────────────────────────────────────────────────────────
class MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final path   = options.path;
    final method = options.method.toUpperCase();

    // ── POST /auth/login ──────────────────────────────────────────
    if (path.endsWith('/auth/login') && method == 'POST') {
      // Arrange
      final body     = options.data as Map<String, dynamic>?;
      final password = body?['password'] as String? ?? '';

      // Act – simulate 401 for wrong password
      if (password != validPassword) {
        return ResponseBody.fromString(
          jsonEncode({'error': 'Wrong password'}),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }

      // Act – simulate 200 for correct password
      return ResponseBody.fromString(
        jsonEncode({
          'user': {
            '_id': 'test_user_id',
            'displayName': validName,
            'role': 'user',
            'permalink': 'e2etester',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // ── Safe empty-list fallback for network/follower endpoints ───
    if (path.contains('/network') ||
        path.contains('/followers') ||
        path.contains('/following') ||
        path.contains('/suggested') ||
        path.contains('/users')) {
      return ResponseBody.fromString(
        jsonEncode({'data': []}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // ── Default safe response for any other endpoint ──────────────
    return ResponseBody.fromString(
      jsonEncode({}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// ─────────────────────────────────────────────────────────────────
// Module 1: Authentication & User Management
// Owner: Omar Walid
// ─────────────────────────────────────────────────────────────────
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Allow GetIt to overwrite dependencies between tests.
  GetIt.instance.allowReassignment = true;

  // ── setUp: reset GetIt before each test ──────────────────────────
  // FIX 3: The mock adapter is set AFTER app.main() inside
  //         waitForStartScreen(), NOT here in setUp.
  //         Previously the adapter was set before app.main() ran,
  //         so dioClient.init() could overwrite it with the real adapter.
  setUp(() async {
    await GetIt.instance.reset();
  });

  // ─────────────────────────────────────────────────────────────────
  // waitForStartScreen
  //
  // Boots the app and waits until the Start page is visible.
  // FIX 3 (continued): mock adapter injected right after app.main()
  //         so dioClient is already initialised when we override it.
  // ─────────────────────────────────────────────────────────────────
  Future<void> waitForStartScreen(WidgetTester tester) async {
    // Arrange – launch app
    app.main();

    // FIX 3: Inject mock adapter immediately after app boots,
    //        before any real HTTP calls can be made.
    dioClient.dio.httpClientAdapter = MockHttpClientAdapter();

    // Allow splash + initialisation to complete.
    await Future.delayed(const Duration(seconds: 2));

    const maxAttempts = 40; // ~20 s total
    for (var i = 0; i < maxAttempts; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final hasLogIn    = find.text('Log in').evaluate().isNotEmpty;
      final hasCreate   = find.text('Create an account').evaluate().isNotEmpty;
      final hasTagline  = find.text('Where artists & fans connect.').evaluate().isNotEmpty;

      if (hasLogIn && hasCreate && hasTagline) return; // ✅ on start page

      // If the app landed on a deeper screen, try to navigate back.
      final onLoginScreen = find.text('Welcome back!').evaluate().isNotEmpty ||
          find.widgetWithText(TextField, 'Email address').evaluate().isNotEmpty;
      final onForgotScreen = find.text('Reset password').evaluate().isNotEmpty;

      if (onLoginScreen || onForgotScreen) {
        if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
        } else if (find.byIcon(Icons.arrow_back_ios).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.arrow_back_ios));
          await tester.pumpAndSettle();
        }
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }

    // Collect visible text for a useful failure message.
    final found = find.byType(Text).evaluate().map((e) {
      final w = e.widget as Text;
      return '"${w.data}"';
    }).join(', ');
    throw Exception('Start screen not visible after 20 s. Found: [$found]');
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Start page
  // ═══════════════════════════════════════════════════════════════
  group('Start page', () {

    testWidgets('should show Log in button', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act – initial load, no action needed

      // Assert
      expect(find.text('Log in'), findsOneWidget);
    });

    testWidgets('should show Create an account button', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act – initial load, no action needed

      // Assert
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('should show tagline text', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act – initial load, no action needed

      // Assert
      expect(find.text('Where artists & fans connect.'), findsOneWidget);
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Login page (LoginScreen — /login-screen)
  // Email + Password are both visible on this single screen.
  // ═══════════════════════════════════════════════════════════════
  group('Login page', () {

    testWidgets('should show Welcome back title after tapping Log in',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Welcome back!'), findsOneWidget);
    });

    testWidgets('should show Email address field', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.widgetWithText(TextField, 'Email address'), findsOneWidget);
    });

    testWidgets('should show Password field', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // Assert
      // FIX 7: The password field label in LoginScreen is 'Password',
      //         not the longer registration label.
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    });

    testWidgets('should show Continue button', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('should show Forgot your password link', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Forgot your password?'), findsOneWidget);
    });

    testWidgets('should show Continue with Google button', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Log in'));
      // FIX 6: Use a longer timeout so the Google favicon network call
      //        does not cause pumpAndSettle to hang indefinitely.
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Assert
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('should show Continue with Facebook button', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Assert
      expect(find.text('Continue with Facebook'), findsOneWidget);
    });

    testWidgets('should show Or with email section', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Or with email'), findsOneWidget);
    });

    testWidgets('should show error snackbar for wrong password', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act – FIX 2: mock now returns 401 for any password != validPassword,
      //              so the app shows the 'Wrong password' snackbar.
      await loginAs(tester, validEmail, 'WrongPass999!');

      // Assert – snackbar must be visible after the failed login attempt
      expect(find.text('Wrong password. Please try again.'), findsOneWidget);
    });

    testWidgets('should navigate to home on successful login', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await loginAs(tester, validEmail, validPassword);

      // Assert – FIX 3: after a successful login the app navigates to /home.
      //          Verify we left the login screen by checking the
      //          login-specific title is gone AND the bottom nav is present.
      expect(find.text('Welcome back!'), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('should navigate to forgot password when link tapped',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();

      // Assert – we left the login screen
      expect(find.text('Welcome back!'), findsNothing);
    });

    testWidgets('should navigate back to start when back button tapped',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert – back on start page
      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Registration page (RegisterScreen — /register-screen)
  //
  // FIX 4 & FIX 5: RegisterScreen shows ALL fields on ONE page.
  //   There is no intermediate "Continue after email" step that
  //   leads to a second page. The original tests tried to:
  //     1. Enter only the email
  //     2. Tap Continue (which does nothing — _canContinue is false)
  //     3. Expect 'Tell us more about you' to appear
  //   That flow was wrong. The tests below test the actual single-page
  //   form that RegisterScreen renders.
  // ═══════════════════════════════════════════════════════════════
  group('Registration page', () {

    testWidgets('should navigate away from start page when Create an account tapped',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Assert – start tagline is gone
      expect(find.text('Where artists & fans connect.'), findsNothing);
    });

    testWidgets('should show Display name field on registration form',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.widgetWithText(TextField, 'Display name'), findsOneWidget);
    });

    testWidgets('should show Date of birth section on registration form',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Date of birth (required)'), findsOneWidget);
    });

    testWidgets('should show password field on registration form', (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.widgetWithText(
            TextField, 'Password (min. 8 chars, letter, number, symbol)'),
        findsOneWidget,
      );
    });

    testWidgets('should show Confirm password field on registration form',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);

      // Act
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.widgetWithText(TextField, 'Confirm password'),
        findsOneWidget,
      );
    });

    testWidgets('should show error for password shorter than 8 characters',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Act – type a password that is too short
      await tester.enterText(
        find.widgetWithText(
            TextField, 'Password (min. 8 chars, letter, number, symbol)'),
        '123',
      );
      await tester.pumpAndSettle();

      // Assert – inline validation error appears immediately
      expect(
        find.text('Must be 8+ characters with a letter, number, and symbol'),
        findsOneWidget,
      );
    });

    testWidgets('should show Passwords do not match error', (tester) async {
      // Arrange
      await waitForStartScreen(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Act – enter valid password then a different confirm password
      await tester.enterText(
        find.widgetWithText(
            TextField, 'Password (min. 8 chars, letter, number, symbol)'),
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

    testWidgets('should show display name length error for name under 2 chars',
        (tester) async {
      // Arrange
      await waitForStartScreen(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Act – enter a 1-character display name and attempt to submit
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'A',
      );
      // Tap Continue to trigger the _attempted flag so validators run
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Display name must be 2–25 characters'), findsOneWidget);
    });

  });
}
