import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/enums.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import '../models/payment.dart';
import 'data_providers.dart';

/// Aggregated figures shown on the dashboard.
class DashboardStats {
  const DashboardStats({
    required this.activeJobs,
    required this.completedJobs,
    required this.pendingPayments,
    required this.monthlyRevenue,
    required this.outstandingTotal,
    required this.outstandingInvoices,
    required this.totalCustomers,
    required this.recentJobs,
    required this.recentInvoices,
  });

  final int activeJobs;
  final int completedJobs;
  final int pendingPayments;
  final double monthlyRevenue;
  final double outstandingTotal;
  final int outstandingInvoices;
  final int totalCustomers;
  final List<Job> recentJobs;
  final List<Invoice> recentInvoices;

  static const DashboardStats empty = DashboardStats(
    activeJobs: 0,
    completedJobs: 0,
    pendingPayments: 0,
    monthlyRevenue: 0,
    outstandingTotal: 0,
    outstandingInvoices: 0,
    totalCustomers: 0,
    recentJobs: <Job>[],
    recentInvoices: <Invoice>[],
  );
}

/// Combines jobs, invoices, customers and payments into [DashboardStats].
/// Returns loading until every underlying stream has produced a first value.
final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final AsyncValue<List<Job>> jobs = ref.watch(jobsProvider);
  final AsyncValue<List<Invoice>> invoices = ref.watch(invoicesProvider);
  final AsyncValue<List<Customer>> customers = ref.watch(customersProvider);
  final AsyncValue<List<Payment>> payments = ref.watch(paymentsProvider);

  // Propagate loading/error from any source.
  if (jobs.isLoading || invoices.isLoading || customers.isLoading || payments.isLoading) {
    return const AsyncValue<DashboardStats>.loading();
  }
  final Object? err = jobs.error ?? invoices.error ?? customers.error ?? payments.error;
  if (err != null) {
    return AsyncValue<DashboardStats>.error(err, StackTrace.current);
  }
  // (err is promoted to non-null above via the early return.)

  final List<Job> jobList = jobs.value ?? <Job>[];
  final List<Invoice> invoiceList = invoices.value ?? <Invoice>[];
  final List<Customer> customerList = customers.value ?? <Customer>[];
  final List<Payment> paymentList = payments.value ?? <Payment>[];

  final DateTime now = DateTime.now();
  final DateTime monthStart = DateTime(now.year, now.month);

  final double monthlyRevenue = paymentList
      .where((Payment p) => p.date != null && !p.date!.isBefore(monthStart))
      .fold<double>(0, (double sum, Payment p) => sum + p.amount);

  final Iterable<Invoice> outstanding = invoiceList.where(
    (Invoice i) => !i.isDraft && i.balanceDue > 0.005,
  );

  final List<Invoice> recentInvoices = <Invoice>[...invoiceList]
    ..sort((Invoice a, Invoice b) =>
        (b.issueDate ?? DateTime(0)).compareTo(a.issueDate ?? DateTime(0)));

  final List<Job> recentJobs = <Job>[...jobList]
    ..sort((Job a, Job b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  final DashboardStats stats = DashboardStats(
    activeJobs: jobList
        .where((Job j) =>
            j.status == JobStatus.accepted || j.status == JobStatus.inProgress)
        .length,
    completedJobs: jobList.where((Job j) => j.status == JobStatus.completed).length,
    pendingPayments: outstanding.length,
    monthlyRevenue: monthlyRevenue,
    outstandingTotal:
        outstanding.fold<double>(0, (double sum, Invoice i) => sum + i.balanceDue),
    outstandingInvoices: outstanding.length,
    totalCustomers: customerList.length,
    recentJobs: recentJobs.take(5).toList(),
    recentInvoices: recentInvoices.take(5).toList(),
  );

  return AsyncValue<DashboardStats>.data(stats);
});
