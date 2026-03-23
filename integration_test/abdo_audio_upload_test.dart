import 'dart:convert';
import 'dart:typed_data';
 
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:soundcloud_clone/main.dart' as app;
import 'package:soundcloud_clone/core/network/dio_client.dart';
// ignore: library_prefixes
import 'package:soundcloud_clone/core/router/app_router.dart' as from_app_router;
 
import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';
 
// ─────────────────────────────────────────────────────────────────
// MockHttpClientAdapter for Module 4
//
// Covers:
//   POST /auth/login     → success (200)
//   POST /tracks         → upload success (201)
//   Safe fallback        → 200 empty JSON
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
 
    // ── Track upload ──────────────────────────────────────────────
    if (path.endsWith('/tracks') && method == 'POST') {
      return _respond({
        'data': {
          '_id': 'track_001',
          'title': 'Test Track',
          'status': 'processing',
        },
      }, 201);
    }
 
    // ── Safe fallback ─────────────────────────────────────────────
    return _respond({});
  }
 
  @override
  void close({bool force = false}) {}
}
 
// ─────────────────────────────────────────────────────────────────
// Module 4: Audio Upload & Track Management
// Owner: Abdelrahman Osama
//
// NOTE on FilePicker:
//   FilePicker opens a native Android dialog that cannot be
//   driven by the Flutter test framework. Any test that requires
//   a file to be selected is marked skip: true for Phase 2.
//   They will be re-enabled in Phase 3 once a FilePicker mock
//   is wired into the DI container.
// ─────────────────────────────────────────────────────────────────
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 
  GetIt.instance.allowReassignment = true;
 
  setUp(() async {
    await GetIt.instance.reset();
  });
 
  // ── Boot, inject mock, and login ──────────────────────────────
  Future<void> bootAndLogin(WidgetTester tester) async {
    app.main();
    // FIX: Inject mock adapter right after app.main() so dioClient
    //      is already initialised and we don't lose the override.
    dioClient.dio.httpClientAdapter = MockHttpClientAdapter();
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
 
  // ── Navigate to Upload page ───────────────────────────────────
  Future<void> navigateToUploadPage(WidgetTester tester) async {
    from_app_router.appRouter.push('/upload');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
 
  // ═══════════════════════════════════════════════════════════════
  // GROUP: Upload page — static UI (no FilePicker interaction)
  // ═══════════════════════════════════════════════════════════════
  group('Upload page — static UI', () {
 
    testWidgets('should show Upload Your Track title', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await navigateToUploadPage(tester);
 
      // Act – no action needed
 
      // Assert
      expect(find.text('Upload Your Track'), findsOneWidget);
    });
 
    testWidgets('should show Choose Audio File button', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await navigateToUploadPage(tester);
 
      // Act – no action needed
 
      // Assert
      expect(find.text('Choose Audio File'), findsOneWidget);
    });
 
    testWidgets('should show description text', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await navigateToUploadPage(tester);
 
      // Act – no action needed
 
      // Assert
      expect(
        find.text(
            'Select an audio file from your device to get started.'),
        findsOneWidget,
      );
    });
 
    testWidgets('should show Cancel button', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await navigateToUploadPage(tester);
 
      // Act – no action needed
 
      // Assert
      expect(find.text('Cancel'), findsOneWidget);
    });
 
    testWidgets('should show upload icon', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await navigateToUploadPage(tester);
 
      // Act – no action needed
 
      // Assert
      expect(find.byIcon(Icons.upload_file), findsOneWidget);
    });
 
    testWidgets('should navigate back when Cancel tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await navigateToUploadPage(tester);
 
      // Act
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
 
      // Assert – upload page is gone
      expect(find.text('Upload Your Track'), findsNothing);
    });
 
    testWidgets('should navigate back when back arrow tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await navigateToUploadPage(tester);
 
      // Act
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
 
      // Assert
      expect(find.text('Upload Your Track'), findsNothing);
    });
 
  });
 
  // ═══════════════════════════════════════════════════════════════
  // GROUP: Upload page — FilePicker interaction
  // All tests in this group are skipped for Phase 2 because
  // FilePicker launches a native Android dialog that cannot be
  // driven by the integration test framework.
  // They will be un-skipped in Phase 3 once a mock is injected.
  // ═══════════════════════════════════════════════════════════════
  group('Upload page — FilePicker interaction (Phase 3)', () {
 
    testWidgets(
      'should navigate to upload edit page after selecting a file',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await navigateToUploadPage(tester);
 
        // Act – tap Choose Audio File (opens native FilePicker dialog)
        await tester.tap(find.text('Choose Audio File'));
        await tester.pumpAndSettle();
 
        // Assert – navigated to edit metadata page
        // (requires mock FilePicker — will be implemented in Phase 3)
        expect(find.text('Upload Your Track'), findsNothing);
      },
      skip: true, // Phase 3: wire mock FilePicker into DI container
    );
 
    testWidgets(
      'should show track title field on edit page after file is selected',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await navigateToUploadPage(tester);
 
        // Act
        await tester.tap(find.text('Choose Audio File'));
        await tester.pumpAndSettle();
 
        // Assert
        expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      },
      skip: true, // Phase 3
    );
 
    testWidgets(
      'should show genre field on edit page after file is selected',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await navigateToUploadPage(tester);
 
        // Act
        await tester.tap(find.text('Choose Audio File'));
        await tester.pumpAndSettle();
 
        // Assert
        expect(find.widgetWithText(TextField, 'Genre'), findsOneWidget);
      },
      skip: true, // Phase 3
    );
 
    testWidgets(
      'should show Public / Private toggle on edit page',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await navigateToUploadPage(tester);
 
        // Act
        await tester.tap(find.text('Choose Audio File'));
        await tester.pumpAndSettle();
 
        // Assert
        expect(find.text('Public'), findsOneWidget);
      },
      skip: true, // Phase 3
    );
 
  });
}
 