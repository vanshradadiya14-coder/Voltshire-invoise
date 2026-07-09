import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/quote.dart';
import 'company_repository.dart';

/// CRUD for the `quotes` collection, including atomic auto-numbering and
/// duplication.
class QuoteRepository {
  QuoteRepository(this._db, this._uid, this._company);

  final FirebaseFirestore _db;
  final String _uid;
  final CompanyRepository _company;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.quotes);

  Query<Map<String, dynamic>> get _owned => _col.where('ownerId', isEqualTo: _uid);

  Stream<List<Quote>> watchAll() =>
      _owned.orderBy('issueDate', descending: true).snapshots().map(_mapDocs);

  Stream<List<Quote>> watchForCustomer(String customerId) => _owned
      .where('customerId', isEqualTo: customerId)
      .orderBy('issueDate', descending: true)
      .snapshots()
      .map(_mapDocs);

  Stream<Quote?> watchById(String id) => _col.doc(id).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> d) =>
          d.exists ? Quote.fromMap(d.id, d.data()!) : null);

  Future<Quote?> fetchById(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> d = await _col.doc(id).get();
    return d.exists ? Quote.fromMap(d.id, d.data()!) : null;
  }

  Future<String> create(Quote quote) async {
    final int number = await _company.reserveNextQuoteNumber();
    final profile = await _company.fetch();
    final String formatted = profile?.formatQuoteNumber(number) ??
        'QT-${number.toString().padLeft(6, '0')}';
    final String id = _uuid.v4();
    final Quote toSave = Quote(
      id: id,
      ownerId: _uid,
      number: number,
      numberFormatted: formatted,
      customerId: quote.customerId,
      customerName: quote.customerName,
      customerAddress: quote.customerAddress,
      jobId: quote.jobId,
      jobTitle: quote.jobTitle,
      workDescription: quote.workDescription,
      items: quote.items,
      issueDate: quote.issueDate ?? DateTime.now(),
      validUntil: quote.validUntil,
      status: quote.status,
      notes: quote.notes,
      createdAt: DateTime.now(),
    );
    await _col.doc(id).set(toSave.toMap());
    return id;
  }

  /// Creates a copy of an existing quote as a fresh draft with a new number.
  Future<String> duplicate(Quote source) => create(
        source.copyWith(status: QuoteStatus.draft),
      );

  Future<void> update(Quote quote) =>
      _col.doc(quote.id).set(quote.toMap(), SetOptions(merge: true));

  Future<void> updateStatus(String id, QuoteStatus status) => _col.doc(id).set(
        <String, dynamic>{'status': status.name, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  /// Records the invoice a quote was converted into.
  Future<void> markConverted(String id, String invoiceId) => _col.doc(id).set(
        <String, dynamic>{
          'status': QuoteStatus.converted.name,
          'convertedInvoiceId': invoiceId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  Future<void> delete(String id) => _col.doc(id).delete();

  List<Quote> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => Quote.fromMap(d.id, d.data()))
      .toList();
}
