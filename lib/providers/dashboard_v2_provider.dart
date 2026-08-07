import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/dashboard_metrics.dart';
import '../models/dashboard_period.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import '../models/payment.dart';
import '../models/quote.dart';
import '../routes/app_routes.dart';
import 'data_providers.dart';

// ---------------------------------------------------------------------------
// Period selection
// ---------------------------------------------------------------------------

final dashboardRangeProvider =
    StateProvider<DashboardRange>((ref) => DashboardRange.month);

/// A user-picked window, set only when [dashboardRangeProvider] is `custom`.
final customPeriodProvider = StateProvider<DashboardPeriod?>((ref) => null);

/// The active window. Everything downstream depends on this one provider, so a
/// period change recomputes each chart exactly once.
final dashboardPeriodProvider = Provider<DashboardPeriod>((ref) {
  final DashboardRange range = ref.watch(dashboardRangeProvider);
  if (range == DashboardRange.custom) {
    final DashboardPeriod? custom = ref.watch(customPeriodProvider);
    if (custom != null) return custom;
  }
  return DashboardPeriod.of(range);
});

// ---------------------------------------------------------------------------
// Source data
// ---------------------------------------------------------------------------

/// Bundles the four streamed collections into one value so each downstream
/// provider declares a single dependency instead of four.
class _Source {
  const _Source({
    required this.jobs,
    required this.invoices,
    required this.quotes,
    required this.payments,
    required this.expenses,
    required this.customers,
    required this.loading,
  });

  final List<Job> jobs;
  final List<Invoice> invoices;
  final List<Quote> quotes;
  final List<Payment> payments;
  final List<Expense> expenses;
  final List<Customer> customers;
  final bool loading;
}

final _sourceProvider = Provider<_Source>((ref) {
  final AsyncValue<List<Job>> jobs = ref.watch(jobsProvider);
  final AsyncValue<List<Invoice>> invoices = ref.watch(invoicesProvider);
  final AsyncValue<List<Quote>> quotes = ref.watch(quotesProvider);
  final AsyncValue<List<Payment>> payments = ref.watch(paymentsProvider);
  final AsyncValue<List<Expense>> expenses = ref.watch(expensesProvider);
  final AsyncValue<List<Customer>> customers = ref.watch(customersProvider);

  return _Source(
    jobs: jobs.valueOrNull ?? const <Job>[],
    invoices: invoices.valueOrNull ?? const <Invoice>[],
    quotes: quotes.valueOrNull ?? const <Quote>[],
    payments: payments.valueOrNull ?? const <Payment>[],
    expenses: expenses.valueOrNull ?? const <Expense>[],
    customers: customers.valueOrNull ?? const <Customer>[],
    loading: jobs.isLoading ||
        invoices.isLoading ||
        quotes.isLoading ||
        payments.isLoading ||
        expenses.isLoading ||
        customers.isLoading,
  );
});

// ---------------------------------------------------------------------------
// Headline metrics
// ---------------------------------------------------------------------------

/// All headline figures for the active window, each paired with the same
/// measure over the preceding window.
final dashboardMetricsProvider = Provider<AsyncValue<DashboardMetrics>>((ref) {
  final _Source s = ref.watch(_sourceProvider);
  final DashboardPeriod p = ref.watch(dashboardPeriodProvider);

  if (s.loading) return const AsyncValue<DashboardMetrics>.loading();

  // --- Money in (payments received) ---
  double revNow = 0, revPrev = 0;
  for (final Payment pay in s.payments) {
    if (p.contains(pay.date)) {
      revNow += pay.amount;
    } else if (p.containsPrevious(pay.date)) {
      revPrev += pay.amount;
    }
  }

  // --- Money out (expenses) ---
  double expNow = 0, expPrev = 0;
  for (final Expense e in s.expenses) {
    if (p.contains(e.date)) {
      expNow += e.amount;
    } else if (p.containsPrevious(e.date)) {
      expPrev += e.amount;
    }
  }

  // --- Invoicing ---
  double invNow = 0, invPrev = 0;
  int invCountNow = 0;
  for (final Invoice i in s.invoices) {
    if (i.isDraft) continue;
    if (p.contains(i.issueDate)) {
      invNow += i.grandTotal;
      invCountNow++;
    } else if (p.containsPrevious(i.issueDate)) {
      invPrev += i.grandTotal;
    }
  }

  // --- Outstanding & overdue (point-in-time, not windowed) ---
  // Compared against the same measure as it stood at the end of the previous
  // window: invoices issued before that cut-off, less payments received before
  // it. Anything else would compare unlike quantities.
  final DateTime now = DateTime.now();
  double outstandingNow = 0, overdueNow = 0;
  int overdueCount = 0, unpaidCount = 0;

  for (final Invoice i in s.invoices) {
    if (i.isDraft) continue;
    final double due = i.balanceDue;
    if (due <= 0.005) continue;

    outstandingNow += due;
    unpaidCount++;
    if (i.dueDate != null && now.isAfter(i.dueDate!)) {
      overdueNow += due;
      overdueCount++;
    }
  }

  final double outstandingPrev = _outstandingAsOf(s, p.previousEnd);
  final double overduePrev = _overdueAsOf(s, p.previousEnd);

  // --- Jobs ---
  int newJobsNow = 0, newJobsPrev = 0;
  int doneNow = 0, donePrev = 0;
  int activeJobs = 0;
  for (final Job j in s.jobs) {
    if (p.contains(j.createdAt)) {
      newJobsNow++;
    } else if (p.containsPrevious(j.createdAt)) {
      newJobsPrev++;
    }
    if (j.status == JobStatus.completed) {
      if (p.contains(j.completionDate)) {
        doneNow++;
      } else if (p.containsPrevious(j.completionDate)) {
        donePrev++;
      }
    }
    if (j.status == JobStatus.accepted || j.status == JobStatus.inProgress) {
      activeJobs++;
    }
  }

  // --- Customers ---
  int custNow = 0, custPrev = 0;
  for (final Customer c in s.customers) {
    if (p.contains(c.createdAt)) {
      custNow++;
    } else if (p.containsPrevious(c.createdAt)) {
      custPrev++;
    }
  }

  // --- Quotes ---
  int sentNow = 0, sentPrev = 0, acceptedNow = 0, acceptedPrev = 0;
  for (final Quote q in s.quotes) {
    final bool issued = q.status != QuoteStatus.draft;
    if (issued) {
      if (p.contains(q.issueDate)) {
        sentNow++;
      } else if (p.containsPrevious(q.issueDate)) {
        sentPrev++;
      }
    }
    final bool won = q.status == QuoteStatus.accepted ||
        q.status == QuoteStatus.converted;
    if (won) {
      if (p.contains(q.issueDate)) {
        acceptedNow++;
      } else if (p.containsPrevious(q.issueDate)) {
        acceptedPrev++;
      }
    }
  }

  return AsyncValue<DashboardMetrics>.data(DashboardMetrics(
    period: p,
    revenue: Metric(current: revNow, previous: revPrev),
    expenses: Metric(
      current: expNow,
      previous: expPrev,
      higherIsBetter: false,
    ),
    profit: Metric(current: revNow - expNow, previous: revPrev - expPrev),
    invoiced: Metric(current: invNow, previous: invPrev),
    outstanding: Metric(
      current: outstandingNow,
      previous: outstandingPrev,
      higherIsBetter: false,
    ),
    overdue: Metric(
      current: overdueNow,
      previous: overduePrev,
      higherIsBetter: false,
    ),
    newJobs: Metric(
      current: newJobsNow.toDouble(),
      previous: newJobsPrev.toDouble(),
      isCurrency: false,
    ),
    completedJobs: Metric(
      current: doneNow.toDouble(),
      previous: donePrev.toDouble(),
      isCurrency: false,
    ),
    newCustomers: Metric(
      current: custNow.toDouble(),
      previous: custPrev.toDouble(),
      isCurrency: false,
    ),
    quotesSent: Metric(
      current: sentNow.toDouble(),
      previous: sentPrev.toDouble(),
      isCurrency: false,
    ),
    quotesAccepted: Metric(
      current: acceptedNow.toDouble(),
      previous: acceptedPrev.toDouble(),
      isCurrency: false,
    ),
    activeJobs: activeJobs,
    overdueCount: overdueCount,
    unpaidCount: unpaidCount,
    averageInvoiceValue: invCountNow == 0 ? 0 : invNow / invCountNow,
    collectionRate: invNow <= 0.005 ? 0 : (revNow / invNow * 100).clamp(0, 999),
    quoteConversionRate: sentNow == 0 ? 0 : acceptedNow / sentNow * 100,
  ));
});

/// Balance outstanding as it stood at [cutoff].
double _outstandingAsOf(_Source s, DateTime cutoff) {
  double total = 0;
  for (final Invoice i in s.invoices) {
    if (i.isDraft) continue;
    if (i.issueDate == null || !i.issueDate!.isBefore(cutoff)) continue;

    final double paidByThen = s.payments
        .where((Payment p) =>
            p.invoiceId == i.id && p.date != null && p.date!.isBefore(cutoff))
        .fold<double>(0, (double sum, Payment p) => sum + p.amount);

    final double due = i.grandTotal - paidByThen;
    if (due > 0.005) total += due;
  }
  return total;
}

/// Overdue balance as it stood at [cutoff].
double _overdueAsOf(_Source s, DateTime cutoff) {
  double total = 0;
  for (final Invoice i in s.invoices) {
    if (i.isDraft || i.dueDate == null) continue;
    if (!i.dueDate!.isBefore(cutoff)) continue;
    if (i.issueDate == null || !i.issueDate!.isBefore(cutoff)) continue;

    final double paidByThen = s.payments
        .where((Payment p) =>
            p.invoiceId == i.id && p.date != null && p.date!.isBefore(cutoff))
        .fold<double>(0, (double sum, Payment p) => sum + p.amount);

    final double due = i.grandTotal - paidByThen;
    if (due > 0.005) total += due;
  }
  return total;
}

// ---------------------------------------------------------------------------
// Charted series
// ---------------------------------------------------------------------------

/// Revenue received vs expenses paid, bucketed for the active window.
final cashFlowSeriesProvider = Provider<List<ChartSeries>>((ref) {
  final _Source s = ref.watch(_sourceProvider);
  final DashboardPeriod p = ref.watch(dashboardPeriodProvider);
  final List<DateTime> buckets = p.buckets();

  final List<double> money = List<double>.filled(buckets.length, 0);
  final List<double> spend = List<double>.filled(buckets.length, 0);

  for (final Payment pay in s.payments) {
    if (pay.date == null) continue;
    final int i = p.bucketIndexOf(pay.date!, buckets);
    if (i >= 0) money[i] += pay.amount;
  }
  for (final Expense e in s.expenses) {
    if (e.date == null) continue;
    final int i = p.bucketIndexOf(e.date!, buckets);
    if (i >= 0) spend[i] += e.amount;
  }

  List<SeriesPoint> pts(List<double> values) => <SeriesPoint>[
        for (int i = 0; i < buckets.length; i++)
          SeriesPoint(
            bucket: buckets[i],
            label: p.bucketLabel(buckets[i]),
            value: values[i],
          ),
      ];

  return <ChartSeries>[
    ChartSeries(name: 'Money in', points: pts(money)),
    ChartSeries(name: 'Money out', points: pts(spend)),
  ];
});

/// Cumulative revenue across the window — the "are we ahead of last month?"
/// view, which a running total answers far better than daily bars.
final revenueTrendProvider = Provider<ChartSeries>((ref) {
  final List<ChartSeries> flow = ref.watch(cashFlowSeriesProvider);
  if (flow.isEmpty) return ChartSeries.empty;

  double running = 0;
  return ChartSeries(
    name: 'Cumulative revenue',
    points: flow.first.points.map((SeriesPoint pt) {
      running += pt.value;
      return SeriesPoint(bucket: pt.bucket, label: pt.label, value: running);
    }).toList(),
  );
});

/// Expenses grouped by category, largest first.
final expenseBreakdownProvider = Provider<List<BreakdownSlice>>((ref) {
  final _Source s = ref.watch(_sourceProvider);
  final DashboardPeriod p = ref.watch(dashboardPeriodProvider);

  final Map<String, double> totals = <String, double>{};
  final Map<String, int> counts = <String, int>{};

  for (final Expense e in s.expenses) {
    if (!p.contains(e.date)) continue;
    final String key = e.category.isEmpty ? 'Other' : e.category;
    totals[key] = (totals[key] ?? 0) + e.amount;
    counts[key] = (counts[key] ?? 0) + 1;
  }

  final List<BreakdownSlice> out = totals.entries
      .map((MapEntry<String, double> e) => BreakdownSlice(
            label: e.key,
            value: e.value,
            count: counts[e.key] ?? 0,
          ))
      .toList()
    ..sort((BreakdownSlice a, BreakdownSlice b) => b.value.compareTo(a.value));

  return out;
});

/// Job pipeline: how many jobs sit at each stage and what they're worth.
///
/// Value comes from the linked quote or invoice, so the funnel shows money at
/// risk, not just a headcount of jobs.
final jobPipelineProvider = Provider<List<BreakdownSlice>>((ref) {
  final _Source s = ref.watch(_sourceProvider);

  final Map<JobStatus, int> counts = <JobStatus, int>{};
  final Map<JobStatus, double> values = <JobStatus, double>{};

  double valueOf(String jobId) {
    for (final Invoice i in s.invoices) {
      if (i.jobId == jobId && !i.isDraft) return i.grandTotal;
    }
    for (final Quote q in s.quotes) {
      if (q.jobId == jobId) return q.grandTotal;
    }
    return 0;
  }

  for (final Job j in s.jobs) {
    if (j.status == JobStatus.cancelled) continue;
    counts[j.status] = (counts[j.status] ?? 0) + 1;
    values[j.status] = (values[j.status] ?? 0) + valueOf(j.id);
  }

  return <BreakdownSlice>[
    for (final JobStatus st in <JobStatus>[
      JobStatus.quote,
      JobStatus.accepted,
      JobStatus.inProgress,
      JobStatus.completed,
    ])
      BreakdownSlice(
        label: st.label,
        value: values[st] ?? 0,
        count: counts[st] ?? 0,
      ),
  ];
});

/// Top customers by money received in the window.
final topCustomersProvider = Provider<List<BreakdownSlice>>((ref) {
  final _Source s = ref.watch(_sourceProvider);
  final DashboardPeriod p = ref.watch(dashboardPeriodProvider);

  final Map<String, double> totals = <String, double>{};
  final Map<String, int> counts = <String, int>{};

  for (final Payment pay in s.payments) {
    if (!p.contains(pay.date)) continue;
    final String key =
        pay.customerName.isEmpty ? 'Unknown' : pay.customerName;
    totals[key] = (totals[key] ?? 0) + pay.amount;
    counts[key] = (counts[key] ?? 0) + 1;
  }

  final List<BreakdownSlice> out = totals.entries
      .map((MapEntry<String, double> e) => BreakdownSlice(
            label: e.key,
            value: e.value,
            count: counts[e.key] ?? 0,
          ))
      .toList()
    ..sort((BreakdownSlice a, BreakdownSlice b) => b.value.compareTo(a.value));

  return out.take(5).toList();
});

// ---------------------------------------------------------------------------
// Action centre
// ---------------------------------------------------------------------------

/// Work that needs attention, most urgent first.
///
/// This is the part of the dashboard that earns its place: numbers describe the
/// business, but these tell the user what to actually do next.
final actionCentreProvider = Provider<List<ActionItem>>((ref) {
  final _Source s = ref.watch(_sourceProvider);
  final DateTime now = DateTime.now();
  final DateTime soon = now.add(const Duration(days: 7));

  final List<ActionItem> items = <ActionItem>[];

  // 1 — Overdue invoices.
  final List<Invoice> overdue = s.invoices
      .where((Invoice i) =>
          !i.isDraft &&
          i.balanceDue > 0.005 &&
          i.dueDate != null &&
          now.isAfter(i.dueDate!))
      .toList();
  if (overdue.isNotEmpty) {
    final double total =
        overdue.fold<double>(0, (double t, Invoice i) => t + i.balanceDue);
    items.add(ActionItem(
      kind: ActionKind.overdueInvoices,
      title: '${overdue.length} overdue ${_plural(overdue.length, 'invoice')}',
      subtitle: 'Chase payment — this money is already late',
      count: overdue.length,
      amount: total,
      route: Routes.invoices,
      entityId: overdue.length == 1 ? overdue.first.id : null,
    ));
  }

  // 2 — Due within the next week.
  final List<Invoice> dueSoon = s.invoices
      .where((Invoice i) =>
          !i.isDraft &&
          i.balanceDue > 0.005 &&
          i.dueDate != null &&
          !now.isAfter(i.dueDate!) &&
          i.dueDate!.isBefore(soon))
      .toList();
  if (dueSoon.isNotEmpty) {
    items.add(ActionItem(
      kind: ActionKind.dueSoon,
      title: '${dueSoon.length} ${_plural(dueSoon.length, 'invoice')} due soon',
      subtitle: 'Payment expected within 7 days',
      count: dueSoon.length,
      amount:
          dueSoon.fold<double>(0, (double t, Invoice i) => t + i.balanceDue),
      route: Routes.invoices,
    ));
  }

  // 3 — Quotes about to expire.
  final List<Quote> expiring = s.quotes
      .where((Quote q) =>
          q.status == QuoteStatus.sent &&
          q.validUntil != null &&
          !now.isAfter(q.validUntil!) &&
          q.validUntil!.isBefore(soon))
      .toList();
  if (expiring.isNotEmpty) {
    items.add(ActionItem(
      kind: ActionKind.quotesExpiring,
      title: '${expiring.length} ${_plural(expiring.length, 'quote')} expiring',
      subtitle: 'Follow up before they lapse',
      count: expiring.length,
      amount:
          expiring.fold<double>(0, (double t, Quote q) => t + q.grandTotal),
      route: Routes.quotes,
      entityId: expiring.length == 1 ? expiring.first.id : null,
    ));
  }

  // 4 — Completed jobs that were never invoiced. Unbilled work is the most
  //     expensive kind of admin oversight there is.
  final Set<String> invoicedJobIds = s.invoices
      .where((Invoice i) => i.jobId != null)
      .map((Invoice i) => i.jobId!)
      .toSet();
  final List<Job> uninvoiced = s.jobs
      .where((Job j) =>
          j.status == JobStatus.completed && !invoicedJobIds.contains(j.id))
      .toList();
  if (uninvoiced.isNotEmpty) {
    items.add(ActionItem(
      kind: ActionKind.uninvoicedJobs,
      title:
          '${uninvoiced.length} completed ${_plural(uninvoiced.length, 'job')} not invoiced',
      subtitle: 'Work finished but never billed',
      count: uninvoiced.length,
      route: Routes.jobs,
      entityId: uninvoiced.length == 1 ? uninvoiced.first.id : null,
    ));
  }

  // 5 — Accepted quotes with no job started.
  final Set<String> quoteJobIds = s.jobs.map((Job j) => j.id).toSet();
  final List<Quote> accepted = s.quotes
      .where((Quote q) =>
          q.status == QuoteStatus.accepted &&
          (q.jobId == null || !quoteJobIds.contains(q.jobId)))
      .toList();
  if (accepted.isNotEmpty) {
    items.add(ActionItem(
      kind: ActionKind.acceptedQuotesNoJob,
      title:
          '${accepted.length} accepted ${_plural(accepted.length, 'quote')} without a job',
      subtitle: 'Create the job to start tracking it',
      count: accepted.length,
      amount:
          accepted.fold<double>(0, (double t, Quote q) => t + q.grandTotal),
      route: Routes.quotes,
    ));
  }

  return items;
});

String _plural(int n, String word) => n == 1 ? word : '${word}s';

// ---------------------------------------------------------------------------
// Recent activity
// ---------------------------------------------------------------------------

final recentJobsProvider = Provider<List<Job>>((ref) {
  final List<Job> jobs = <Job>[...ref.watch(_sourceProvider).jobs]
    ..sort((Job a, Job b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return jobs.take(5).toList();
});

final recentInvoicesProvider = Provider<List<Invoice>>((ref) {
  final List<Invoice> list = <Invoice>[...ref.watch(_sourceProvider).invoices]
    ..sort((Invoice a, Invoice b) =>
        (b.issueDate ?? DateTime(0)).compareTo(a.issueDate ?? DateTime(0)));
  return list.take(5).toList();
});
