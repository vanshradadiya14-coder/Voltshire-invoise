import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/invoice.dart';
import '../models/payment.dart';

/// CRUD for the `payments` collection. Adding/removing a payment atomically
/// updates the parent invoice's `amountPaid` (and therefore its status).
class PaymentRepository {
  PaymentRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.payments);
  CollectionReference<Map<String, dynamic>> get _invoices =>
      _db.collection(FirestorePaths.invoices);

  Query<Map<String, dynamic>> get _owned => _col.where('ownerId', isEqualTo: _uid);

  Stream<List<Payment>> watchAll() =>
      _owned.orderBy('date', descending: true).snapshots().map(_mapDocs);

  Stream<List<Payment>> watchForInvoice(String invoiceId) => _owned
      .where('invoiceId', isEqualTo: invoiceId)
      .orderBy('date', descending: true)
      .snapshots()
      .map(_mapDocs);

  /// Records a payment and increases the invoice's `amountPaid` atomically.
  Future<String> addPayment(Payment payment) async {
    final String id = _uuid.v4();
    final DocumentReference<Map<String, dynamic>> payRef = _col.doc(id);
    final DocumentReference<Map<String, dynamic>> invRef =
        _invoices.doc(payment.invoiceId);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> invSnap = await tx.get(invRef);
      final Payment toSave = Payment(
        id: id,
        ownerId: _uid,
        invoiceId: payment.invoiceId,
        invoiceNumber: payment.invoiceNumber,
        customerName: payment.customerName,
        amount: payment.amount,
        method: payment.method,
        reference: payment.reference,
        date: payment.date ?? DateTime.now(),
        notes: payment.notes,
        createdAt: DateTime.now(),
      );
      tx.set(payRef, toSave.toMap());

      if (invSnap.exists) {
        final Invoice inv = Invoice.fromMap(invSnap.id, invSnap.data()!);
        final Invoice updated =
            inv.copyWith(amountPaid: inv.amountPaid + payment.amount);
        tx.set(invRef, updated.toMap(), SetOptions(merge: true));
      }
    });
    return id;
  }

  /// Deletes a payment and decreases the invoice's `amountPaid` atomically.
  Future<void> deletePayment(Payment payment) async {
    final DocumentReference<Map<String, dynamic>> payRef = _col.doc(payment.id);
    final DocumentReference<Map<String, dynamic>> invRef =
        _invoices.doc(payment.invoiceId);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> invSnap = await tx.get(invRef);
      tx.delete(payRef);
      if (invSnap.exists) {
        final Invoice inv = Invoice.fromMap(invSnap.id, invSnap.data()!);
        final double newPaid =
            (inv.amountPaid - payment.amount).clamp(0, double.infinity).toDouble();
        tx.set(invRef, inv.copyWith(amountPaid: newPaid).toMap(), SetOptions(merge: true));
      }
    });
  }

  List<Payment> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => Payment.fromMap(d.id, d.data()))
      .toList();
}
