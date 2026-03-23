import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/main.dart' as app;
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/router/app_router.dart';

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';

// ─────────────────────────────────────────────────────────────────
// MockHttpClientAdapter for Module 2
//
// Key findings from reading edit_profile_page.dart:
//   - Save calls PATCH /profile/update  (NOT PUT /users/me)
//   - Back button uses Icons.arrow_back_ios_new_rounded
//   - No AppBar — custom _topBar() widget inside SafeArea
//   - Bio tap target text is 'Add a bio'
//   - Country row shows text 'Country' when none selected
// ─────────────────────────────────────────────────────────────────
class MockHttpClientAdapter implements HttpClientAdapter {
  bool simulateSaveError;

  MockHttpClientAdapter({this.simulateSaveError = false});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final path   = options.path;
    final method = options.method.toUpperCase();

    ResponseBody respond(Object body, [int status = 200]) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );

    // ── Auth login ────────────────────────────────────────────────
    if (path.endsWith('/auth/login') && method == 'POST') {
      return respond({
        'user': {
          '_id': 'test_user_id',
          'displayName': validName,
          'role': 'user',
          'permalink': 'e2etester',
        },
      });
    }

    // ── Profile save — PATCH /profile/update ─────────────────────
    if (path.contains('/profile/update') && method == 'PATCH') {
      if (simulateSaveError) return respond({'error': 'Server error'}, 500);
      return respond({'message': 'Profile updated successfully'});
    }

    // ── Safe fallback ─────────────────────────────────────────────
    return respond({});
  }

  @override
  void close({bool force = false}) {}
}

// ─────────────────────────────────────────────────────────────────
// Module 2: User Profile & Social Identity
// Owner: Abdelrahman Osama
// ─────────────────────────────────────────────────────────────────
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GetIt.instance.allowReassignment = true;

  setUp(() async {
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  tearDown(() async {
    try {
      appRouter.go('/home');
    } catch (_) {}
  });

  // ── Boot app, inject mock, login ─────────────────────────────
  Future<void> bootAndLogin(
    WidgetTester tester,
    MockHttpClientAdapter adapter,
  ) async {
    app.main();
    dioClient.dio.httpClientAdapter = adapter;
    await Future.delayed(const Duration(seconds: 2));

    const maxAttempts = 40;
    for (var i = 0; i < maxAttempts; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final onStart = find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty;
      if (onStart) break;

      // If a previous test left app on home, navigate back to start
      final onHome = find.byType(BottomNavigationBar).evaluate().isNotEmpty;
      if (onHome) {
        appRouter.go('/start');
        await tester.pumpAndSettle();
        continue;
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }

    await loginAs(tester, validEmail, validPassword);

    // Explicitly write userId so any page reading UserSession works correctly.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', 'test_user_id');
    await prefs.setString('displayName', validName);
  }

  // ── Navigate to edit profile page ────────────────────────────
  // Correct route from app_router.dart: /profile/edit
  Future<void> goToEditProfile(WidgetTester tester) async {
    appRouter.push('/profile/edit');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Edit profile page  (/profile/edit)
  // ═══════════════════════════════════════════════════════════════
  group('Edit profile page', () {

    testWidgets('should show Edit profile title', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('should show Save button', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should show Display Name field label', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Display Name'), findsOneWidget);
    });

    testWidgets('should show City field label', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('City'), findsOneWidget);
    });

    testWidgets('should show Country picker row', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – no action needed

      // Assert — 'Country' is shown as placeholder text when none is selected
      expect(find.text('Country'), findsOneWidget);
    });

    testWidgets('should show Add a bio placeholder', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Add a bio'), findsOneWidget);
    });

    testWidgets('should show Profile updated snackbar on successful save',
        (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – change display name to make the form dirty, then save
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'New Display Name');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert
      expect(find.text('Profile updated!'), findsOneWidget);
    });

    testWidgets('should show Are you sure discard dialog when back tapped with changes',
        (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – make form dirty, then tap back
      // Back button uses Icons.arrow_back_ios_new_rounded (from _topBar widget)
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Unsaved Change');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Are you sure?'), findsOneWidget);
    });

    testWidgets('should show DISCARD CHANGES button in dialog', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – trigger discard dialog
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Unsaved Change');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('DISCARD CHANGES'), findsOneWidget);
    });

    testWidgets('should show CONTINUE EDITING button in dialog', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Unsaved Change');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('CONTINUE EDITING'), findsOneWidget);
    });

    testWidgets('should stay on edit profile after tapping CONTINUE EDITING',
        (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Unsaved Change');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE EDITING'));
      await tester.pumpAndSettle();

      // Assert – dialog gone, still on edit profile
      expect(find.text('Are you sure?'), findsNothing);
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('should navigate away after tapping DISCARD CHANGES', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Unsaved Change');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DISCARD CHANGES'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Edit profile'), findsNothing);
    });

    testWidgets('should open bio bottom sheet when Add a bio tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – 'Add a bio' is the GestureDetector tap target, not a TextField
      await tester.tap(find.text('Add a bio'));
      await tester.pumpAndSettle();

      // Assert – bio sheet shows the Done button
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('should show Egypt in country picker list', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goToEditProfile(tester);

      // Act – tap the Country row to open the bottom sheet picker
      await tester.tap(find.text('Country'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Egypt'), findsOneWidget);
    });

  });
}