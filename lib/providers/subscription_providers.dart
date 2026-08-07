import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/billing_config.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';
import '../services/billing_service.dart';
import '../services/revenuecat_billing_service.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'data_providers.dart';

// ---------------------------------------------------------------------------
// Service composition
// ---------------------------------------------------------------------------

/// Chooses the real billing service when a store key is configured, and the
/// mock otherwise. This is what lets the app run in CI, on desktop, and before
/// store products exist — without a single `if (kDebugMode)` at a call site.
final billingServiceProvider = Provider<BillingService>((ref) {
  final BillingService service =
      BillingConfig.isConfigured && billingPlatformSupported
          ? RevenueCatBillingService()
          : MockBillingService();

  ref.onDispose(service.dispose);
  return service;
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository?>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return SubscriptionRepository(ref.watch(firestoreProvider), uid);
});

/// Boots the billing SDK and keeps its identity in sync with Firebase Auth.
///
/// Identity matters: without it, purchases are tied to an anonymous store user
/// and are lost when the customer reinstalls or switches device.
final billingBootstrapProvider = FutureProvider<void>((ref) async {
  final BillingService billing = ref.watch(billingServiceProvider);
  final String? uid = ref.watch(currentUidProvider);

  await billing.initialise(appUserId: uid);
  if (uid != null) {
    await billing.identify(uid);
  } else {
    await billing.logOut();
  }
});

// ---------------------------------------------------------------------------
// Entitlements
// ---------------------------------------------------------------------------

/// The authoritative entitlement stream, merging the store with the Firestore
/// cache.
///
/// Resolution order:
///   1. emit the cached tier immediately (no Free→Pro flash at cold start),
///   2. emit whatever the store reports as soon as it answers,
///   3. write the store's answer back to the cache.
///
/// If the store and cache disagree, the store wins — always.
final entitlementsProvider = StreamProvider<Entitlements>((ref) {
  final BillingService billing = ref.watch(billingServiceProvider);
  final SubscriptionRepository? repo = ref.watch(subscriptionRepositoryProvider);

  // Ensure the SDK is configured before we subscribe to it.
  ref.watch(billingBootstrapProvider);

  final StreamController<Entitlements> out =
      StreamController<Entitlements>.broadcast();
  Entitlements last = Entitlements.free;

  void emit(Entitlements value) {
    if (out.isClosed) return;
    last = value;
    out.add(value);
  }

  // 1 — cached value first.
  StreamSubscription<Entitlements>? cacheSub;
  if (repo != null) {
    cacheSub = repo.watch().listen((Entitlements cached) {
      // Only let the cache speak while the store has not yet answered.
      if (last == Entitlements.free && cached != Entitlements.free) {
        emit(cached.copyWith(isFromCache: true));
      }
    });
  }

  // 2 — store stream is authoritative.
  final StreamSubscription<Entitlements> storeSub =
      billing.watchEntitlements().listen((Entitlements live) {
    emit(live);
    // 3 — mirror to the cache for the next cold start / offline session.
    repo?.cache(live);
  });

  // Kick off an immediate read rather than waiting for the first push.
  unawaited(billing.fetchEntitlements().then((Entitlements live) {
    emit(live);
    repo?.cache(live);
  }).catchError((_) {}));

  ref.onDispose(() {
    cacheSub?.cancel();
    storeSub.cancel();
    out.close();
  });

  return out.stream;
});

/// Synchronous entitlements for widgets that cannot await.
///
/// Defaults to [Entitlements.free] — gating always fails closed, so a loading
/// state never accidentally unlocks a paid feature.
final currentEntitlementsProvider = Provider<Entitlements>((ref) {
  return ref.watch(entitlementsProvider).valueOrNull ?? Entitlements.free;
});

/// The tier actually in force.
final currentTierProvider = Provider<SubscriptionTier>((ref) {
  return ref.watch(currentEntitlementsProvider).effectiveTier;
});

/// Whether the user has a given capability. The single question the UI asks.
final hasFeatureProvider = Provider.family<bool, PaidFeature>((ref, feature) {
  return ref.watch(currentEntitlementsProvider).has(feature);
});

/// Purchasable packages, refreshed when the store connection changes.
final subscriptionOffersProvider =
    FutureProvider<List<SubscriptionOffer>>((ref) async {
  await ref.watch(billingBootstrapProvider.future);
  return ref.watch(billingServiceProvider).fetchOffers();
});

/// Whether a paywall can meaningfully be shown at all.
final billingAvailableProvider = Provider<bool>((ref) {
  ref.watch(billingBootstrapProvider);
  return ref.watch(billingServiceProvider).isAvailable;
});

// ---------------------------------------------------------------------------
// Usage counting & limit enforcement
// ---------------------------------------------------------------------------

/// Live counts of every limited resource.
///
/// Counts come from the already-streamed collections, so this costs no extra
/// Firestore reads.
class UsageSnapshot {
  const UsageSnapshot({
    this.customers = 0,
    this.jobs = 0,
    this.documents = 0,
    this.photos = 0,
    this.storedFiles = 0,
  });

  final int customers;
  final int jobs;

  /// Invoices + quotes combined.
  final int documents;
  final int photos;
  final int storedFiles;

  int countOf(LimitedResource resource) => switch (resource) {
        LimitedResource.customers => customers,
        LimitedResource.jobs => jobs,
        LimitedResource.documents => documents,
        LimitedResource.photos => photos,
        LimitedResource.storedFiles => storedFiles,
      };
}

final usageProvider = Provider<UsageSnapshot>((ref) {
  return UsageSnapshot(
    customers: ref.watch(customersProvider).valueOrNull?.length ?? 0,
    jobs: ref.watch(jobsProvider).valueOrNull?.length ?? 0,
    documents: (ref.watch(invoicesProvider).valueOrNull?.length ?? 0) +
        (ref.watch(quotesProvider).valueOrNull?.length ?? 0),
    storedFiles: ref.watch(documentsProvider).valueOrNull?.length ?? 0,
  );
});

/// The outcome of asking "may the user create another one of these?".
class LimitCheck {
  const LimitCheck({
    required this.allowed,
    required this.resource,
    required this.used,
    required this.limit,
  });

  final bool allowed;
  final LimitedResource resource;
  final int used;

  /// [UsageLimits.unlimited] when uncapped.
  final int limit;

  bool get isUnlimited => limit == UsageLimits.unlimited;
  int get remaining => isUnlimited ? 1 << 30 : (limit - used).clamp(0, limit);

  /// 0..1 progress toward the cap, for the usage meter.
  double get fraction =>
      isUnlimited || limit <= 0 ? 0 : (used / limit).clamp(0, 1).toDouble();

  /// True when the user is one away from the cap — the right moment for a
  /// gentle nudge rather than a hard block.
  bool get isNearLimit => !isUnlimited && remaining <= 1 && allowed;

  String get blockedMessage =>
      'Your Free plan includes $limit ${resource.plural}. '
      'Upgrade to Pro for unlimited ${resource.plural}.';
}

/// Whether another [LimitedResource] may be created right now.
///
/// Deliberately only gates *creation*. Existing records stay fully readable and
/// editable at any tier — locking people out of their own data is how apps earn
/// one-star reviews.
final canCreateProvider =
    Provider.family<LimitCheck, LimitedResource>((ref, resource) {
  final Entitlements ent = ref.watch(currentEntitlementsProvider);
  final UsageSnapshot usage = ref.watch(usageProvider);

  final int limit = resource.limitIn(ent.limits);
  final int used = usage.countOf(resource);

  if (limit == UsageLimits.unlimited) {
    return LimitCheck(
      allowed: true,
      resource: resource,
      used: used,
      limit: UsageLimits.unlimited,
    );
  }

  return LimitCheck(
    allowed: used < limit,
    resource: resource,
    used: used,
    limit: limit,
  );
});

// ---------------------------------------------------------------------------
// Purchase controller
// ---------------------------------------------------------------------------

/// Drives purchase and restore from the paywall, exposing a busy/error state.
class PurchaseController extends StateNotifier<AsyncValue<PurchaseResult?>> {
  PurchaseController(this._billing, this._repo)
      : super(const AsyncValue<PurchaseResult?>.data(null));

  final BillingService _billing;
  final SubscriptionRepository? _repo;

  Future<PurchaseResult> buy(SubscriptionOffer offer) async {
    state = const AsyncValue<PurchaseResult?>.loading();
    try {
      final PurchaseResult result = await _billing.purchase(offer);
      if (result.isSuccess && result.entitlements != null) {
        await _repo?.cache(result.entitlements!);
      }
      state = AsyncValue<PurchaseResult?>.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue<PurchaseResult?>.error(e, st);
      return PurchaseResult.failed('The purchase could not be completed.');
    }
  }

  Future<PurchaseResult> restore() async {
    state = const AsyncValue<PurchaseResult?>.loading();
    try {
      final PurchaseResult result = await _billing.restore();
      if (result.isSuccess && result.entitlements != null) {
        await _repo?.cache(result.entitlements!);
      }
      state = AsyncValue<PurchaseResult?>.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue<PurchaseResult?>.error(e, st);
      return PurchaseResult.failed('Could not restore purchases.');
    }
  }

  void reset() => state = const AsyncValue<PurchaseResult?>.data(null);
}

final purchaseControllerProvider = StateNotifierProvider<PurchaseController,
    AsyncValue<PurchaseResult?>>((ref) {
  return PurchaseController(
    ref.watch(billingServiceProvider),
    ref.watch(subscriptionRepositoryProvider),
  );
});

/// Selected billing period on the paywall.
final paywallPeriodProvider =
    StateProvider<BillingPeriod>((ref) => BillingPeriod.yearly);
