import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/config/billing_config.dart';
import '../models/subscription.dart';
import 'billing_service.dart';

/// Production [BillingService] backed by RevenueCat.
///
/// RevenueCat is responsible for receipt validation, entitlement computation,
/// grace periods and cross-platform restore. This class only translates its
/// types into the app's own [Entitlements] so nothing else in the codebase
/// imports `purchases_flutter`.
///
/// Failure policy: every call degrades to Free rather than throwing. A billing
/// outage must never prevent a builder from invoicing.
class RevenueCatBillingService implements BillingService {
  RevenueCatBillingService();

  final StreamController<Entitlements> _controller =
      StreamController<Entitlements>.broadcast();

  bool _initialised = false;
  bool _available = false;
  void Function(CustomerInfo)? _listener;

  @override
  bool get isAvailable => _available;

  @override
  Future<void> initialise({String? appUserId}) async {
    if (_initialised) return;
    _initialised = true;

    final String? key = BillingConfig.apiKeyForPlatform();
    if (key == null || key.isEmpty) {
      // No key configured for this platform (or running on desktop/web).
      // Stay unavailable; the paywall shows an explanatory state.
      _available = false;
      _controller.add(Entitlements.free);
      return;
    }

    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.error,
      );

      final PurchasesConfiguration config = PurchasesConfiguration(key)
        ..appUserID = appUserId;
      await Purchases.configure(config);

      _listener = (CustomerInfo info) {
        _controller.add(_toEntitlements(info));
      };
      Purchases.addCustomerInfoUpdateListener(_listener!);

      _available = true;
      _controller.add(await fetchEntitlements());
    } catch (e, st) {
      _available = false;
      debugPrint('RevenueCat init failed: $e\n$st');
      _controller.add(Entitlements.free);
    }
  }

  @override
  Future<void> identify(String appUserId) async {
    if (!_available) return;
    try {
      final LogInResult result = await Purchases.logIn(appUserId);
      _controller.add(_toEntitlements(result.customerInfo));
    } catch (e) {
      debugPrint('RevenueCat identify failed: $e');
    }
  }

  @override
  Future<void> logOut() async {
    if (!_available) {
      _controller.add(Entitlements.free);
      return;
    }
    try {
      await Purchases.logOut();
    } catch (e) {
      // Logging out an anonymous user throws; that is not an error here.
      debugPrint('RevenueCat logout: $e');
    }
    _controller.add(Entitlements.free);
  }

  @override
  Stream<Entitlements> watchEntitlements() => _controller.stream;

  @override
  Future<Entitlements> fetchEntitlements() async {
    if (!_available) return Entitlements.free;
    try {
      return _toEntitlements(await Purchases.getCustomerInfo());
    } catch (e) {
      debugPrint('RevenueCat fetch failed: $e');
      return Entitlements.free;
    }
  }

  @override
  Future<List<SubscriptionOffer>> fetchOffers() async {
    if (!_available) return const <SubscriptionOffer>[];
    try {
      final Offerings offerings = await Purchases.getOfferings();
      final Offering? current = offerings.current;
      if (current == null) return const <SubscriptionOffer>[];

      final List<SubscriptionOffer> offers = <SubscriptionOffer>[];
      for (final Package pkg in current.availablePackages) {
        final SubscriptionOffer? offer = _toOffer(pkg);
        if (offer != null) offers.add(offer);
      }
      // Cheapest tier first, then monthly before yearly — matches the paywall.
      offers.sort((SubscriptionOffer a, SubscriptionOffer b) {
        final int byTier = a.tier.index.compareTo(b.tier.index);
        return byTier != 0 ? byTier : a.period.index.compareTo(b.period.index);
      });
      return offers;
    } catch (e) {
      debugPrint('RevenueCat offerings failed: $e');
      return const <SubscriptionOffer>[];
    }
  }

  @override
  Future<PurchaseResult> purchase(SubscriptionOffer offer) async {
    if (!_available) {
      return PurchaseResult.failed('In-app purchases are unavailable.');
    }
    try {
      final Offerings offerings = await Purchases.getOfferings();
      final List<Package> packages =
          offerings.current?.availablePackages ?? const <Package>[];

      Package? pkg;
      for (final Package p in packages) {
        if (p.storeProduct.identifier == offer.identifier) {
          pkg = p;
          break;
        }
      }
      if (pkg == null) {
        return PurchaseResult.failed('That plan is no longer available.');
      }

      final CustomerInfo info = await Purchases.purchasePackage(pkg);
      return PurchaseResult.success(_toEntitlements(info));
    } on PlatformException catch (e) {
      final PurchasesErrorCode code = PurchasesErrorHelper.getErrorCode(e);
      return switch (code) {
        PurchasesErrorCode.purchaseCancelledError => PurchaseResult.cancelled(),
        PurchasesErrorCode.paymentPendingError => PurchaseResult.pending(),
        PurchasesErrorCode.productAlreadyPurchasedError =>
          PurchaseResult.failed(
            'You already own this plan. Try "Restore purchases".',
          ),
        PurchasesErrorCode.networkError => PurchaseResult.failed(
            'No connection. Check your network and try again.',
          ),
        PurchasesErrorCode.storeProblemError => PurchaseResult.failed(
            'The store is having trouble. Please try again shortly.',
          ),
        PurchasesErrorCode.purchaseNotAllowedError => PurchaseResult.failed(
            'Purchases are not allowed on this device.',
          ),
        _ => PurchaseResult.failed(
            e.message ?? 'The purchase could not be completed.',
          ),
      };
    } catch (e) {
      debugPrint('RevenueCat purchase failed: $e');
      return PurchaseResult.failed('The purchase could not be completed.');
    }
  }

  @override
  Future<PurchaseResult> restore() async {
    if (!_available) {
      return PurchaseResult.failed('In-app purchases are unavailable.');
    }
    try {
      final CustomerInfo info = await Purchases.restorePurchases();
      final Entitlements ent = _toEntitlements(info);
      if (!ent.tier.isPaid) {
        return PurchaseResult.failed(
          'No previous purchases were found for this account.',
        );
      }
      return PurchaseResult.success(ent);
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
      return PurchaseResult.failed('Could not restore purchases.');
    }
  }

  // ---- Translation ------------------------------------------------------

  /// Maps RevenueCat's [CustomerInfo] onto the app's [Entitlements].
  ///
  /// Checks the highest tier first so a Business subscriber is never reported
  /// as Pro just because both entitlements happen to be active.
  Entitlements _toEntitlements(CustomerInfo info) {
    for (final SubscriptionTier tier in <SubscriptionTier>[
      SubscriptionTier.business,
      SubscriptionTier.pro,
    ]) {
      final EntitlementInfo? e = info.entitlements.all[tier.entitlementId];
      if (e == null || !e.isActive) continue;

      final DateTime? expires = _parse(e.expirationDate);
      final bool trial = e.periodType == PeriodType.trial;

      return Entitlements(
        tier: tier,
        status: _status(e, expires, trial),
        period: _period(e),
        expiresAt: expires,
        trialEndsAt: trial ? expires : null,
        willRenew: e.willRenew,
        managementUrl: info.managementURL,
      );
    }
    return Entitlements.free;
  }

  SubscriptionStatus _status(
    EntitlementInfo e,
    DateTime? expires,
    bool trial,
  ) {
    if (e.billingIssueDetectedAt != null) {
      return SubscriptionStatus.gracePeriod;
    }
    if (trial) return SubscriptionStatus.trialing;
    if (!e.willRenew) {
      // Cancelled but still inside the paid term keeps access until expiry.
      if (expires != null && expires.isAfter(DateTime.now())) {
        return SubscriptionStatus.cancelled;
      }
      return SubscriptionStatus.expired;
    }
    return SubscriptionStatus.active;
  }

  BillingPeriod? _period(EntitlementInfo e) {
    final String id = e.productIdentifier.toLowerCase();
    if (id.contains('year') || id.contains('annual')) return BillingPeriod.yearly;
    if (id.contains('month')) return BillingPeriod.monthly;
    return null;
  }

  SubscriptionOffer? _toOffer(Package pkg) {
    final StoreProduct p = pkg.storeProduct;
    final String id = p.identifier.toLowerCase();

    final SubscriptionTier tier = id.contains('business')
        ? SubscriptionTier.business
        : id.contains('pro')
            ? SubscriptionTier.pro
            : SubscriptionTier.free;
    if (!tier.isPaid) return null;

    final BillingPeriod period =
        (id.contains('year') || id.contains('annual') ||
                pkg.packageType == PackageType.annual)
            ? BillingPeriod.yearly
            : BillingPeriod.monthly;

    return SubscriptionOffer(
      identifier: p.identifier,
      tier: tier,
      period: period,
      priceString: p.priceString,
      rawPrice: p.price,
      introOfferDays: _trialDays(p),
    );
  }

  /// Reads the introductory free-trial length, if the product has one.
  int? _trialDays(StoreProduct product) {
    final IntroductoryPrice? intro = product.introductoryPrice;
    if (intro == null || intro.price != 0) return null;
    return switch (intro.periodUnit) {
      PeriodUnit.day => intro.periodNumberOfUnits,
      PeriodUnit.week => intro.periodNumberOfUnits * 7,
      PeriodUnit.month => intro.periodNumberOfUnits * 30,
      PeriodUnit.year => intro.periodNumberOfUnits * 365,
      _ => null,
    };
  }

  DateTime? _parse(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso)?.toLocal();

  @override
  void dispose() {
    if (_listener != null && _available) {
      Purchases.removeCustomerInfoUpdateListener(_listener!);
    }
    _controller.close();
  }
}

/// Platforms where a store is actually present.
bool get billingPlatformSupported {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}
