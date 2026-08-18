import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/payment_stage.dart';
import '../models/trade_enums.dart';

/// CRUD for the `payment_stages` collection — deposits and staged billing.
class PaymentStageRepository {
  PaymentStageRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.paymentStages);

  Query<Map<String, dynamic>> get _owned =>
      _col.where('ownerId', isEqualTo: _uid);

  Stream<List<PaymentStage>> _watchOwned() =>
      _owned.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) => snap
          .docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              PaymentStage.fromMap(d.id, d.data()))
          .toList()
          .ordered);

  Stream<List<PaymentStage>> watchAll() => _watchOwned();

  Stream<List<PaymentStage>> watchForJob(String jobId) => _watchOwned().map(
      (List<PaymentStage> l) =>
          l.where((PaymentStage s) => s.jobId == jobId).toList());

  Future<String> create(PaymentStage stage) async {
    final String id = _uuid.v4();
    await _col.doc(id).set(_withOwner(stage, id).toMap());
    return id;
  }

  Future<void> update(PaymentStage stage) =>
      _col.doc(stage.id).set(stage.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Replaces a job's whole schedule in one atomic write.
  ///
  /// Applying a preset must not be able to half-apply — a schedule with three
  /// of four stages would misreport what is left to bill.
  Future<void> replaceSchedule(
    String jobId,
    List<PaymentStage> stages,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> existing =
        await _owned.where('jobId', isEqualTo: jobId).get();

    final WriteBatch batch = _db.batch();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> d
        in existing.docs) {
      // Never discard a stage that has already been billed — the invoice for
      // it exists and the customer may have paid.
      final bool billed = (d.data()['invoiceId'] as String?) != null;
      if (!billed) batch.delete(d.reference);
    }

    for (int i = 0; i < stages.length; i++) {
      final String id = _uuid.v4();
      batch.set(
        _col.doc(id),
        _withOwner(stages[i].copyWith(order: i), id).toMap(),
      );
    }

    await batch.commit();
  }

  /// Links a stage to the invoice raised for it.
  Future<void> markInvoiced(String stageId, String invoiceId) {
    return _col.doc(stageId).set(<String, dynamic>{
      'invoiceId': invoiceId,
      'status': StageStatus.invoiced.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setStatus(String stageId, StageStatus status) {
    return _col.doc(stageId).set(<String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteForJob(String jobId) async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _owned.where('jobId', isEqualTo: jobId).get();
    if (snap.docs.isEmpty) return;
    final WriteBatch batch = _db.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  PaymentStage _withOwner(PaymentStage s, String id) => PaymentStage(
        id: id,
        ownerId: _uid,
        jobId: s.jobId,
        jobTitle: s.jobTitle,
        customerId: s.customerId,
        customerName: s.customerName,
        label: s.label,
        percent: s.percent,
        fixedAmount: s.fixedAmount,
        order: s.order,
        status: s.status,
        dueDate: s.dueDate,
        invoiceId: s.invoiceId,
        notes: s.notes,
        createdAt: s.createdAt ?? DateTime.now(),
      );
}
