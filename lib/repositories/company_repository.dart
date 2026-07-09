import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/company_profile.dart';

/// Reads/writes the single company profile document at `settings/{uid}` and
/// hands out the next sequential invoice/quote numbers atomically.
class CompanyRepository {
  CompanyRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(FirestorePaths.settings).doc(_uid);

  Stream<CompanyProfile?> watch() {
    return _doc.snapshots().map((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (!snap.exists) return null;
      return CompanyProfile.fromMap(snap.data()!);
    });
  }

  Future<CompanyProfile?> fetch() async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _doc.get();
    if (!snap.exists) return null;
    return CompanyProfile.fromMap(snap.data()!);
  }

  /// Creates or fully updates the profile.
  Future<void> save(CompanyProfile profile) async {
    await _doc.set(profile.toMap(), SetOptions(merge: true));
  }

  /// Atomically reserves and returns the next invoice number, incrementing the
  /// stored counter. Runs in a transaction so concurrent creates never collide.
  Future<int> reserveNextInvoiceNumber() => _reserveCounter('nextInvoiceNumber');

  Future<int> reserveNextQuoteNumber() => _reserveCounter('nextQuoteNumber');

  Future<int> _reserveCounter(String field) async {
    return _db.runTransaction<int>((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(_doc);
      final int current = (snap.data()?[field] as num?)?.toInt() ?? 1;
      tx.set(_doc, <String, dynamic>{field: current + 1}, SetOptions(merge: true));
      return current;
    });
  }
}
