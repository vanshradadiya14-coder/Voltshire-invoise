/// Central definition of every Firestore collection name used by the app.
///
/// Keeping these in one place avoids typos and makes it trivial to rename a
/// collection or migrate to sub-collections in a future version.
class FirestorePaths {
  const FirestorePaths._();

  static const String users = 'users';
  static const String settings = 'settings';

  /// Read-through cache of store entitlements, keyed by UID.
  static const String subscriptions = 'subscriptions';

  /// Recycle bin for deleted records, recoverable for 30 days.
  static const String trash = 'trash';

  // ---- Trade tools ----

  /// The builder's saved price list.
  static const String priceItems = 'price_items';

  /// Extra work agreed after a job started.
  static const String variations = 'variations';

  /// Deposit and staged-payment schedules on jobs.
  static const String paymentStages = 'payment_stages';
  static const String customers = 'customers';
  static const String jobs = 'jobs';
  static const String quotes = 'quotes';
  static const String invoices = 'invoices';
  static const String invoiceItems = 'invoice_items';
  static const String payments = 'payments';
  static const String expenses = 'expenses';
  static const String documents = 'documents';
  static const String photos = 'photos';
}

/// Firebase Storage folder layout (all scoped under the signed-in user's UID).
class StoragePaths {
  const StoragePaths._();

  static String logo(String uid) => 'users/$uid/company/logo';
  static String jobPhotos(String uid, String jobId) =>
      'users/$uid/jobs/$jobId/photos';
  static String receipts(String uid) => 'users/$uid/expenses/receipts';
  static String documents(String uid) => 'users/$uid/documents';
}
