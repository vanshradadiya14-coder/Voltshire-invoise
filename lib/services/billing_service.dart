import 'dart:async';

import '../models/subscription.dart';

/// The app's contract with a billing provider.
///
/// Every screen and provider talks to this interface, never to a store SDK.
/// That gives three concrete benefits:
///
///  * widget and unit tests run with [MockBillingService] and need no store,
///    no network and no platform channels;
///  * the app boots and works before store products have been configured;
///  * swapping RevenueCat for anything else touches exactly one file.
abstract class BillingService {
  /// Prepares the SDK. Must tolerate a missing/invalid API key by degrading to
  /// Free rather than throwing — a billing outage must never block sign-in.
  Future<void> initialise({String? appUserId});

  /// Associates purchases with the signed-in user, so entitlements follow them
  /// across devices and reinstalls.
  Future<void> identify(String appUserId);

  /// Clears the identity on sign-out so the next user does not inherit
  /// entitlements on a shared device.
  Future<void> logOut();

  /// The current entitlement state, re-emitted whenever the store reports a
  /// change (purchase, renewal, cancellation, expiry).
  Stream<Entitlements> watchEntitlements();

  /// A one-shot read, used at startup and after returning from the store.
  Future<Entitlements> fetchEntitlements();

  /// Packages currently purchasable, grouped by tier and period. Returns an
  /// empty list when the store is unreachable or products are not yet set up.
  Future<List<SubscriptionOffer>> fetchOffers();

  /// Starts the platform purchase flow for [offer].
  Future<PurchaseResult> purchase(SubscriptionOffer offer);

  /// Restores previous purchases — required by App Store review guidelines.
  Future<PurchaseResult> restore();

  /// Whether billing is actually wired up. False when running on an
  /// unsupported platform or with no API key, so the UI can explain why the
  /// paywall is unavailable instead of showing an empty screen.
  bool get isAvailable;

  void dispose();
}

/// An in-memory [BillingService] used by tests, CI and local development.
///
/// It behaves like a real store: purchases succeed, entitlements stream, and
/// restore works — it simply never talks to a network.
class MockBillingService implements BillingService {
  MockBillingService({Entitlements initial = Entitlements.free})
      : _current = initial;

  final StreamController<Entitlements> _controller =
      StreamController<Entitlements>.broadcast();
  Entitlements _current;
  bool _disposed = false;

  /// Set by tests to simulate a store failure.
  bool shouldFailPurchase = false;

  /// Set by tests to simulate the user backing out of the store sheet.
  bool shouldCancelPurchase = false;

  @override
  bool get isAvailable => true;

  Entitlements get current => _current;

  @override
  Future<void> initialise({String? appUserId}) async {
    _emit(_current);
  }

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<void> logOut() async {
    _current = Entitlements.free;
    _emit(_current);
  }

  @override
  Stream<Entitlements> watchEntitlements() => _controller.stream;

  @override
  Future<Entitlements> fetchEntitlements() async => _current;

  @override
  Future<List<SubscriptionOffer>> fetchOffers() async {
    return <SubscriptionOffer>[
      const SubscriptionOffer(
        identifier: 'mock_pro_monthly',
        tier: SubscriptionTier.pro,
        period: BillingPeriod.monthly,
        priceString: '£9.99',
        rawPrice: 9.99,
        introOfferDays: 14,
      ),
      const SubscriptionOffer(
        identifier: 'mock_pro_yearly',
        tier: SubscriptionTier.pro,
        period: BillingPeriod.yearly,
        priceString: '£99.00',
        rawPrice: 99,
        introOfferDays: 14,
      ),
      const SubscriptionOffer(
        identifier: 'mock_business_monthly',
        tier: SubscriptionTier.business,
        period: BillingPeriod.monthly,
        priceString: '£24.99',
        rawPrice: 24.99,
      ),
      const SubscriptionOffer(
        identifier: 'mock_business_yearly',
        tier: SubscriptionTier.business,
        period: BillingPeriod.yearly,
        priceString: '£249.00',
        rawPrice: 249,
      ),
    ];
  }

  @override
  Future<PurchaseResult> purchase(SubscriptionOffer offer) async {
    if (shouldCancelPurchase) return PurchaseResult.cancelled();
    if (shouldFailPurchase) {
      return PurchaseResult.failed('Mock purchase failure');
    }

    final DateTime now = DateTime.now();
    final bool trial = offer.hasTrial && !_current.tier.isPaid;

    _current = Entitlements(
      tier: offer.tier,
      status: trial ? SubscriptionStatus.trialing : SubscriptionStatus.active,
      period: offer.period,
      expiresAt: offer.period == BillingPeriod.yearly
          ? DateTime(now.year + 1, now.month, now.day)
          : DateTime(now.year, now.month + 1, now.day),
      trialEndsAt:
          trial ? now.add(Duration(days: offer.introOfferDays ?? 14)) : null,
      willRenew: true,
    );
    _emit(_current);
    return PurchaseResult.success(_current);
  }

  @override
  Future<PurchaseResult> restore() async {
    if (_current.tier.isPaid) return PurchaseResult.success(_current);
    return PurchaseResult.failed('No previous purchases found.');
  }

  /// Test hook: force a specific entitlement state.
  void setEntitlements(Entitlements value) {
    _current = value;
    _emit(value);
  }

  void _emit(Entitlements value) {
    if (!_disposed && !_controller.isClosed) _controller.add(value);
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.close();
  }
}
