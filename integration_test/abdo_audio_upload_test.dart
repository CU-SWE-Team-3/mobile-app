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
// MockHttpClientAdapter for Module 4
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

    ResponseBody respond(Object body, [int status = 200]) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );

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

    if (path.endsWith('/tracks') && method == 'POST') {
      return respond({
        'data': {'_id': 'track_001', 'title': 'Test Track', 'status': 'processing'},
      }, 201);
    }

    return respond({});
  }

  @override
  void close({bool force = false}) {}
}

// ─────────────────────────────────────────────────────────────────
// Module 4: Audio Upload & Track Management
// Owner: Abdelrahman Osama
//
// IMPORTANT — Route clarification (from reading app_router.dart):
//   /upload          → UploadEditPage  (metadata form, reached AFTER
//                       FilePicker selects a file)
//   /library/uploads → LibraryUploadsPage  (the uploads list screen
//                       with the FAB that triggers FilePicker)
//
//   The standalone UploadPage widget in upload_page.dart has NO route
//   assigned — it is unreachable. All upload UI tests target
//   LibraryUploadsPage at /library/uploads.
//
// NOTE — FilePicker:
//   FilePicker opens a native Android dialog the test framework cannot
//   drive. Tests requiring file selection are skip: true for Phase 2
//   and will be re-enabled in Phase 3 once a mock is injected.
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
      appRouter.go('/start');
    } catch (_) {}
  });

  // ── Boot app, inject mock, login ─────────────────────────────
  Future<void> bootAndLogin(WidgetTester tester) async {
    app.main();
    dioClient.dio.httpClientAdapter = MockHttpClientAdapter();
    await Future.delayed(const Duration(seconds: 2));

    const maxAttempts = 40;
    for (var i = 0; i < maxAttempts; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final onStart = find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty;
      if (onStart) break;

      // Force /start for any unknown screen
      appRouter.go('/start');
      await tester.pumpAndSettle();
    }

    await loginAs(tester, validEmail, validPassword);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', 'test_user_id');
    await prefs.setString('displayName', validName);
  }

  // ── Navigate to the uploads list page ────────────────────────
  Future<void> goToUploadsPage(WidgetTester tester) async {
    appRouter.push('/library/uploads');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Library uploads page  (/library/uploads)
  // Static UI tests — no FilePicker interaction
  // ═══════════════════════════════════════════════════════════════
  group('Library uploads page — static UI', () {

    testWidgets('should show Your Uploads title in app bar', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goToUploadsPage(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Your Uploads'), findsOneWidget);
    });

    testWidgets('should show Search in your uploads hint', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goToUploadsPage(tester);

      // Act – no action needed

      // Assert
      expect(find.text('Search in your uploads'), findsOneWidget);
    });

    testWidgets('should show No Amplify credits pill', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goToUploadsPage(tester);

      // Act – no action needed

      // Assert
      expect(find.text('No Amplify credits'), findsOneWidget);
    });

    testWidgets('should show storage usage pill', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goToUploadsPage(tester);

      // Act – no action needed

      // Assert
      expect(find.text('24/120 mins used'), findsOneWidget);
    });

    testWidgets('should show upload FAB with add icon', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goToUploadsPage(tester);

      // Act – no action needed

      // Assert — FloatingActionButton with Icons.add
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should show search TextField', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goToUploadsPage(tester);

      // Act – no action needed

      // Assert
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should navigate back when back button tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester);
      await goToUploadsPage(tester);

      // Act
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert — uploads page title is gone
      expect(find.text('Your Uploads'), findsNothing);
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Upload metadata page  (/upload = UploadEditPage)
  // Reached after FilePicker selects a file — all skipped Phase 2
  // ═══════════════════════════════════════════════════════════════
  group('Upload metadata page (Phase 3)', () {

    testWidgets(
      'should show title field after file selected',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await goToUploadsPage(tester);

        // Act — tap FAB to trigger FilePicker (native dialog, not driveable)
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Assert
        expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      },
      skip: true, // Phase 3: inject mock FilePicker
    );

    testWidgets(
      'should show genre dropdown after file selected',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await goToUploadsPage(tester);

        // Act
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('All Music Genres'), findsOneWidget);
      },
      skip: true, // Phase 3
    );

    testWidgets(
      'should show Public toggle after file selected',
      (tester) async {
        // Arrange
        await bootAndLogin(tester);
        await goToUploadsPage(tester);

        // Act
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Public'), findsOneWidget);
      },
      skip: true, // Phase 3
    );

  });
}