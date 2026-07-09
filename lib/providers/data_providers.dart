import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/company_profile.dart';
import '../models/customer.dart';
import '../models/document_file.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import '../models/job_photo.dart';
import '../models/payment.dart';
import '../models/quote.dart';
import 'repository_providers.dart';

// ---------------------------------------------------------------------------
// Company profile
// ---------------------------------------------------------------------------

final companyProfileProvider = StreamProvider<CompanyProfile?>((ref) {
  return ref.watch(companyRepositoryProvider).watch();
});

/// The configured currency symbol (defaults to £), used by money formatting
/// across the UI so figures always match the company's chosen currency.
final currencySymbolProvider = Provider<String>((ref) {
  return ref.watch(companyProfileProvider).valueOrNull?.currencySymbol ?? '£';
});

// ---------------------------------------------------------------------------
// Customers
// ---------------------------------------------------------------------------

final customersProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).watchAll();
});

final customerProvider =
    StreamProvider.family<Customer?, String>((ref, String id) {
  return ref.watch(customerRepositoryProvider).watchById(id);
});

/// Free-text customer search term (bound to the search field).
final customerSearchTermProvider = StateProvider<String>((ref) => '');

final customerSearchProvider = StreamProvider<List<Customer>>((ref) {
  final String term = ref.watch(customerSearchTermProvider);
  return ref.watch(customerRepositoryProvider).search(term);
});

// ---------------------------------------------------------------------------
// Jobs
// ---------------------------------------------------------------------------

final jobsProvider = StreamProvider<List<Job>>((ref) {
  return ref.watch(jobRepositoryProvider).watchAll();
});

final jobProvider = StreamProvider.family<Job?, String>((ref, String id) {
  return ref.watch(jobRepositoryProvider).watchById(id);
});

final jobsByCustomerProvider =
    StreamProvider.family<List<Job>, String>((ref, String customerId) {
  return ref.watch(jobRepositoryProvider).watchForCustomer(customerId);
});

final jobsByStatusProvider =
    StreamProvider.family<List<Job>, JobStatus>((ref, JobStatus status) {
  return ref.watch(jobRepositoryProvider).watchByStatus(status);
});

// ---------------------------------------------------------------------------
// Quotes
// ---------------------------------------------------------------------------

final quotesProvider = StreamProvider<List<Quote>>((ref) {
  return ref.watch(quoteRepositoryProvider).watchAll();
});

final quoteProvider = StreamProvider.family<Quote?, String>((ref, String id) {
  return ref.watch(quoteRepositoryProvider).watchById(id);
});

// ---------------------------------------------------------------------------
// Invoices
// ---------------------------------------------------------------------------

final invoicesProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchAll();
});

final invoiceProvider = StreamProvider.family<Invoice?, String>((ref, String id) {
  return ref.watch(invoiceRepositoryProvider).watchById(id);
});

final invoicesByCustomerProvider =
    StreamProvider.family<List<Invoice>, String>((ref, String customerId) {
  return ref.watch(invoiceRepositoryProvider).watchForCustomer(customerId);
});

// ---------------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------------

final paymentsProvider = StreamProvider<List<Payment>>((ref) {
  return ref.watch(paymentRepositoryProvider).watchAll();
});

final paymentsForInvoiceProvider =
    StreamProvider.family<List<Payment>, String>((ref, String invoiceId) {
  return ref.watch(paymentRepositoryProvider).watchForInvoice(invoiceId);
});

// ---------------------------------------------------------------------------
// Expenses
// ---------------------------------------------------------------------------

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAll();
});

final expensesForJobProvider =
    StreamProvider.family<List<Expense>, String>((ref, String jobId) {
  return ref.watch(expenseRepositoryProvider).watchForJob(jobId);
});

// ---------------------------------------------------------------------------
// Photos
// ---------------------------------------------------------------------------

final photosForJobProvider =
    StreamProvider.family<List<JobPhoto>, String>((ref, String jobId) {
  return ref.watch(photoRepositoryProvider).watchForJob(jobId);
});

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

final documentsProvider = StreamProvider<List<DocumentFile>>((ref) {
  return ref.watch(documentRepositoryProvider).watchAll();
});

final documentsForJobProvider =
    StreamProvider.family<List<DocumentFile>, String>((ref, String jobId) {
  return ref.watch(documentRepositoryProvider).watchForJob(jobId);
});
