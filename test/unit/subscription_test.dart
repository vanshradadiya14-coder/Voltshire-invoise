import 'package:builder_crm/models/subscription.dart';
import 'package:builder_crm/services/billing_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Entitlement logic decides who can use what. A bug that fails *open* gives
/// the product away; one that fails *closed* locks out a paying customer.
/// Both directions are tested.
void main() {
  group('tier ordering', () {
    test('meets() is inclusive and ordered', () {
      expect(SubscriptionTier.business.meets(SubscriptionTier.pro), isTrue);
      expect(SubscriptionTier.pro.meets(SubscriptionTier.pro), isTrue);
      expect(SubscriptionTier.pro.meets(SubscriptionTier.business), isFalse);
      expect(SubscriptionTier.free.meets(SubscriptionTier.pro), isFalse);
    });

    test('only paid tiers report isPaid', () {
      expect(SubscriptionTier.free.isPaid, isFalse);
      expect(SubscriptionTier.pro.isPaid, isTrue);
      expect(SubscriptionTier.business.isPaid, isTrue);
    });

    test('yearly saving is computed from the monthly price', () {
      // £9.99 × 12 = £119.88 vs £99 → ~17%.
      expect(SubscriptionTier.pro.yearlySavingPercent, 17);
      expect(SubscriptionTier.free.yearlySavingPercent, 0);
    });

    test('unknown ids fall back to free, never to a paid tier', () {
      expect(SubscriptionTier.fromId('enterprise'), SubscriptionTier.free);
      expect(SubscriptionTier.fromId(null), SubscriptionTier.free);
      expect(SubscriptionTier.fromId(''), SubscriptionTier.free);
    });
  });

  group('status grants access', () {
    test('active, trialing, grace and cancelled all retain access', () {
      expect(SubscriptionStatus.active.grantsAccess, isTrue);
      expect(SubscriptionStatus.trialing.grantsAccess, isTrue);
      // A failed card must not lock a builder out mid-job.
      expect(SubscriptionStatus.gracePeriod.grantsAccess, isTrue);
      // Cancelled but still inside the paid term.
      expect(SubscriptionStatus.cancelled.grantsAccess, isTrue);
    });

    test('expired and none do not', () {
      expect(SubscriptionStatus.expired.grantsAccess, isFalse);
      expect(SubscriptionStatus.none.grantsAccess, isFalse);
    });
  });

  group('effective tier', () {
    test('an expired Pro subscription drops to free', () {
      const Entitlements e = Entitlements(
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.expired,
      );
      expect(e.effectiveTier, SubscriptionTier.free);
      expect(e.isPaid, isFalse);
      expect(e.has(PaidFeature.reports), isFalse);
    });

    test('a cancelled but unexpired subscription keeps its tier', () {
      const Entitlements e = Entitlements(
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.cancelled,
      );
      expect(e.effectiveTier, SubscriptionTier.pro);
      expect(e.has(PaidFeature.reports), isTrue);
    });

    test('the default is free — gating fails closed', () {
      expect(Entitlements.free.effectiveTier, SubscriptionTier.free);
      for (final PaidFeature f in PaidFeature.values) {
        expect(Entitlements.free.has(f), isFalse,
            reason: '$f must not be available on the free default');
      }
    });
  });

  group('feature matrix', () {
    const Entitlements pro = Entitlements(
      tier: SubscriptionTier.pro,
      status: SubscriptionStatus.active,
    );
    const Entitlements business = Entitlements(
      tier: SubscriptionTier.business,
      status: SubscriptionStatus.active,
    );

    test('Pro unlocks the Pro set but not the Business set', () {
      expect(pro.has(PaidFeature.reports), isTrue);
      expect(pro.has(PaidFeature.cleanPdf), isTrue);
      expect(pro.has(PaidFeature.advancedDashboard), isTrue);
      expect(pro.has(PaidFeature.dataExport), isTrue);

      expect(pro.has(PaidFeature.recurringInvoices), isFalse);
      expect(pro.has(PaidFeature.teamSeats), isFalse);
      expect(pro.has(PaidFeature.customBranding), isFalse);
    });

    test('Business unlocks everything', () {
      for (final PaidFeature f in PaidFeature.values) {
        expect(business.has(f), isTrue, reason: '$f should be in Business');
      }
    });
  });

  group('usage limits', () {
    test('free tier is capped, paid tiers are not', () {
      expect(UsageLimits.forTier(SubscriptionTier.free).customers, 5);
      expect(UsageLimits.forTier(SubscriptionTier.pro).customers,
          UsageLimits.unlimited);
      expect(UsageLimits.forTier(SubscriptionTier.business).documents,
          UsageLimits.unlimited);
    });

    test('every limited resource resolves a limit for both tiers', () {
      for (final LimitedResource r in LimitedResource.values) {
        expect(r.limitIn(UsageLimits.freeTier), isNot(0),
            reason: '${r.id} free limit should be set (0 is likely a mistake)');
        expect(r.limitIn(UsageLimits.unlimitedTier), UsageLimits.unlimited);
      }
    });
  });

  group('trial countdown', () {
    test('reports days remaining while trialing', () {
      final Entitlements e = Entitlements(
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.trialing,
        trialEndsAt: DateTime.now().add(const Duration(days: 7, hours: 1)),
      );
      expect(e.isTrialing, isTrue);
      expect(e.trialDaysRemaining, 7);
    });

    test('never goes negative', () {
      final Entitlements e = Entitlements(
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.trialing,
        trialEndsAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(e.trialDaysRemaining, 0);
    });

    test('is null when not trialing', () {
      const Entitlements e = Entitlements(
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.active,
      );
      expect(e.trialDaysRemaining, isNull);
    });
  });

  group('serialisation round-trip', () {
    test('survives a Firestore write and read', () {
      final Entitlements original = Entitlements(
        tier: SubscriptionTier.business,
        status: SubscriptionStatus.active,
        period: BillingPeriod.yearly,
        expiresAt: DateTime(2027, 3, 15),
        willRenew: true,
      );
      // toMap uses Timestamp; simulate the read side with plain DateTimes,
      // which tsToDate also accepts.
      final Map<String, dynamic> map = <String, dynamic>{
        'tier': original.tier.id,
        'status': original.status.name,
        'period': original.period?.name,
        'expiresAt': original.expiresAt,
        'willRenew': original.willRenew,
      };
      final Entitlements restored = Entitlements.fromMap(map);

      expect(restored.tier, original.tier);
      expect(restored.status, original.status);
      expect(restored.period, original.period);
      expect(restored.expiresAt, original.expiresAt);
      expect(restored.willRenew, isTrue);
      expect(restored.isFromCache, isTrue);
    });

    test('a corrupt document degrades to free rather than throwing', () {
      final Entitlements e = Entitlements.fromMap(<String, dynamic>{
        'tier': 'platinum',
        'status': 'wobbly',
        'expiresAt': 'not a date',
      });
      expect(e.tier, SubscriptionTier.free);
      expect(e.status, SubscriptionStatus.none);
      expect(e.isPaid, isFalse);
    });
  });

  group('MockBillingService', () {
    late MockBillingService billing;

    setUp(() => billing = MockBillingService());
    tearDown(() => billing.dispose());

    test('starts free', () async {
      expect((await billing.fetchEntitlements()).isPaid, isFalse);
    });

    test('a purchase grants the tier and starts a trial', () async {
      final List<SubscriptionOffer> offers = await billing.fetchOffers();
      final SubscriptionOffer proYearly = offers.firstWhere(
        (SubscriptionOffer o) =>
            o.tier == SubscriptionTier.pro && o.period == BillingPeriod.yearly,
      );

      final PurchaseResult result = await billing.purchase(proYearly);
      expect(result.isSuccess, isTrue);
      expect(result.entitlements!.tier, SubscriptionTier.pro);
      expect(result.entitlements!.status, SubscriptionStatus.trialing);
      expect(billing.current.has(PaidFeature.reports), isTrue);
    });

    test('a cancelled purchase changes nothing', () async {
      billing.shouldCancelPurchase = true;
      final List<SubscriptionOffer> offers = await billing.fetchOffers();
      final PurchaseResult r = await billing.purchase(offers.first);

      expect(r.outcome, PurchaseOutcome.cancelled);
      expect(r.isSuccess, isFalse);
      expect(billing.current.isPaid, isFalse);
    });

    test('a failed purchase surfaces a message and grants nothing', () async {
      billing.shouldFailPurchase = true;
      final List<SubscriptionOffer> offers = await billing.fetchOffers();
      final PurchaseResult r = await billing.purchase(offers.first);

      expect(r.outcome, PurchaseOutcome.failed);
      expect(r.message, isNotNull);
      expect(billing.current.isPaid, isFalse);
    });

    test('restore fails when there is nothing to restore', () async {
      expect((await billing.restore()).isSuccess, isFalse);
    });

    test('signing out clears entitlements on a shared device', () async {
      final List<SubscriptionOffer> offers = await billing.fetchOffers();
      await billing.purchase(offers.first);
      expect(billing.current.isPaid, isTrue);

      await billing.logOut();
      expect(billing.current.isPaid, isFalse);
    });

    test('entitlement changes are streamed', () async {
      final Future<Entitlements> next = billing.watchEntitlements().first;
      billing.setEntitlements(const Entitlements(
        tier: SubscriptionTier.business,
        status: SubscriptionStatus.active,
      ));
      expect((await next).tier, SubscriptionTier.business);
    });

    test('offers cover both tiers and both periods', () async {
      final List<SubscriptionOffer> offers = await billing.fetchOffers();
      for (final SubscriptionTier t in <SubscriptionTier>[
        SubscriptionTier.pro,
        SubscriptionTier.business,
      ]) {
        for (final BillingPeriod p in BillingPeriod.values) {
          expect(
            offers.any((SubscriptionOffer o) => o.tier == t && o.period == p),
            isTrue,
            reason: 'missing offer for ${t.id} ${p.name}',
          );
        }
      }
    });

    test('yearly monthlyEquivalent divides by twelve', () async {
      final List<SubscriptionOffer> offers = await billing.fetchOffers();
      final SubscriptionOffer yearly = offers.firstWhere(
        (SubscriptionOffer o) =>
            o.tier == SubscriptionTier.pro && o.period == BillingPeriod.yearly,
      );
      expect(yearly.monthlyEquivalent, closeTo(99 / 12, 0.001));
    });
  });
}
