import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/invoice.dart';
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

  Stream<List<Invoice>> watchAll() =>
      _owned.orderBy('issueDate', descending: true).snapshots().map(_mapDocs);

  Stream<List<Invoice>> watchByStatus(InvoiceStatus status) => _owned
      .where('status', isEqualTo: status.name)
      .orderBy('issueDate', descending: true)
      .snapshots()
      .map(_mapDocs);

  Stream<List<Invoice>> watchForCustomer(String customerId) => _owned
      .where('customerId', isEqualTo: customerId)
      .orderBy('issueDate', descending: true)
      .snapshots()
      .map(_mapDocs);

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
    final Invoice toSave = Invoice(
      id: id,
      ownerId: _uid,
      number: number,
      numberFormatted: fmt.invoice,
      customerId: invoice.customerId,
      customerName: invoice.customerName,
      customerAddress: invoice.customerAddress,
      jobId: invoice.jobId,
      jobTitle: invoice.jobTitle,
      workDescription: invoice.workDescription,
      items: invoice.items,
      issueDate: invoice.issueDate ?? DateTime.now(),
      dueDate: invoice.dueDate,
      amountPaid: invoice.amountPaid,
      isDraft: invoice.isDraft,
      notes: invoice.notes,
      createdAt: DateTime.now(),
    );
    await _col.doc(id).set(toSave.toMap());
    return id;
  }

  Future<void> update(Invoice invoice) =>
      _col.doc(invoice.id).set(invoice.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();

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
