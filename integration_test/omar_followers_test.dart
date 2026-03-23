import 'dart:convert';
import 'dart:typed_data';
import 'package:soundcloud_clone/core/router/app_router.dart' as from_app_router;
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
// MockHttpClientAdapter for Module 3
//
// Covers:
//   POST /auth/login              → success (200)
//   GET  /network/:id/followers   → empty list  (tests empty state)
//   GET  /network/:id/following   → empty list
//   GET  /network/suggested       → empty list
//   POST /network/:id/follow      → 200 (follow action)
//   DELETE /network/:id/follow    → 200 (unfollow action)
//   POST /network/:id/follow      → 500 (used to simulate action failure)
// ─────────────────────────────────────────────────────────────────
class MockHttpClientAdapter implements HttpClientAdapter {
  // When true, follow/unfollow calls return 500 to test error snackbar.
  bool simulateFollowError = false;
 
  // Pre-seeded user list to test non-empty states.
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
 
    // ── Followers list ────────────────────────────────────────────
    if (path.contains('/followers') && method == 'GET') {
      return _respond({'data': seedFollowers});
    }
 
    // ── Following list ────────────────────────────────────────────
    if (path.contains('/following') && method == 'GET') {
      return _respond({'data': seedFollowing});
    }
 
    // ── Suggested users ───────────────────────────────────────────
    if (path.contains('/suggested') && method == 'GET') {
      return _respond({'data': seedSuggested});
    }
 
    // ── Follow / Unfollow actions ─────────────────────────────────
    if (path.contains('/follow')) {
      if (simulateFollowError) {
        return _respond({'error': 'Server error'}, 500);
      }
      return _respond({});
    }
 
    // ── userId stored in prefs endpoint ──────────────────────────
    if (path.contains('/users')) {
      return _respond({'data': []});
    }
 
    return _respond({});
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
  });
 
  // ── Boot app, inject mock, login, and navigate to target page ───
  Future<void> bootAndLogin(
    WidgetTester tester,
    MockHttpClientAdapter adapter,
  ) async {
    // Arrange – launch app and inject mock before any HTTP call
    app.main();
    dioClient.dio.httpClientAdapter = adapter;
    await Future.delayed(const Duration(seconds: 2));
 
    // Wait for start screen
    const maxAttempts = 40;
    for (var i = 0; i < maxAttempts; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final onStart =
          find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty;
      if (onStart) break;
      await Future.delayed(const Duration(milliseconds: 250));
    }
 
    // Act – login
    await loginAs(tester, validEmail, validPassword);
  }
 
  // ─────────────────────────────────────────────────────────────────
  // Helper: navigate to a named page from the home bottom nav or profile.
  // The followers pages are accessed via the profile tab → followers.
  // We use go_router paths directly via the test driver navigation
  // by tapping the correct AppBar back chain.
  // ─────────────────────────────────────────────────────────────────
 
  // ═══════════════════════════════════════════════════════════════
  // GROUP: Followers list page
  // ═══════════════════════════════════════════════════════════════
  group('Followers list page', () {
 
    testWidgets('should show Followers title in app bar', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
 
      // Act – navigate to /followers via go_router
      // The FollowersListPage is pushed from the profile page.
      // In integration tests we drive routing directly.
      final router = find.byType(MaterialApp);
      expect(router, findsOneWidget);
 
      // Use the router reference to push the followers route.
      // We tap the profile nav item, then the followers row.
      // Since the exact nav structure varies, we push the route directly.
      await tester.pumpWidget(
        // Re-use the already running app widget tree — just pump.
        tester.binding.rootElement!.widget as Widget,
      );
 
      // Navigate directly via the exposed appRouter.
      // ignore: invalid_use_of_visible_for_testing_member
      await tester.binding.runAsync(() async {
        // Push followers page directly through the router.
        // This is the most reliable way in integration tests without Keys.
        from_app_router.appRouter.push('/followers');
      });
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Assert
      expect(find.text('Followers'), findsOneWidget);
    });
 
    testWidgets('should show No followers yet when list is empty', (tester) async {
      // Arrange – empty seed list
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/followers');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed, checking initial empty state
 
      // Assert
      expect(find.text('No followers yet'), findsOneWidget);
    });
 
    testWidgets('should show follower names when list is non-empty', (tester) async {
      // Arrange – seed one follower
      final adapter = MockHttpClientAdapter(
        seedFollowers: [
          {
            '_id': 'follower_1',
            'displayName': 'Alice',
            'avatarUrl': '',
            'followerCount': 5,
          },
        ],
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/followers');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed, checking rendered list
 
      // Assert
      expect(find.text('Alice'), findsOneWidget);
    });
 
    testWidgets('should show Follow button for each follower', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedFollowers: [
          {
            '_id': 'follower_1',
            'displayName': 'Alice',
            'avatarUrl': '',
            'followerCount': 5,
          },
        ],
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/followers');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert – Follow button is rendered
      expect(find.text('Follow'), findsOneWidget);
    });
 
    testWidgets('should toggle to Following after tapping Follow', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedFollowers: [
          {
            '_id': 'follower_1',
            'displayName': 'Alice',
            'avatarUrl': '',
            'followerCount': 5,
          },
        ],
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/followers');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – tap the Follow button
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
 
      // Assert – button now reads 'Following'
      expect(find.text('Following'), findsOneWidget);
    });
 
    testWidgets('should show error snackbar when follow action fails', (tester) async {
      // Arrange – adapter returns 500 for follow calls
      final adapter = MockHttpClientAdapter(
        seedFollowers: [
          {
            '_id': 'follower_1',
            'displayName': 'Alice',
            'avatarUrl': '',
            'followerCount': 5,
          },
        ],
        simulateFollowError: true,
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/followers');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
 
      // Assert
      expect(find.text('Action failed. Please try again.'), findsOneWidget);
    });
 
    testWidgets('should navigate back when back button tapped', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/followers');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
 
      // Assert – followers title is gone
      expect(find.text('Followers'), findsNothing);
    });
 
  });
 
  // ═══════════════════════════════════════════════════════════════
  // GROUP: Following list page
  // ═══════════════════════════════════════════════════════════════
  group('Following list page', () {
 
    testWidgets('should show Following title in app bar', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/following');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text('Following'), findsOneWidget);
    });
 
    testWidgets('should show People who follow you back banner', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/following');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text('People who follow you back'), findsOneWidget);
    });
 
    testWidgets('should show see your true friends subtitle', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/following');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text('see your true friends'), findsOneWidget);
    });
 
    testWidgets("should show You're not following anyone yet when empty",
        (tester) async {
      // Arrange – empty following list
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/following');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text("You're not following anyone yet"), findsOneWidget);
    });
 
    testWidgets('should show following user names when list is non-empty',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedFollowing: [
          {
            '_id': 'following_1',
            'displayName': 'Bob',
            'avatarUrl': '',
            'followerCount': 10,
          },
        ],
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/following');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text('Bob'), findsOneWidget);
    });
 
    testWidgets('should navigate to Your true friends page on banner tap',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/following');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act
      await tester.tap(find.text('People who follow you back'));
      await tester.pumpAndSettle();
 
      // Assert
      expect(find.text('Your true friends'), findsOneWidget);
    });
 
  });
 
  // ═══════════════════════════════════════════════════════════════
  // GROUP: Suggested users page
  // ═══════════════════════════════════════════════════════════════
  group('Suggested users page', () {
 
    testWidgets('should show Suggested Users title in app bar', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/suggested-users');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text('Suggested Users'), findsOneWidget);
    });
 
    testWidgets('should show No suggestions right now when empty', (tester) async {
      // Arrange – empty suggestions list
      final adapter = MockHttpClientAdapter();
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/suggested-users');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text('No suggestions right now'), findsOneWidget);
    });
 
    testWidgets('should show suggested user names when list is non-empty',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedSuggested: [
          {
            '_id': 'suggested_1',
            'displayName': 'Carol',
            'avatarUrl': '',
            'followerCount': 3,
          },
        ],
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/suggested-users');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text('Carol'), findsOneWidget);
    });
 
    testWidgets('should show Follow button for suggested user', (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedSuggested: [
          {
            '_id': 'suggested_1',
            'displayName': 'Carol',
            'avatarUrl': '',
            'followerCount': 3,
          },
        ],
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/suggested-users');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act – no action needed
 
      // Assert
      expect(find.text('Follow'), findsOneWidget);
    });
 
    testWidgets('should toggle to Following after tapping Follow on suggestion',
        (tester) async {
      // Arrange
      final adapter = MockHttpClientAdapter(
        seedSuggested: [
          {
            '_id': 'suggested_1',
            'displayName': 'Carol',
            'avatarUrl': '',
            'followerCount': 3,
          },
        ],
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/suggested-users');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
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
          {
            '_id': 'suggested_1',
            'displayName': 'Carol',
            'avatarUrl': '',
            'followerCount': 3,
          },
        ],
        simulateFollowError: true,
      );
      await bootAndLogin(tester, adapter);
      from_app_router.appRouter.push('/suggested-users');
      await tester.pumpAndSettle(const Duration(seconds: 3));
 
      // Act
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
 
      // Assert
      expect(find.text('Action failed. Please try again.'), findsOneWidget);
    });
 
  });
}

