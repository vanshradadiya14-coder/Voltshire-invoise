import 'package:builder_crm/models/subscription.dart';
import 'package:builder_crm/providers/subscription_providers.dart';
import 'package:builder_crm/screens/subscription/paywall_screen.dart';
import 'package:builder_crm/services/billing_service.dart';
import 'package:builder_crm/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The paywall is the only screen where a bug costs money directly. These
/// tests run entirely against [MockBillingService] — no store, no network, no
/// platform channels — which is the whole reason BillingService is an
/// interface rather than a direct RevenueCat call.
void main() {
  late MockBillingService billing;

  setUp(() => billing = MockBillingService());
  tearDown(() => billing.dispose());

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: <Override>[
        billingServiceProvider.overrideWithValue(billing),
        // The real provider needs Firebase; the paywall only needs the tier.
        currentEntitlementsProvider.overrideWithValue(Entitlements.free),
        subscriptionRepositoryProvider.overrideWithValue(null),
        billingBootstrapProvider.overrideWith((ref) async {}),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );
  }

  testWidgets('renders both paid tiers with prices', (WidgetTester t) async {
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();

    expect(find.text('Pro'), findsWidgets);
    expect(find.text('Business'), findsWidgets);
    expect(find.text('Upgrade'), findsOneWidget);
  });

  testWidgets('defaults to yearly billing', (WidgetTester t) async {
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();

    // Yearly is preselected because annual plans retain far better and the
    // saving shown is real.
    expect(find.textContaining('SAVE'), findsOneWidget);
    expect(find.textContaining('a month'), findsWidgets);
  });

  testWidgets('switching to monthly changes the displayed price',
      (WidgetTester t) async {
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();

    expect(find.text('£99.00'), findsOneWidget);

    await t.tap(find.text('Monthly'));
    await t.pumpAndSettle();

    expect(find.text('£9.99'), findsOneWidget);
    expect(find.text('£99.00'), findsNothing);
  });

  testWidgets('always offers restore purchases', (WidgetTester t) async {
    // Required by App Store review, and needed by anyone who reinstalls.
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('shows the trial offer on the call to action',
      (WidgetTester t) async {
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();
    expect(find.textContaining('14-day free trial'), findsOneWidget);
  });

  testWidgets('shows the reason the paywall opened', (WidgetTester t) async {
    await t.pumpWidget(wrap(
      const PaywallScreen(reason: "You've reached the 5 customer limit"),
    ));
    await t.pumpAndSettle();
    expect(find.text("You've reached the 5 customer limit"), findsOneWidget);
  });

  testWidgets('selecting Business highlights it and updates the button',
      (WidgetTester t) async {
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();

    // The plan list scrolls; bring the Business card into view before tapping
    // so the gesture lands on it in the short test viewport.
    await t.scrollUntilVisible(find.text('£249.00'), 120);
    await t.pumpAndSettle();
    await t.tap(find.text('£249.00'));
    await t.pumpAndSettle();

    // Business has no trial in the mock offers, so the CTA changes.
    expect(find.text('Get Business'), findsOneWidget);
  });

  testWidgets('a purchase completes and grants the entitlement',
      (WidgetTester t) async {
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('free trial'));
    await t.pumpAndSettle();

    expect(billing.current.tier, SubscriptionTier.pro);
    expect(billing.current.has(PaidFeature.advancedDashboard), isTrue);
  });

  testWidgets('a cancelled purchase leaves the user on free',
      (WidgetTester t) async {
    billing.shouldCancelPurchase = true;
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('free trial'));
    await t.pumpAndSettle();

    expect(billing.current.isPaid, isFalse);
    // Backing out is a deliberate choice, not an error — say nothing.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed purchase explains itself', (WidgetTester t) async {
    billing.shouldFailPurchase = true;
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('free trial'));
    await t.pumpAndSettle();

    expect(billing.current.isPaid, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('the comparison table lists what each plan includes',
      (WidgetTester t) async {
    await t.pumpWidget(wrap(const PaywallScreen()));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(find.text('Compare plans'), 300);
    expect(find.text('Compare plans'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Unlimited'), findsWidgets);
  });
}
