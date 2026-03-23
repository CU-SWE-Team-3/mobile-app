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
// ignore: library_prefixes
import 'package:soundcloud_clone/core/router/app_router.dart' as from_app_router;

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';

// ─────────────────────────────────────────────────────────────────
// MockHttpClientAdapter for Module 2
//
// Covers:
//   POST /auth/login          → success (200)
//   GET  /users/:permalink    → profile data
//   PUT  /users/me            → profile update success (200)
//   PUT  /users/me            → profile update failure (500)
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

    _respond(Object body, [int status = 200]) => ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    // ── Auth login ────────────────────────────────────────────────
    if (path.endsWith('/auth/login') && method == 'POST') {
      return _respond({
        'user': {
          '_id': 'test_user_id',
          'displayName': validName,
          'role': 'user',
          'permalink': 'e2etester',
        },
      });
    }

    // ── Profile fetch ─────────────────────────────────────────────
    if ((path.contains('/users/') || path.contains('/users/me')) &&
        method == 'GET') {
      return _respond({
        'data': {
          '_id': 'test_user_id',
          'displayName': validName,
          'city': 'Cairo',
          'country': 'Egypt',
          'bio': 'Test bio',
          'permalink': 'e2etester',
          'role': 'user',
          'avatarUrl': '',
        },
      });
    }

    // ── Profile update ────────────────────────────────────────────
    if (path.contains('/users/me') && method == 'PUT') {
      if (simulateSaveError) {
        return _respond({'error': 'Server error'}, 500);
      }
      return _respond({'message': 'Profile updated successfully'});
    }

    // ── Safe fallback ─────────────────────────────────────────────
    return _respond({});
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

  // ── Boot, inject mock, and login ──────────────────────────────
  Future<void> bootAndLogin(
    WidgetTester tester,
    MockHttpClientAdapter adapter,
  ) async {
    app.main();
    // FIX: Set mock adapter immediately after app.main() so
    //      dioClient is already initialised.
    dioClient.dio.httpClientAdapter = adapter;
    await Future.delayed(const Duration(seconds: 2));

    const maxAttempts = 40;
    for (var i = 0; i < maxAttempts; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final onStart =
          find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty;
      if (onStart) break;
      await Future.delayed(const Duration(milliseconds: 250));
    }

    await loginAs(tester, validEmail, validPassword);
  }

  // ── Navigate to Edit Profile page ────────────────────────────
  Future<void> navigateToEditProfile(WidgetTester tester) async {
    from_app_router.appRouter.push('/edit-profile');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Edit Profile page
  // ═══════════════════════════════════════════════════════════════
  group('Edit profile page', () {

    testWidgets('should show Edit profile title in app bar', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('should show Display Name field', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Display Name'), findsOneWidget);
    });

    testWidgets('should show City field', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('City'), findsOneWidget);
    });

    testWidgets('should show Country picker row', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Country'), findsOneWidget);
    });

    testWidgets('should show Save button', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should show Profile updated snackbar on successful save',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – make a change to enable Save, then tap it
      await tester.enterText(
        find.widgetWithText(TextField, 'Display Name'),
        'New Name',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert – success snackbar appears
      expect(find.text('Profile updated!'), findsOneWidget);
    });

    testWidgets('should show discard dialog when back tapped with unsaved changes',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – make a change, then tap back
      await tester.enterText(
        find.widgetWithText(TextField, 'Display Name'),
        'Unsaved Change',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert – discard dialog appears
      expect(find.text('Are you sure?'), findsOneWidget);
    });

    testWidgets('should show DISCARD CHANGES button in dialog', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – trigger discard dialog
      await tester.enterText(
        find.widgetWithText(TextField, 'Display Name'),
        'Unsaved Change',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('DISCARD CHANGES'), findsOneWidget);
    });

    testWidgets('should show CONTINUE EDITING button in dialog', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – trigger discard dialog
      await tester.enterText(
        find.widgetWithText(TextField, 'Display Name'),
        'Unsaved Change',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('CONTINUE EDITING'), findsOneWidget);
    });

    testWidgets('should dismiss dialog and stay on page when CONTINUE EDITING tapped',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act
      await tester.enterText(
        find.widgetWithText(TextField, 'Display Name'),
        'Unsaved Change',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE EDITING'));
      await tester.pumpAndSettle();

      // Assert – dialog gone, still on edit profile page
      expect(find.text('Are you sure?'), findsNothing);
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('should navigate away when DISCARD CHANGES tapped', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act
      await tester.enterText(
        find.widgetWithText(TextField, 'Display Name'),
        'Unsaved Change',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DISCARD CHANGES'));
      await tester.pumpAndSettle();

      // Assert – edit profile page is gone
      expect(find.text('Edit profile'), findsNothing);
    });

    testWidgets('should open bio bottom sheet when bio area tapped', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act – tap the bio placeholder
      await tester.tap(find.text('Add a bio'));
      await tester.pumpAndSettle();

      // Assert – bio sheet confirms button appears
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('should show country list containing Egypt when Country tapped',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      await navigateToEditProfile(tester);

      // Act
      await tester.tap(find.text('Country'));
      await tester.pumpAndSettle();

      // Assert – Egypt is in the country picker list
      expect(find.text('Egypt'), findsOneWidget);
    });

  });
}
