import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/company_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/document_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/job_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/photo_repository.dart';
import '../repositories/quote_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Thrown when a repository is read while signed out. In practice this never
/// happens because every screen using them lives behind the auth guard.
StateError _noUser() => StateError('No authenticated user for repository access');

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return CompanyRepository(ref.watch(firestoreProvider), uid);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return CustomerRepository(ref.watch(firestoreProvider), uid);
});

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return JobRepository(ref.watch(firestoreProvider), uid);
});

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return QuoteRepository(
    ref.watch(firestoreProvider),
    uid,
    ref.watch(companyRepositoryProvider),
  );
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return InvoiceRepository(
    ref.watch(firestoreProvider),
    uid,
    ref.watch(companyRepositoryProvider),
  );
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return PaymentRepository(ref.watch(firestoreProvider), uid);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return ExpenseRepository(
    ref.watch(firestoreProvider),
    uid,
    ref.watch(storageServiceProvider),
  );
});

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return PhotoRepository(
    ref.watch(firestoreProvider),
    uid,
    ref.watch(storageServiceProvider),
  );
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) throw _noUser();
  return DocumentRepository(
    ref.watch(firestoreProvider),
    uid,
    ref.watch(storageServiceProvider),
  );
});
