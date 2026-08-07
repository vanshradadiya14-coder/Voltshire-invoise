import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/utils/firestore_utils.dart';

/// A deleted record held for recovery.
class TrashedItem {
  const TrashedItem({
    required this.id,
    required this.collection,
    required this.originalId,
    required this.label,
    required this.data,
    this.deletedAt,
  });

  final String id;

  /// The collection the record came from, so restore knows where to put it.
  final String collection;
  final String originalId;

  /// A human-readable description, captured at delete time. Stored rather than
  /// derived so the list renders without deserialising every document type.
  final String label;

  final Map<String, dynamic> data;
  final DateTime? deletedAt;

  /// Days until this is purged.
  int get daysRemaining {
    if (deletedAt == null) return TrashRepository.retentionDays;
    final int elapsed = DateTime.now().difference(deletedAt!).inDays;
    return (TrashRepository.retentionDays - elapsed).clamp(0, 999);
  }

  String get typeLabel => switch (collection) {
        FirestorePaths.customers => 'Customer',
        FirestorePaths.jobs => 'Job',
        FirestorePaths.quotes => 'Quotation',
        FirestorePaths.invoices => 'Invoice',
        FirestorePaths.payments => 'Payment',
        FirestorePaths.expenses => 'Expense',
        FirestorePaths.documents => 'Document',
        FirestorePaths.photos => 'Photo',
        _ => 'Record',
      };

  factory TrashedItem.fromMap(String id, Map<String, dynamic> map) {
    return TrashedItem(
      id: id,
      collection: asString(map['collection']),
      originalId: asString(map['originalId']),
      label: asString(map['label'], fallback: 'Untitled'),
      data: Map<String, dynamic>.from(
        (map['data'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{},
      ),
      deletedAt: tsToDate(map['deletedAt']),
    );
  }
}

/// A recycle bin for deleted records.
///
/// Implemented as a side collection rather than a `deletedAt` flag on every
/// document. That choice is deliberate: a flag would require adding a
/// `where('deletedAt', isNull: true)` filter to every existing query — nine
/// repositories, easy to miss one, and a missed one silently resurrects
/// deleted records in a list. A separate collection cannot leak into a query
/// that does not name it.
class TrashRepository {
  TrashRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  /// How long deleted records are recoverable.
  static const int retentionDays = 30;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.trash);

  Stream<List<TrashedItem>> watchAll() {
    return _col
        .where('ownerId', isEqualTo: _uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<TrashedItem> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              TrashedItem.fromMap(d.id, d.data()))
          .toList()
        ..sort((TrashedItem a, TrashedItem b) => (b.deletedAt ?? DateTime(0))
            .compareTo(a.deletedAt ?? DateTime(0)));
      return list;
    });
  }

  /// Moves a document to the bin, then removes the original.
  ///
  /// Uses a batch so a record can never exist in both places, or in neither.
  Future<void> moveToTrash({
    required String collection,
    required String docId,
    required String label,
  }) async {
    final DocumentReference<Map<String, dynamic>> src =
        _db.collection(collection).doc(docId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await src.get();
    if (!snap.exists) return;

    final WriteBatch batch = _db.batch();
    batch.set(_col.doc(), <String, dynamic>{
      'ownerId': _uid,
      'collection': collection,
      'originalId': docId,
      'label': label,
      'data': snap.data(),
      'deletedAt': Timestamp.now(),
    });
    batch.delete(src);
    await batch.commit();
  }

  /// Puts a record back where it came from.
  Future<void> restore(TrashedItem item) async {
    final WriteBatch batch = _db.batch();
    batch.set(
      _db.collection(item.collection).doc(item.originalId),
      <String, dynamic>{...item.data, 'ownerId': _uid},
    );
    batch.delete(_col.doc(item.id));
    await batch.commit();
  }

  /// Permanently removes one item.
  Future<void> purge(String trashId) => _col.doc(trashId).delete();

  /// Empties the bin.
  Future<void> purgeAll() async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _col.where('ownerId', isEqualTo: _uid).get();
    // Firestore caps a batch at 500 writes, so chunk it.
    const int chunk = 400;
    for (int i = 0; i < snap.docs.length; i += chunk) {
      final WriteBatch batch = _db.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d
          in snap.docs.skip(i).take(chunk)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// Clears anything past the retention window.
  ///
  /// Client-side rather than a Cloud Function so this works on the free Spark
  /// plan. Runs opportunistically when the user opens the bin.
  Future<int> purgeExpired() async {
    final DateTime cutoff =
        DateTime.now().subtract(const Duration(days: retentionDays));
    final QuerySnapshot<Map<String, dynamic>> snap = await _col
        .where('ownerId', isEqualTo: _uid)
        .where('deletedAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    if (snap.docs.isEmpty) return 0;

    final WriteBatch batch = _db.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }
}
