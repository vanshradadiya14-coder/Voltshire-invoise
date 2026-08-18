import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/trade_enums.dart';
import '../models/variation.dart';

/// CRUD for the `variations` collection — extra work agreed after a job started.
class VariationRepository {
  VariationRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.variations);

  Query<Map<String, dynamic>> get _owned =>
      _col.where('ownerId', isEqualTo: _uid);

  Stream<List<Variation>> _watchOwned() =>
      _owned.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
        final List<Variation> list = snap.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                Variation.fromMap(d.id, d.data()))
            .toList()
          ..sort((Variation a, Variation b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  Stream<List<Variation>> watchAll() => _watchOwned();

  Stream<List<Variation>> watchForJob(String jobId) => _watchOwned().map(
      (List<Variation> l) =>
          l.where((Variation v) => v.jobId == jobId).toList());

  /// Approved work across every job that has not yet been billed.
  Stream<List<Variation>> watchUnbilled() =>
      _watchOwned().map((List<Variation> l) => l.unbilled);

  Future<String> create(Variation variation) async {
    final String id = _uuid.v4();
    await _col.doc(id).set(
          Variation(
            id: id,
            ownerId: _uid,
            jobId: variation.jobId,
            jobTitle: variation.jobTitle,
            customerId: variation.customerId,
            description: variation.description,
            amount: variation.amount,
            quantity: variation.quantity,
            category: variation.category,
            vatPercent: variation.vatPercent,
            status: variation.status,
            requestedBy: variation.requestedBy,
            notes: variation.notes,
            approvedAt: variation.status == VariationStatus.approved
                ? DateTime.now()
                : null,
            createdAt: DateTime.now(),
          ).toMap(),
        );
    return id;
  }

  Future<void> update(Variation variation) =>
      _col.doc(variation.id).set(variation.toMap(), SetOptions(merge: true));

  Future<void> setStatus(String id, VariationStatus status) {
    return _col.doc(id).set(<String, dynamic>{
      'status': status.name,
      'approvedAt': status == VariationStatus.approved
          ? Timestamp.now()
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Marks variations as billed once they have been pulled onto an invoice.
  ///
  /// Batched so a multi-variation invoice cannot half-succeed and leave some
  /// extras looking unbilled when the customer has already been charged.
  Future<void> markInvoiced(List<String> ids, String invoiceId) async {
    if (ids.isEmpty) return;
    final WriteBatch batch = _db.batch();
    for (final String id in ids) {
      batch.set(
        _col.doc(id),
        <String, dynamic>{
          'status': VariationStatus.invoiced.name,
          'invoiceId': invoiceId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
