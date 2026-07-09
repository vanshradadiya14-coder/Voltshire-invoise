import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/customer.dart';

/// CRUD + search for the `customers` collection, always scoped to the owner UID.
class CustomerRepository {
  CustomerRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.customers);

  Query<Map<String, dynamic>> get _owned =>
      _col.where('ownerId', isEqualTo: _uid);

  /// All customers, sorted alphabetically on-device (so no Firestore composite
  /// index is required).
  Stream<List<Customer>> watchAll() {
    return _owned.snapshots().map((snap) {
      final List<Customer> list = _mapDocs(snap);
      list.sort((Customer a, Customer b) => a.nameLower.compareTo(b.nameLower));
      return list;
    });
  }

  Stream<Customer?> watchById(String id) {
    return _col.doc(id).snapshots().map((DocumentSnapshot<Map<String, dynamic>> d) =>
        d.exists ? Customer.fromMap(d.id, d.data()!) : null);
  }

  Future<Customer?> fetchById(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> d = await _col.doc(id).get();
    return d.exists ? Customer.fromMap(d.id, d.data()!) : null;
  }

  /// Case-insensitive search on name / phone / email (filtered on-device).
  Stream<List<Customer>> search(String term) {
    final String q = term.toLowerCase().trim();
    if (q.isEmpty) return watchAll();
    return watchAll().map((List<Customer> list) => list
        .where((Customer c) =>
            c.nameLower.contains(q) ||
            c.phone.contains(q) ||
            c.email.toLowerCase().contains(q))
        .toList());
  }

  Future<String> create(Customer customer) async {
    final String id = _uuid.v4();
    final Customer toSave = Customer(
      id: id,
      ownerId: _uid,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      billingAddress: customer.billingAddress,
      siteAddress: customer.siteAddress,
      notes: customer.notes,
      createdAt: DateTime.now(),
    );
    await _col.doc(id).set(toSave.toMap());
    return id;
  }

  Future<void> update(Customer customer) async {
    await _col.doc(customer.id).set(customer.toMap(), SetOptions(merge: true));
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  List<Customer> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => Customer.fromMap(d.id, d.data()))
      .toList();
}
