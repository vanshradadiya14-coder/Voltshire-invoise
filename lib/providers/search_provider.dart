import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import '../models/payment.dart';
import '../models/quote.dart';
import 'data_providers.dart';

/// The active global-search query.
final globalSearchTermProvider = StateProvider<String>((ref) => '');

/// Combined, in-memory global search results across all entities. Because the
/// underlying lists are already streamed and cached, filtering locally is
/// instant and works fully offline.
class SearchResults {
  const SearchResults({
    this.customers = const <Customer>[],
    this.jobs = const <Job>[],
    this.quotes = const <Quote>[],
    this.invoices = const <Invoice>[],
    this.payments = const <Payment>[],
  });

  final List<Customer> customers;
  final List<Job> jobs;
  final List<Quote> quotes;
  final List<Invoice> invoices;
  final List<Payment> payments;

  bool get isEmpty =>
      customers.isEmpty &&
      jobs.isEmpty &&
      quotes.isEmpty &&
      invoices.isEmpty &&
      payments.isEmpty;

  int get total =>
      customers.length + jobs.length + quotes.length + invoices.length + payments.length;
}

final globalSearchProvider = Provider<SearchResults>((ref) {
  final String q = ref.watch(globalSearchTermProvider).trim().toLowerCase();
  if (q.isEmpty) return const SearchResults();

  bool has(String? value) => (value ?? '').toLowerCase().contains(q);

  final List<Customer> customers = (ref.watch(customersProvider).value ?? <Customer>[])
      .where((Customer c) => has(c.name) || has(c.phone) || has(c.email))
      .toList();

  final List<Job> jobs = (ref.watch(jobsProvider).value ?? <Job>[])
      .where((Job j) => has(j.title) || has(j.customerName) || has(j.siteAddress))
      .toList();

  final List<Quote> quotes = (ref.watch(quotesProvider).value ?? <Quote>[])
      .where((Quote qt) => has(qt.numberFormatted) || has(qt.customerName))
      .toList();

  final List<Invoice> invoices = (ref.watch(invoicesProvider).value ?? <Invoice>[])
      .where((Invoice i) => has(i.numberFormatted) || has(i.customerName))
      .toList();

  final List<Payment> payments = (ref.watch(paymentsProvider).value ?? <Payment>[])
      .where((Payment p) =>
          has(p.invoiceNumber) || has(p.customerName) || has(p.reference))
      .toList();

  return SearchResults(
    customers: customers,
    jobs: jobs,
    quotes: quotes,
    invoices: invoices,
    payments: payments,
  );
});
