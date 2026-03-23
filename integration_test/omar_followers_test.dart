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
// MockHttpClientAdapter for Module 3
// ─────────────────────────────────────────────────────────────────
class MockHttpClientAdapter implements HttpClientAdapter {
  bool simulateFollowError;
  final List<Map<String, dynamic>> seedFollowers;
  final List<Map<String, dynamic>> seedFollowing;
  final List<Map<String, dynamic>> seedSuggested;

  MockHttpClientAdapter({
    this.seedFollowers = const [],
    this.seedFollowing = const [],
    this.seedSuggested = const [],
    this.simulateFollowError = false,
  });

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

    // ── Followers list ────────────────────────────────────────────
    if (path.contains('/followers') && method == 'GET') {
      return respond({'data': seedFollowers});
    }

    // ── Following list ────────────────────────────────────────────
    if (path.contains('/following') && method == 'GET') {
      return respond({'data': seedFollowing});
    }

    // ── Suggested users ───────────────────────────────────────────
    if (path.contains('/suggested') && method == 'GET') {
      return respond({'data': seedSuggested});
    }

    // ── Follow / Unfollow ─────────────────────────────────────────
    if (path.contains('/follow')) {
      if (simulateFollowError) return respond({'error': 'Server error'}, 500);
      return respond({});
    }

    return respond({});
  }

  @override
  void close({bool force = false}) {}
}

// ─────────────────────────────────────────────────────────────────
// Module 3: Followers & Social Graph
// Owner: Omar Walid
// ─────────────────────────────────────────────────────────────────
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GetIt.instance.allowReassignment = true;

  setUp(() async {
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  // Navigate back to /home before each test tears down, so that any
  // page still running async work (like _fetchFollowers) is unmounted
  // before setUp clears SharedPreferences on the next test.
  // This prevents "Not logged in" exceptions thrown after test completion.
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

    // Wait for start screen OR navigate back to it if already on home
    const maxAttempts = 40;
    for (var i = 0; i < maxAttempts; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final onStart = find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty;
      if (onStart) break;

      // If previous test left app on home, go back to start
      final onHome = find.byType(BottomNavigationBar).evaluate().isNotEmpty;
      if (onHome) {
        appRouter.go('/start');
        await tester.pumpAndSettle();
        continue;
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }

    await loginAs(tester, validEmail, validPassword);

    // Write userId to SharedPreferences so UserSession.getUserId()
    // returns a value when FollowersListPage._fetchFollowers() fires
    // in initState. The mock login HTTP response is intercepted but
    // LoginScreen._onContinue() still runs and writes to prefs —
    // this is a safety net for timing edge cases.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', 'test_user_id');
    await prefs.setString('displayName', validName);
  }

  // ── Navigate to a followers module page after login ───────────
  // Correct routes confirmed from app_router.dart:
  //   /profile/followers  → FollowersListPage
  //   /profile/following  → FollowingListPage
  //   /profile/suggested  → SuggestedUsersPage
  Future<void> goTo(WidgetTester tester, String route) async {
    appRouter.push(route);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Followers list page  (/profile/followers)
  // ═══════════════════════════════════════════════════════════════
  group('Followers list page', () {

    testWidgets('should show Followers title in app bar', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/followers');

      // Act – no action needed

      // Assert
      expect(find.text('Followers'), findsOneWidget);
    });

    testWidgets('should show No followers yet when list is empty', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/followers');

      // Act – no action needed

      // Assert
      expect(find.text('No followers yet'), findsOneWidget);
    });

    testWidgets('should show follower display name when list is non-empty',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedFollowers: [
          {'_id': 'f1', 'displayName': 'Alice', 'avatarUrl': '', 'followerCount': 5},
        ],
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/followers');

      // Act – no action needed

      // Assert
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('should show Follow button for each follower', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedFollowers: [
          {'_id': 'f1', 'displayName': 'Alice', 'avatarUrl': '', 'followerCount': 5},
        ],
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/followers');

      // Act – no action needed

      // Assert
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('should toggle button to Following after tapping Follow',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedFollowers: [
          {'_id': 'f1', 'displayName': 'Alice', 'avatarUrl': '', 'followerCount': 5},
        ],
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/followers');

      // Act
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('should show error snackbar when follow action fails',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedFollowers: [
          {'_id': 'f1', 'displayName': 'Alice', 'avatarUrl': '', 'followerCount': 5},
        ],
        simulateFollowError: true,
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/followers');

      // Act
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Action failed. Please try again.'), findsOneWidget);
    });

    testWidgets('should navigate back when back button tapped', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/followers');

      // Act – FollowersListPage uses Icons.arrow_back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Followers'), findsNothing);
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Following list page  (/profile/following)
  // ═══════════════════════════════════════════════════════════════
  group('Following list page', () {

    testWidgets('should show Following title in app bar', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/following');

      // Act – no action needed

      // Assert
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('should show People who follow you back banner', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/following');

      // Act – no action needed

      // Assert
      expect(find.text('People who follow you back'), findsOneWidget);
    });

    testWidgets('should show see your true friends subtitle', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/following');

      // Act – no action needed

      // Assert
      expect(find.text('see your true friends'), findsOneWidget);
    });

    testWidgets("should show You're not following anyone yet when empty",
        (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/following');

      // Act – no action needed

      // Assert
      expect(find.text("You're not following anyone yet"), findsOneWidget);
    });

    testWidgets('should show following user name when list is non-empty',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedFollowing: [
          {'_id': 'f1', 'displayName': 'Bob', 'avatarUrl': '', 'followerCount': 10},
        ],
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/following');

      // Act – no action needed

      // Assert
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('should navigate to Your true friends page on banner tap',
        (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/following');

      // Act
      await tester.tap(find.text('People who follow you back'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Your true friends'), findsOneWidget);
    });

  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP: Suggested users page  (/profile/suggested)
  // ═══════════════════════════════════════════════════════════════
  group('Suggested users page', () {

    testWidgets('should show Suggested Users title in app bar', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/suggested');

      // Act – no action needed

      // Assert
      expect(find.text('Suggested Users'), findsOneWidget);
    });

    testWidgets('should show No suggestions right now when empty', (tester) async {
      // Arrange
      await bootAndLogin(tester, MockHttpClientAdapter());
      await goTo(tester, '/profile/suggested');

      // Act – no action needed

      // Assert
      expect(find.text('No suggestions right now'), findsOneWidget);
    });

    testWidgets('should show suggested user name when list is non-empty',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedSuggested: [
          {'_id': 's1', 'displayName': 'Carol', 'avatarUrl': '', 'followerCount': 3},
        ],
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/suggested');

      // Act – no action needed

      // Assert
      expect(find.text('Carol'), findsOneWidget);
    });

    testWidgets('should show Follow button for suggested user', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedSuggested: [
          {'_id': 's1', 'displayName': 'Carol', 'avatarUrl': '', 'followerCount': 3},
        ],
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/suggested');

      // Act – no action needed

      // Assert
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('should toggle to Following after tapping Follow on suggestion',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedSuggested: [
          {'_id': 's1', 'displayName': 'Carol', 'avatarUrl': '', 'followerCount': 3},
        ],
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/suggested');

      // Act
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('should show error snackbar when follow fails on suggestions',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedSuggested: [
          {'_id': 's1', 'displayName': 'Carol', 'avatarUrl': '', 'followerCount': 3},
        ],
        simulateFollowError: true,
      );
      await bootAndLogin(tester, adapter);
      await goTo(tester, '/profile/suggested');

      // Act
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Action failed. Please try again.'), findsOneWidget);
    });

  });
}