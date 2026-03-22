import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundcloud_clone/main.dart' as app;

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';

// ─────────────────────────────────────────────────────────────────
// Module 4: Audio Upload & Track Management
// Owner: Abdelrahman Osama
// ─────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Upload page', () {

    testWidgets('should show Upload Your Track heading', (tester) async {
      // Arrange
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);

      // Act — navigate to upload
      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Upload Your Track'), findsOneWidget);
    });

    testWidgets('should show Choose Audio File button', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pumpAndSettle();

      expect(find.text('Choose Audio File'), findsOneWidget);
    });

    testWidgets('should show description text', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Select an audio file from your device to get started.'),
        findsOneWidget,
      );
    });

    testWidgets('should show Cancel button', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should navigate back when Cancel tapped', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert — upload heading gone
      expect(find.text('Upload Your Track'), findsNothing);
    });

    testWidgets('should show upload icon on page', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.upload_file), findsWidgets);
    });

  });

  group('Upload metadata form', () {

    testWidgets('FilePicker is native dialog — skipped for Phase 2',
        (tester) async {
      // FilePicker.platform.pickFiles() opens the Android native file picker.
      // This dialog is outside the Flutter widget tree and cannot be
      // controlled by integration_test.
      // These tests will be implemented in Phase 3 using a mock file provider.
      // Status: Not Tested — documented in Excel sheet.
    }, skip: true);

  });
}