import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundcloud_clone/main.dart' as app;

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';

// ─────────────────────────────────────────────────────────────────
// Module 2: User Profile & Social Identity
// Owner: Abdelrahman Osama
// ─────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Edit profile page', () {

    testWidgets('should show Edit profile title', (tester) async {
      // Arrange
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);

      // Act
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('should show Save button', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should show Display Name field', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.text('Display Name'), findsOneWidget);
    });

    testWidgets('should show City field', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.text('City'), findsOneWidget);
    });

    testWidgets('should show Country field', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.text('Country'), findsOneWidget);
    });

    testWidgets('should show Bio section', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.text('Bio'), findsOneWidget);
    });

  });

  group('Display name editing', () {

    testWidgets('should type in display name field', (tester) async {
      // Arrange
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(
          find.byType(TextField).first, 'New Test Name');
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('New Test Name'), findsOneWidget);
    });

    testWidgets('should enforce 50 character max on display name',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(
          find.byType(TextField).first, 'x' * 60);
      await tester.pumpAndSettle();

      // Assert — capped at 50 by maxLength
      final field = tester.widget<TextField>(
          find.byType(TextField).first);
      expect(field.controller!.text.length, lessThanOrEqualTo(50));
    });

    testWidgets('should tap Save without crashing', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert — no exception thrown
      expect(tester.takeException(), isNull);
    });

  });

  group('Country picker', () {

    testWidgets('should open country list when Country tapped',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Country'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Egypt'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
    });

    testWidgets('should select Egypt from country list', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Country'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Egypt'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Egypt'), findsOneWidget);
    });

  });

  group('Bio editor', () {

    testWidgets('should open bio sheet when Bio row tapped', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Add a bio'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('should type bio and confirm with Done', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Add a bio'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).last, 'E2E testing account');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('E2E testing account'), findsOneWidget);
    });

    testWidgets('should enforce 500 char bio limit', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a bio'));
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(
          find.byType(TextField).last, 'x' * 600);
      await tester.pumpAndSettle();

      // Assert
      final field = tester.widget<TextField>(
          find.byType(TextField).last);
      expect(field.controller!.text.length, lessThanOrEqualTo(500));
    });

  });

  group('Discard dialog', () {

    testWidgets('should show discard dialog on back with unsaved changes',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      // Make a change
      await tester.enterText(
          find.byType(TextField).first, 'Changed Name');
      await tester.pumpAndSettle();

      // Press back
      await tester.tap(
          find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('DISCARD CHANGES'), findsOneWidget);
      expect(find.text('CONTINUE EDITING'), findsOneWidget);
    });

    testWidgets('should stay on edit page when CONTINUE EDITING tapped',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).first, 'Changed Name');
      await tester.tap(
          find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('CONTINUE EDITING'));
      await tester.pumpAndSettle();

      // Assert — still on edit page
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should go back when DISCARD CHANGES tapped',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await loginAs(tester, validEmail, validPassword);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).first, 'Changed Name');
      await tester.tap(
          find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('DISCARD CHANGES'));
      await tester.pumpAndSettle();

      // Assert — Save button gone, back on profile
      expect(find.text('Save'), findsNothing);
    });

  });
}