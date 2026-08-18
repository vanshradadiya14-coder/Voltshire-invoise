import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/invoice.dart';
import '../models/job.dart';
import '../models/payment_stage.dart';
import '../models/price_item.dart';
import '../models/quote.dart';
import '../models/trade_enums.dart';
import '../models/variation.dart';
import '../repositories/payment_stage_repository.dart';
import '../repositories/price_item_repository.dart';
import '../repositories/variation_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'data_providers.dart';

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------
//
// Nullable rather than throwing when signed out. These are read from widgets
// that can briefly build during sign-out, and a thrown StateError there would
// surface as a red screen for a fraction of a second.

final priceItemRepositoryProvider = Provider<PriceItemRepository?>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return PriceItemRepository(ref.watch(firestoreProvider), uid);
});

final variationRepositoryProvider = Provider<VariationRepository?>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return VariationRepository(ref.watch(firestoreProvider), uid);
});

final paymentStageRepositoryProvider =
    Provider<PaymentStageRepository?>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return PaymentStageRepository(ref.watch(firestoreProvider), uid);
});

// ---------------------------------------------------------------------------
// Price list
// ---------------------------------------------------------------------------

final priceItemsProvider = StreamProvider<List<PriceItem>>((ref) {
  final PriceItemRepository? repo = ref.watch(priceItemRepositoryProvider);
  if (repo == null) return Stream<List<PriceItem>>.value(const <PriceItem>[]);
  return repo.watchAll();
});

/// Free-text filter over the price list.
final priceSearchTermProvider = StateProvider<String>((ref) => '');

/// Category filter, or null for all.
final priceCategoryFilterProvider =
    StateProvider<LineCategory?>((ref) => null);

final filteredPriceItemsProvider = Provider<List<PriceItem>>((ref) {
  final List<PriceItem> all =
      ref.watch(priceItemsProvider).valueOrNull ?? const <PriceItem>[];
  final String term = ref.watch(priceSearchTermProvider).trim().toLowerCase();
  final LineCategory? category = ref.watch(priceCategoryFilterProvider);

  return all.where((PriceItem p) {
    if (category != null && p.category != category) return false;
    if (term.isEmpty) return true;
    return p.searchText.contains(term);
  }).toList();
});

/// Seeds the starter price list the first time the list is opened and found
/// empty. Runs once per session; failures are silent because an empty price
/// list is a degraded experience, not a broken one.
final priceListSeedProvider = FutureProvider<int>((ref) async {
  final PriceItemRepository? repo = ref.watch(priceItemRepositoryProvider);
  if (repo == null) return 0;
  try {
    return await repo.seedDefaults();
  } catch (_) {
    return 0;
  }
});

// ---------------------------------------------------------------------------
// Variations
// ---------------------------------------------------------------------------

final variationsProvider = StreamProvider<List<Variation>>((ref) {
  final VariationRepository? repo = ref.watch(variationRepositoryProvider);
  if (repo == null) return Stream<List<Variation>>.value(const <Variation>[]);
  return repo.watchAll();
});

final variationsForJobProvider =
    StreamProvider.family<List<Variation>, String>((ref, String jobId) {
  final VariationRepository? repo = ref.watch(variationRepositoryProvider);
  if (repo == null) return Stream<List<Variation>>.value(const <Variation>[]);
  return repo.watchForJob(jobId);
});

/// Approved extras across every job that have not yet been billed — the money
/// most commonly lost on a building job.
final unbilledVariationsProvider = Provider<List<Variation>>((ref) {
  return (ref.watch(variationsProvider).valueOrNull ?? const <Variation>[])
      .unbilled;
});

final unbilledVariationTotalProvider = Provider<double>((ref) {
  return ref
      .watch(unbilledVariationsProvider)
      .fold<double>(0, (double s, Variation v) => s + v.netTotal);
});

// ---------------------------------------------------------------------------
// Payment stages
// ---------------------------------------------------------------------------

final paymentStagesForJobProvider =
    StreamProvider.family<List<PaymentStage>, String>((ref, String jobId) {
  final PaymentStageRepository? repo =
      ref.watch(paymentStageRepositoryProvider);
  if (repo == null) {
    return Stream<List<PaymentStage>>.value(const <PaymentStage>[]);
  }
  return repo.watchForJob(jobId);
});

// ---------------------------------------------------------------------------
// Job value
// ---------------------------------------------------------------------------

/// What a job is worth, for costing payment stages against.
///
/// Resolution order, best evidence first:
///   1. invoices already raised for the job — what was actually billed;
///   2. the accepted quote — what was agreed;
///   3. any quote — the most recent estimate;
/// then approved variations are added on top, because staged percentages
/// should be taken against the real contract value including agreed extras.
final jobValueProvider = Provider.family<double, String>((ref, String jobId) {
  final List<Invoice> invoices =
      ref.watch(invoicesProvider).valueOrNull ?? const <Invoice>[];
  final List<Quote> quotes =
      ref.watch(quotesProvider).valueOrNull ?? const <Quote>[];
  final List<Variation> variations =
      ref.watch(variationsForJobProvider(jobId)).valueOrNull ??
          const <Variation>[];

  double base = 0;

  final Iterable<Invoice> jobInvoices =
      invoices.where((Invoice i) => i.jobId == jobId && !i.isDraft);
  if (jobInvoices.isNotEmpty) {
    base = jobInvoices.fold<double>(
        0, (double s, Invoice i) => s + i.settlement.subtotal);
  } else {
    final Iterable<Quote> jobQuotes =
        quotes.where((Quote q) => q.jobId == jobId);
    final Iterable<Quote> accepted = jobQuotes.where((Quote q) =>
        q.status.name == 'accepted' || q.status.name == 'converted');
    final Iterable<Quote> use = accepted.isNotEmpty ? accepted : jobQuotes;
    if (use.isNotEmpty) {
      base = use
          .map((Quote q) => q.totals.subtotal)
          .reduce((double a, double b) => a > b ? a : b);
    }
  }

  return base + variations.approvedNet;
});

/// The job's schedule paired with its value, which is what the stage screen and
/// the job detail card both need.
class JobBilling {
  const JobBilling({
    required this.jobValue,
    required this.stages,
    required this.invoicedTotal,
  });

  final double jobValue;
  final List<PaymentStage> stages;
  final double invoicedTotal;

  double get remaining =>
      (jobValue - invoicedTotal).clamp(0, double.infinity).toDouble();

  double get progress =>
      jobValue <= 0 ? 0 : (invoicedTotal / jobValue).clamp(0, 1).toDouble();

  bool get hasSchedule => stages.isNotEmpty;
  PaymentStage? get nextStage => stages.nextUnbilled;
}

final jobBillingProvider =
    Provider.family<JobBilling, String>((ref, String jobId) {
  final double value = ref.watch(jobValueProvider(jobId));
  final List<PaymentStage> stages =
      ref.watch(paymentStagesForJobProvider(jobId)).valueOrNull ??
          const <PaymentStage>[];

  return JobBilling(
    jobValue: value,
    stages: stages,
    invoicedTotal: stages.billedAgainst(value),
  );
});

/// Jobs that are finished but have never been invoiced — unbilled work.
final uninvoicedCompletedJobsProvider = Provider<List<Job>>((ref) {
  final List<Job> jobs = ref.watch(jobsProvider).valueOrNull ?? const <Job>[];
  final List<Invoice> invoices =
      ref.watch(invoicesProvider).valueOrNull ?? const <Invoice>[];
  final Set<String> billed = invoices
      .where((Invoice i) => i.jobId != null)
      .map((Invoice i) => i.jobId!)
      .toSet();

  return jobs
      .where((Job j) => j.status.name == 'completed' && !billed.contains(j.id))
      .toList();
});
