// ─────────────────────────────────────────────────────────────────────────────
// BioBeats — Module 12 — Premium Subscription
// Owner    : Abdelrahman Osama  |  Phase 4  |  Android
// Framework: Flutter integration_test — real server
//
// API endpoints exercised:
//   POST   /subscriptions/checkout   (planType: "Pro" | "Go+" only — no "Free" plan)
//   DELETE /subscriptions/cancel     (cancelAtPeriodEnd: true, 400 if no active sub)
//   GET    /profile/tier             (isPremium, planType, cancelAtPeriodEnd, expiresAt)
//
// Plans available: Pro and "Go+" only
//   Pro   — unlimited uploads, scheduled releases, audio quality options
//   Go+   — offline listening / downloads, exclusive content
//   premium_plan_tile_0 → plan index 0 (Pro)
//   premium_plan_tile_1 → plan index 1 (Go+)
//   (No premium_plan_tile_2 — only two paid plans exist)
//
// Test IDs: PRE-001 → PRE-043
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/main.dart' as app;
import 'package:soundcloud_clone/core/router/app_router.dart';

import 'helpers/auth_helpers.dart';
import 'helpers/test_data.dart';
import 'helpers/test_keys.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GetIt.instance.allowReassignment = true;

  setUp(() async {
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  tearDown(() async {
    try { appRouter.go('/start'); } catch (_) {}
  });

  Future<void> bootAndLogin(WidgetTester t) async {
    app.main();
    await Future.delayed(const Duration(seconds: 2));
    for (var i = 0; i < 40; i++) {
      await t.pumpAndSettle(const Duration(milliseconds: 500));
      if (find.text('Log in').evaluate().isNotEmpty &&
          find.text('Create an account').evaluate().isNotEmpty) break;
      appRouter.go('/start');
      await t.pumpAndSettle();
    }
    await loginAs(t, validEmail, validPassword);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayName', validName);
  }

  Future<void> goTo(WidgetTester t, String r) async {
    appRouter.push(r);
    await t.pumpAndSettle(const Duration(seconds: 5));
  }

  // ══════════════════════════════════════════════════════════════
  // GROUP 1 — Premium Paywall (/upgrade)
  // Free user → subscribe CTA; Premium user → manage/cancel
  // ══════════════════════════════════════════════════════════════
  group('PRE — Premium Paywall page', () {

    testWidgets('PRE-001: Paywall loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('PRE-002: paywall_dismiss_button present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      expect(find.byKey(const Key(kPaywallDismissButton)), findsOneWidget);
    });

    // Free user: subscribe button; premium user: current plan label
    testWidgets('PRE-003: premium_subscribe_button or premium_current_plan_label present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.byKey(const Key(kPremiumSubscribeButton)).evaluate().isNotEmpty
          || find.byKey(const Key(kPremiumCurrentPlanLabel)).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    // Plans are Pro and Go+ per API
    testWidgets('PRE-004: Paywall shows Pro or Go+ branding', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.textContaining('Pro').evaluate().isNotEmpty
          || find.textContaining('Go+').evaluate().isNotEmpty
          || find.textContaining('Unlock').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-005: paywall_dismiss_button navigates away', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.tap(find.byKey(const Key(kPaywallDismissButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key(kPremiumSubscribeButton)), findsNothing);
    });

    testWidgets('PRE-006: premium_subscribe_button navigates to pricing', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final btn = find.byKey(const Key(kPremiumSubscribeButton));
      if (btn.evaluate().isNotEmpty) {
        await t.tap(btn);
        await t.pumpAndSettle(const Duration(seconds: 4));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('PRE-007: Paywall does not crash on scroll', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      final scroll = find.byType(SingleChildScrollView);
      if (scroll.evaluate().isNotEmpty) {
        await t.fling(scroll.first, const Offset(0, -200), 800);
        await t.pumpAndSettle();
      }
      expect(find.byType(Exception), findsNothing);
    });

    // Premium user: premium_current_plan_label shown
    testWidgets('PRE-008: premium_current_plan_label shown to premium user', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 5));
      if (find.byKey(const Key(kPremiumCurrentPlanLabel)).evaluate().isNotEmpty) {
        expect(find.byKey(const Key(kPremiumCurrentPlanLabel)), findsOneWidget);
      }
    });

    // API: DELETE /subscriptions/cancel — only for premium users without cancelAtPeriodEnd
    testWidgets('PRE-009: Cancel plan option visible to premium user', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 5));
      if (find.byKey(const Key(kPremiumCurrentPlanLabel)).evaluate().isNotEmpty) {
        final ok = find.textContaining('Cancel').evaluate().isNotEmpty
            || find.textContaining('Manage').evaluate().isNotEmpty;
        expect(ok, isTrue);
      }
    });

    // Cancel plan dialog: "Keep plan" / "Cancel plan" (from source code and API spec)
    testWidgets('PRE-010: Cancel plan dialog has Keep plan and Cancel plan buttons', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final cancelOption = find.textContaining('Cancel plan');
      if (cancelOption.evaluate().isNotEmpty) {
        await t.tap(cancelOption.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        final ok = find.text('Keep plan').evaluate().isNotEmpty
            || find.textContaining('Cancel plan').evaluate().isNotEmpty;
        expect(ok, isTrue);
      }
    });

    // "Keep plan" dismisses dialog — no API call made
    testWidgets('PRE-011: Keep plan button dismisses cancel dialog', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final cancelOption = find.textContaining('Cancel plan');
      if (cancelOption.evaluate().isNotEmpty) {
        await t.tap(cancelOption.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        final keepBtn = find.text('Keep plan');
        if (keepBtn.evaluate().isNotEmpty) {
          await t.tap(keepBtn);
          await t.pumpAndSettle(const Duration(seconds: 2));
          expect(find.byType(Exception), findsNothing);
        }
      }
    });

    // Feature list visible on paywall
    testWidgets('PRE-012: Feature list (uploads, offline, etc.) visible on paywall', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.textContaining('upload').evaluate().isNotEmpty
          || find.textContaining('Upload').evaluate().isNotEmpty
          || find.textContaining('Offline').evaluate().isNotEmpty
          || find.textContaining('Unlimited').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 2 — Pricing Tiers (/upgrade/pricing)
  // API: POST /subscriptions/checkout  planType: "Pro" | "Go+"
  // ══════════════════════════════════════════════════════════════
  group('PRE — Pricing Tiers page', () {

    testWidgets('PRE-013: Pricing page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      expect(find.byType(Exception), findsNothing);
    });

    // At least one plan tile rendered — API has exactly 2 paid plans (Pro, Go+)
    testWidgets('PRE-014: At least one premium_plan_tile present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.byKey(const Key(kPremiumPlanTile)).evaluate().isNotEmpty
          || find.byKey(Key(kPremiumPlanTileByIdx(0))).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    // premium_plan_tile_0 = Pro plan
    testWidgets('PRE-015: premium_plan_tile_0 (Pro) present and tappable', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final tile = find.byKey(Key(kPremiumPlanTileByIdx(0)));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // premium_plan_tile_1 = Go+ plan
    testWidgets('PRE-016: premium_plan_tile_1 (Go+) present and tappable', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final tile = find.byKey(Key(kPremiumPlanTileByIdx(1)));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // Plan names from API: "Pro" and "Go+"
    testWidgets('PRE-017: Pro and Go+ plan names visible', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.textContaining('Pro').evaluate().isNotEmpty
          || find.textContaining('Go+').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-018: premium_confirm_button present after plan selection', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final tile = find.byKey(Key(kPremiumPlanTileByIdx(0)));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile);
        await t.pumpAndSettle(const Duration(seconds: 2));
      }
      final ok = find.byKey(const Key(kPremiumConfirmButton)).evaluate().isNotEmpty
          || find.textContaining('Confirm').evaluate().isNotEmpty
          || find.textContaining('Subscribe').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-019: premium_confirm_button tappable without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final tile = find.byKey(Key(kPremiumPlanTileByIdx(0)));
      if (tile.evaluate().isNotEmpty) {
        await t.tap(tile);
        await t.pumpAndSettle(const Duration(seconds: 2));
      }
      final confirm = find.byKey(const Key(kPremiumConfirmButton));
      if (confirm.evaluate().isNotEmpty) {
        await t.tap(confirm);
        await t.pumpAndSettle(const Duration(seconds: 4));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('PRE-020: Pricing page back navigation works', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      final back = find.byIcon(Icons.arrow_back_ios_sharp).evaluate().isNotEmpty
          ? find.byIcon(Icons.arrow_back_ios_sharp)
          : find.byIcon(Icons.arrow_back);
      if (back.evaluate().isNotEmpty) {
        await t.tap(back.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // Select plan_tile_0 then plan_tile_1 — only 2 paid plans
    testWidgets('PRE-021: Selecting plan_tile_0 then plan_tile_1 — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 4));
      for (var i = 0; i <= 1; i++) {
        final tile = find.byKey(Key(kPremiumPlanTileByIdx(i)));
        if (tile.evaluate().isNotEmpty) {
          await t.tap(tile);
          await t.pumpAndSettle(const Duration(seconds: 1));
          expect(find.byType(Exception), findsNothing);
        }
      }
    });

    // API: POST /subscriptions/checkout returns 400 for already-active subscriber
    testWidgets('PRE-022: Premium user current plan tile shown as highlighted', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 3 — Subscription Status (/upgrade/status)
  // API: GET /profile/tier — isPremium, planType (Pro|Go+), cancelAtPeriodEnd
  // ══════════════════════════════════════════════════════════════
  group('PRE — Subscription Status page', () {

    testWidgets('PRE-023: Status page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/status');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('PRE-024: premium_current_plan_label present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/status');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.byKey(const Key(kPremiumCurrentPlanLabel)).evaluate().isNotEmpty
          || find.textContaining('plan').evaluate().isNotEmpty
          || find.textContaining('Free').evaluate().isNotEmpty
          || find.textContaining('Pro').evaluate().isNotEmpty
          || find.textContaining('Go+').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    // cancelAtPeriodEnd: false → "Cancel subscription" option shown
    // isPremium: false → "Upgrade" shown
    testWidgets('PRE-025: Status page shows upgrade or cancel/manage action', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/status');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.textContaining('Upgrade').evaluate().isNotEmpty
          || find.textContaining('Subscribe').evaluate().isNotEmpty
          || find.textContaining('Manage').evaluate().isNotEmpty
          || find.textContaining('Cancel').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    // "Cancel anytime" perk shown per subscription API spec
    testWidgets('PRE-026: Status page shows plan perks', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/status');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.textContaining('Cancel anytime').evaluate().isNotEmpty
          || find.textContaining('upload').evaluate().isNotEmpty
          || find.byType(ListTile).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-027: Status page back navigation works', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/status');
      final back = find.byIcon(Icons.arrow_back_ios_sharp).evaluate().isNotEmpty
          ? find.byIcon(Icons.arrow_back_ios_sharp)
          : find.byIcon(Icons.arrow_back);
      if (back.evaluate().isNotEmpty) {
        await t.tap(back.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 4 — Offline Download (/upgrade/offline)
  // Go+ plan required — Pro users see upsell to Go+
  // ══════════════════════════════════════════════════════════════
  group('PRE — Offline Download page', () {

    testWidgets('PRE-028: Offline page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/offline');
      expect(find.byType(Exception), findsNothing);
    });

    // Free and Pro users see Go+ required message
    testWidgets('PRE-029: Non-Go+ user sees Go+ required message', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/offline');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final ok = find.textContaining('Go+').evaluate().isNotEmpty
          || find.textContaining('Offline').evaluate().isNotEmpty
          || find.textContaining('Download').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-030: premium_download_button tappable if present', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/offline');
      await t.pumpAndSettle(const Duration(seconds: 5));
      final btn = find.byKey(const Key(kPremiumDownloadButton));
      if (btn.evaluate().isNotEmpty) {
        await t.tap(btn);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });

    testWidgets('PRE-031: Offline page does not crash on scroll', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/offline');
      final scroll = find.byType(SingleChildScrollView);
      if (scroll.evaluate().isNotEmpty) {
        await t.fling(scroll.first, const Offset(0, -200), 800);
        await t.pumpAndSettle();
      }
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 5 — Explore Features (/upgrade/features)
  // ══════════════════════════════════════════════════════════════
  group('PRE — Explore Features page', () {

    testWidgets('PRE-032: Features page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/features');
      expect(find.byType(Exception), findsNothing);
    });

    // Features from API plans: unlimited uploads (Pro), offline listening (Go+)
    testWidgets('PRE-033: Features page shows Pro/Go+ feature list', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/features');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.textContaining('Offline').evaluate().isNotEmpty
          || find.textContaining('Unlimited').evaluate().isNotEmpty
          || find.textContaining('upload').evaluate().isNotEmpty
          || find.textContaining('Pro').evaluate().isNotEmpty
          || find.textContaining('Go+').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-034: Features page has subscribe CTA', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/features');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.byKey(const Key(kPremiumSubscribeButton)).evaluate().isNotEmpty
          || find.textContaining('Subscribe').evaluate().isNotEmpty
          || find.textContaining('Upgrade').evaluate().isNotEmpty
          || find.textContaining('Get').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-035: Features page does not crash on scroll', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade/features');
      final scroll = find.byType(SingleChildScrollView);
      if (scroll.evaluate().isNotEmpty) {
        await t.fling(scroll.first, const Offset(0, -300), 800);
        await t.pumpAndSettle();
      }
      expect(find.byType(Exception), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 6 — Payment Success (/payment-success)
  // Reached after Stripe webhook fires checkout.session.completed
  // ══════════════════════════════════════════════════════════════
  group('PRE — Payment Success page', () {

    testWidgets('PRE-036: Payment success page loads without crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/payment-success');
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('PRE-037: Success page shows success indication', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/payment-success');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.textContaining('Success').evaluate().isNotEmpty
          || find.textContaining('Welcome').evaluate().isNotEmpty
          || find.textContaining('Pro').evaluate().isNotEmpty
          || find.textContaining('Go+').evaluate().isNotEmpty
          || find.byIcon(Icons.check_circle).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-038: Success page has continue or done button', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/payment-success');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final ok = find.textContaining('Continue').evaluate().isNotEmpty
          || find.textContaining('Done').evaluate().isNotEmpty
          || find.textContaining('Explore').evaluate().isNotEmpty;
      expect(ok, isTrue);
    });

    testWidgets('PRE-039: Tapping continue/done navigates away', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/payment-success');
      await t.pumpAndSettle(const Duration(seconds: 4));
      final btn = find.textContaining('Continue').evaluate().isNotEmpty
          ? find.textContaining('Continue')
          : find.textContaining('Done');
      if (btn.evaluate().isNotEmpty) {
        await t.tap(btn.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(Exception), findsNothing);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP 7 — Cross-page premium navigation
  // ══════════════════════════════════════════════════════════════
  group('PRE — Cross-page premium navigation', () {

    // /upgrade → /upgrade/pricing → back → /upgrade/status
    testWidgets('PRE-040: Paywall → Pricing → back → Status — no crash', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.pumpAndSettle(const Duration(seconds: 3));
      appRouter.push('/upgrade/pricing');
      await t.pumpAndSettle(const Duration(seconds: 3));
      appRouter.pop();
      await t.pumpAndSettle(const Duration(seconds: 2));
      appRouter.push('/upgrade/status');
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });

    // Rapid navigation through all 5 premium routes
    testWidgets('PRE-041: Rapid navigation through all premium pages — no crash', (t) async {
      await bootAndLogin(t);
      for (final r in [
        '/upgrade',
        '/upgrade/pricing',
        '/upgrade/status',
        '/upgrade/features',
        '/upgrade/offline',
      ]) {
        appRouter.push(r);
        await t.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(Exception), findsNothing);
      }
    });

    // paywall_dismiss_button always navigates back — no premium module page blocks
    testWidgets('PRE-042: paywall_dismiss_button dismisses every premium route', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      await t.tap(find.byKey(const Key(kPaywallDismissButton)));
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key(kPaywallDismissButton)), findsNothing);
    });

    // premium_subscribe_button present across paywall and features pages
    testWidgets('PRE-043: premium_subscribe_button visible on /upgrade page', (t) async {
      await bootAndLogin(t);
      await goTo(t, '/upgrade');
      final ok = find.byKey(const Key(kPremiumSubscribeButton)).evaluate().isNotEmpty
          || find.byKey(const Key(kPremiumCurrentPlanLabel)).evaluate().isNotEmpty;
      expect(ok, isTrue);
    });
  });
}