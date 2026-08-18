import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/invoice.dart';
import '../models/trade_enums.dart';
import 'company_repository.dart';

/// CRUD for the `invoices` collection, including atomic auto-numbering.
class InvoiceRepository {
  InvoiceRepository(this._db, this._uid, this._company);

  final FirebaseFirestore _db;
  final String _uid;
  final CompanyRepository _company;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.invoices);

  Query<Map<String, dynamic>> get _owned => _col.where('ownerId', isEqualTo: _uid);

  // Sorted/filtered on-device so no Firestore composite index is required.
  Stream<List<Invoice>> _watchOwned() => _owned.snapshots().map((snap) {
        final List<Invoice> list = _mapDocs(snap);
        list.sort((Invoice a, Invoice b) =>
            (b.issueDate ?? DateTime(0)).compareTo(a.issueDate ?? DateTime(0)));
        return list;
      });

  Stream<List<Invoice>> watchAll() => _watchOwned();

  Stream<List<Invoice>> watchByStatus(InvoiceStatus status) => _watchOwned().map(
      (List<Invoice> l) => l.where((Invoice i) => i.status == status).toList());

  Stream<List<Invoice>> watchForCustomer(String customerId) => _watchOwned().map(
      (List<Invoice> l) =>
          l.where((Invoice i) => i.customerId == customerId).toList());

  Stream<Invoice?> watchById(String id) => _col.doc(id).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> d) =>
          d.exists ? Invoice.fromMap(d.id, d.data()!) : null);

  Future<Invoice?> fetchById(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> d = await _col.doc(id).get();
    return d.exists ? Invoice.fromMap(d.id, d.data()!) : null;
  }

  /// Creates a new invoice, reserving the next sequential number from the
  /// company profile. The provided [invoice]'s number fields are overwritten.
  Future<String> create(Invoice invoice) async {
    final int number = await _company.reserveNextInvoiceNumber();
    final CompanyProfileNumber fmt = await _formattedNumber(number);
    final String id = _uuid.v4();

    // Copy the caller's invoice and override only what the server assigns.
    // Rebuilding it field by field used to silently drop anything not listed —
    // that lost cisStatus and reverseCharge (wrong amount due for every CIS and
    // reverse-charge customer) and the payment-stage link. copyWith keeps new
    // fields by default, so adding one cannot reintroduce that bug.
    final Invoice toSave = invoice.copyWith(
      id: id,
      ownerId: _uid,
      number: number,
      numberFormatted: fmt.invoice,
      issueDate: invoice.issueDate ?? DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _col.doc(id).set(toSave.toMap());
    return id;
  }

  Future<void> update(Invoice invoice) =>
      _col.doc(invoice.id).set(invoice.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Logs that a payment reminder was sent.
  ///
  /// Kept as an audit trail rather than a simple flag: if an unpaid invoice
  /// ends up in a county court claim, "I chased three times, here are the
  /// dates" is the difference between winning and not.
  Future<void> recordReminder(String id, ReminderStage stage) {
    return _col.doc(id).set(<String, dynamic>{
      'remindersSent': FieldValue.increment(1),
      'lastReminderAt': Timestamp.now(),
      'lastReminderStage': stage.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<CompanyProfileNumber> _formattedNumber(int number) async {
    final profile = await _company.fetch();
    final String inv = profile?.formatInvoiceNumber(number) ??
        'INV-${number.toString().padLeft(6, '0')}';
    return CompanyProfileNumber(inv);
  }

  List<Invoice> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => Invoice.fromMap(d.id, d.data()))
      .toList();
}

/// Tiny holder so [InvoiceRepository] can format the display number.
class CompanyProfileNumber {
  const CompanyProfileNumber(this.invoice);
  final String invoice;
}
