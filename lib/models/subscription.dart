import 'package:flutter/material.dart';

import '../core/utils/firestore_utils.dart';

/// The subscription tiers offered by the app.
///
/// Order matters: [index] is used for `>=` comparisons when checking whether
/// the active tier meets a feature's minimum requirement, so tiers must be
/// declared cheapest-first.
enum SubscriptionTier {
  free(
    id: 'free',
    label: 'Free',
    tagline: 'Get started at no cost',
    monthlyPrice: 0,
    yearlyPrice: 0,
  ),
  pro(
    id: 'pro',
    label: 'Pro',
    tagline: 'For the working builder',
    monthlyPrice: 9.99,
    yearlyPrice: 99,
  ),
  business(
    id: 'business',
    label: 'Business',
    tagline: 'For growing teams',
    monthlyPrice: 24.99,
    yearlyPrice: 249,
  );

  const SubscriptionTier({
    required this.id,
    required this.label,
    required this.tagline,
    required this.monthlyPrice,
    required this.yearlyPrice,
  });

  final String id;
  final String label;
  final String tagline;

  /// Reference pricing in GBP, shown before the store's live prices load.
  /// The store is always the source of truth for what the user is charged.
  final double monthlyPrice;
  final double yearlyPrice;

  bool get isPaid => this != SubscriptionTier.free;

  /// Percentage saved by paying yearly instead of monthly.
  int get yearlySavingPercent {
    if (monthlyPrice <= 0) return 0;
    final double full = monthlyPrice * 12;
    return (((full - yearlyPrice) / full) * 100).round();
  }

  /// True when this tier is at least as capable as [required].
  bool meets(SubscriptionTier required) => index >= required.index;

  static SubscriptionTier fromId(String? id) => SubscriptionTier.values
      .firstWhere((SubscriptionTier t) => t.id == id,
          orElse: () => SubscriptionTier.free);

  /// RevenueCat entitlement identifier. Configure these in the RevenueCat
  /// dashboard to match exactly.
  String get entitlementId => switch (this) {
        SubscriptionTier.free => '',
        SubscriptionTier.pro => 'pro',
        SubscriptionTier.business => 'business',
      };

  IconData get icon => switch (this) {
        SubscriptionTier.free => Icons.person_outline,
        SubscriptionTier.pro => Icons.workspace_premium_outlined,
        SubscriptionTier.business => Icons.apartment_outlined,
      };
}

/// Billing cadence for a paid tier.
enum BillingPeriod {
  monthly('Monthly', 'month'),
  yearly('Yearly', 'year');

  const BillingPeriod(this.label, this.unit);
  final String label;
  final String unit;
}

/// Lifecycle state of the user's subscription.
enum SubscriptionStatus {
  /// Never subscribed, or the trial has not been started.
  none('Free'),

  /// In an active introductory trial.
  trialing('Trial'),

  /// Paid and current.
  active('Active'),

  /// Payment failed; store is retrying. Access is retained during the grace
  /// period so a failed card does not lock a builder out mid-job.
  gracePeriod('Payment issue'),

  /// Cancelled but still within the paid term.
  cancelled('Cancelled'),

  /// Term ended — no paid access.
  expired('Expired');

  const SubscriptionStatus(this.label);
  final String label;

  /// Whether this status should grant paid features.
  bool get grantsAccess =>
      this == SubscriptionStatus.trialing ||
      this == SubscriptionStatus.active ||
      this == SubscriptionStatus.gracePeriod ||
      this == SubscriptionStatus.cancelled;

  static SubscriptionStatus fromName(String? name) =>
      SubscriptionStatus.values.firstWhere(
        (SubscriptionStatus s) => s.name == name,
        orElse: () => SubscriptionStatus.none,
      );
}

/// Every gate-able capability in the app.
///
/// Adding a feature here and to [Entitlements.minimumTier] is the only change
/// needed to gate it — no scattered tier comparisons at call sites.
enum PaidFeature {
  unlimitedCustomers,
  unlimitedJobs,
  unlimitedDocuments,
  unlimitedPhotos,
  cleanPdf,
  customBranding,
  advancedDashboard,
  reports,
  dataExport,
  documentStorage,
  recurringInvoices,
  automaticReminders,
  teamSeats,
  prioritySupport,
}

/// Hard caps applied to the Free tier.
///
/// Reads are never limited — only creation. A user who downgrades keeps full
/// access to everything they already made.
class UsageLimits {
  const UsageLimits({
    required this.customers,
    required this.jobs,
    required this.documents,
    required this.photos,
    required this.storedFiles,
  });

  /// Maximum number of customers that may exist.
  final int customers;

  /// Maximum number of jobs.
  final int jobs;

  /// Combined invoices + quotes.
  final int documents;

  /// Total job photos across all jobs.
  final int photos;

  /// Attached files in the Documents section.
  final int storedFiles;

  /// Sentinel meaning "no limit".
  static const int unlimited = -1;

  static const UsageLimits freeTier = UsageLimits(
    customers: 5,
    jobs: 5,
    documents: 5,
    photos: 10,
    storedFiles: 0,
  );

  static const UsageLimits unlimitedTier = UsageLimits(
    customers: unlimited,
    jobs: unlimited,
    documents: unlimited,
    photos: unlimited,
    storedFiles: unlimited,
  );

  static UsageLimits forTier(SubscriptionTier tier) =>
      tier == SubscriptionTier.free ? freeTier : unlimitedTier;

  bool isUnlimited(int limit) => limit == unlimited;
}

/// A countable resource that the Free tier caps.
enum LimitedResource {
  customers('customers', 'Customer', 'customers'),
  jobs('jobs', 'Job', 'jobs'),
  documents('documents', 'Invoice or quote', 'invoices and quotes'),
  photos('photos', 'Photo', 'job photos'),
  storedFiles('storedFiles', 'Document', 'stored documents');

  const LimitedResource(this.id, this.singular, this.plural);
  final String id;
  final String singular;
  final String plural;

  int limitIn(UsageLimits limits) => switch (this) {
        LimitedResource.customers => limits.customers,
        LimitedResource.jobs => limits.jobs,
        LimitedResource.documents => limits.documents,
        LimitedResource.photos => limits.photos,
        LimitedResource.storedFiles => limits.storedFiles,
      };
}

/// The resolved capability set for the signed-in user.
///
/// This is what the UI asks — never the raw tier — so gating logic lives in
/// one place and stays testable.
class Entitlements {
  const Entitlements({
    required this.tier,
    required this.status,
    this.period,
    this.expiresAt,
    this.trialEndsAt,
    this.willRenew = false,
    this.managementUrl,
    this.isFromCache = false,
  });

  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final BillingPeriod? period;
  final DateTime? expiresAt;
  final DateTime? trialEndsAt;
  final bool willRenew;

  /// Deep link to the store's subscription management page.
  final String? managementUrl;

  /// True when this came from the Firestore cache rather than a live store
  /// check — used to decide whether to show a "syncing" hint.
  final bool isFromCache;

  /// Safe default before anything has loaded. Fails closed: never assume paid.
  static const Entitlements free = Entitlements(
    tier: SubscriptionTier.free,
    status: SubscriptionStatus.none,
  );

  /// The tier actually in force right now. A cancelled-but-not-yet-expired
  /// subscription still grants its tier; an expired one does not.
  SubscriptionTier get effectiveTier =>
      status.grantsAccess ? tier : SubscriptionTier.free;

  bool get isPaid => effectiveTier.isPaid;
  bool get isTrialing => status == SubscriptionStatus.trialing;
  bool get hasBillingProblem => status == SubscriptionStatus.gracePeriod;

  /// Days left in the trial, or null when not trialing.
  int? get trialDaysRemaining {
    if (!isTrialing || trialEndsAt == null) return null;
    final int days = trialEndsAt!.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  /// The minimum tier required for each feature. This table *is* the pricing
  /// model — change it here and the whole app follows.
  static SubscriptionTier minimumTier(PaidFeature feature) => switch (feature) {
        PaidFeature.unlimitedCustomers ||
        PaidFeature.unlimitedJobs ||
        PaidFeature.unlimitedDocuments ||
        PaidFeature.unlimitedPhotos ||
        PaidFeature.cleanPdf ||
        PaidFeature.advancedDashboard ||
        PaidFeature.reports ||
        PaidFeature.dataExport ||
        PaidFeature.documentStorage =>
          SubscriptionTier.pro,
        PaidFeature.customBranding ||
        PaidFeature.recurringInvoices ||
        PaidFeature.automaticReminders ||
        PaidFeature.teamSeats ||
        PaidFeature.prioritySupport =>
          SubscriptionTier.business,
      };

  /// The single question the UI asks.
  bool has(PaidFeature feature) =>
      effectiveTier.meets(minimumTier(feature));

  UsageLimits get limits => UsageLimits.forTier(effectiveTier);

  Entitlements copyWith({
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    BillingPeriod? period,
    DateTime? expiresAt,
    DateTime? trialEndsAt,
    bool? willRenew,
    String? managementUrl,
    bool? isFromCache,
  }) {
    return Entitlements(
      tier: tier ?? this.tier,
      status: status ?? this.status,
      period: period ?? this.period,
      expiresAt: expiresAt ?? this.expiresAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      willRenew: willRenew ?? this.willRenew,
      managementUrl: managementUrl ?? this.managementUrl,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  factory Entitlements.fromMap(Map<String, dynamic> map) {
    return Entitlements(
      tier: SubscriptionTier.fromId(asString(map['tier'])),
      status: SubscriptionStatus.fromName(asString(map['status'])),
      period: map['period'] == null
          ? null
          : BillingPeriod.values.firstWhere(
              (BillingPeriod p) => p.name == map['period'],
              orElse: () => BillingPeriod.monthly,
            ),
      expiresAt: tsToDate(map['expiresAt']),
      trialEndsAt: tsToDate(map['trialEndsAt']),
      willRenew: asBool(map['willRenew']),
      managementUrl: map['managementUrl'] as String?,
      isFromCache: true,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'tier': tier.id,
        'status': status.name,
        'period': period?.name,
        'expiresAt': dateToTs(expiresAt),
        'trialEndsAt': dateToTs(trialEndsAt),
        'willRenew': willRenew,
        'managementUrl': managementUrl,
        'syncedAt': dateToTs(DateTime.now()),
      };

  @override
  bool operator ==(Object other) =>
      other is Entitlements &&
      other.tier == tier &&
      other.status == status &&
      other.period == period &&
      other.expiresAt == expiresAt &&
      other.willRenew == willRenew;

  @override
  int get hashCode => Object.hash(tier, status, period, expiresAt, willRenew);

  @override
  String toString() => 'Entitlements(${tier.id}, ${status.name})';
}

/// A purchasable package as offered by the store.
///
/// Wraps the store SDK's package so the paywall never imports RevenueCat types
/// directly — which is what keeps widget tests free of the billing SDK.
class SubscriptionOffer {
  const SubscriptionOffer({
    required this.identifier,
    required this.tier,
    required this.period,
    required this.priceString,
    required this.rawPrice,
    this.introOfferDays,
  });

  /// Store product identifier, passed back to [BillingService.purchase].
  final String identifier;
  final SubscriptionTier tier;
  final BillingPeriod period;

  /// Localised price string from the store, e.g. `£9.99`. Always prefer this
  /// over formatting [rawPrice] yourself — the store knows the user's currency.
  final String priceString;
  final double rawPrice;

  /// Length of any introductory free trial attached to this package.
  final int? introOfferDays;

  bool get hasTrial => (introOfferDays ?? 0) > 0;

  /// Approximate per-month cost, for showing "£8.25/month billed yearly".
  double get monthlyEquivalent =>
      period == BillingPeriod.yearly ? rawPrice / 12 : rawPrice;
}

/// The result of a purchase attempt.
class PurchaseResult {
  const PurchaseResult._(this.outcome, {this.entitlements, this.message});

  final PurchaseOutcome outcome;
  final Entitlements? entitlements;
  final String? message;

  factory PurchaseResult.success(Entitlements entitlements) =>
      PurchaseResult._(PurchaseOutcome.success, entitlements: entitlements);

  factory PurchaseResult.cancelled() =>
      const PurchaseResult._(PurchaseOutcome.cancelled);

  factory PurchaseResult.failed(String message) =>
      PurchaseResult._(PurchaseOutcome.failed, message: message);

  factory PurchaseResult.pending() =>
      const PurchaseResult._(PurchaseOutcome.pending);

  bool get isSuccess => outcome == PurchaseOutcome.success;
}

enum PurchaseOutcome { success, cancelled, failed, pending }
