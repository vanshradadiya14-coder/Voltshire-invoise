import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/price_item.dart';

/// CRUD for the `price_items` collection — the builder's saved price list.
class PriceItemRepository {
  PriceItemRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.priceItems);

  Query<Map<String, dynamic>> get _owned =>
      _col.where('ownerId', isEqualTo: _uid);

  /// Most-used first, then alphabetical.
  ///
  /// Ordering by use matters once a builder has 80 saved prices: the day rate
  /// and the skip should not be buried under "Acrow prop".
  Stream<List<PriceItem>> watchAll() {
    return _owned.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<PriceItem> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              PriceItem.fromMap(d.id, d.data()))
          .toList()
        ..sort((PriceItem a, PriceItem b) {
          final int byUse = b.useCount.compareTo(a.useCount);
          if (byUse != 0) return byUse;
          return a.description
              .toLowerCase()
              .compareTo(b.description.toLowerCase());
        });
      return list;
    });
  }

  Future<String> create(PriceItem item) async {
    final String id = _uuid.v4();
    await _col.doc(id).set(
          PriceItem(
            id: id,
            ownerId: _uid,
            description: item.description,
            unitPrice: item.unitPrice,
            unit: item.unit,
            category: item.category,
            vatPercent: item.vatPercent,
            defaultQuantity: item.defaultQuantity,
            notes: item.notes,
            isSeeded: item.isSeeded,
            createdAt: DateTime.now(),
          ).toMap(),
        );
    return id;
  }

  Future<void> update(PriceItem item) =>
      _col.doc(item.id).set(item.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Bumps the usage counter when an item is added to a document.
  ///
  /// Fire-and-forget: a failed counter write must never break adding a line to
  /// an invoice.
  Future<void> recordUse(String id) async {
    try {
      await _col.doc(id).set(<String, dynamic>{
        'useCount': FieldValue.increment(1),
        'lastUsedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Creates the starter price list, once.
  ///
  /// A price library that starts empty is a feature nobody finds. Seeding it
  /// with realistic trade defaults means the first quote a builder writes is
  /// already faster than doing it on paper.
  ///
  /// Returns the number of items created; 0 when the list was not empty.
  Future<int> seedDefaults() async {
    final QuerySnapshot<Map<String, dynamic>> existing =
        await _owned.limit(1).get();
    if (existing.docs.isNotEmpty) return 0;

    final WriteBatch batch = _db.batch();
    for (final ({
      String description,
      double price,
      dynamic unit,
      dynamic category,
      double qty,
    }) seed in PriceItemSeeds.defaults) {
      final String id = _uuid.v4();
      batch.set(
        _col.doc(id),
        PriceItem(
          id: id,
          ownerId: _uid,
          description: seed.description,
          unitPrice: seed.price,
          unit: seed.unit,
          category: seed.category,
          defaultQuantity: seed.qty,
          isSeeded: true,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    }
    await batch.commit();
    return PriceItemSeeds.defaults.length;
  }

  /// Removes only the seeded starter items, leaving anything the builder added.
  Future<int> clearSeeded() async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _owned.where('isSeeded', isEqualTo: true).get();
    if (snap.docs.isEmpty) return 0;

    final WriteBatch batch = _db.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }
}
