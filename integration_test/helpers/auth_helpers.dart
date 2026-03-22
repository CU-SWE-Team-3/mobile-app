import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loginAs(
    WidgetTester tester, String email, String password) async {
  await tester.enterText(
    find.widgetWithText(TextField,
        'Email address or profile URL').first,
    email,
  );
  await tester.pumpAndSettle();
  await tester.tap(
      find.widgetWithText(ElevatedButton, 'Continue'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextField,
        'Your Password (min. 8 characters)').first,
    password,
  );
  await tester.pumpAndSettle();
  await tester.tap(
      find.widgetWithText(ElevatedButton, 'Continue'));
  await tester.pumpAndSettle();
}