import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/job.dart';

/// CRUD for the `jobs` collection.
class JobRepository {
  JobRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.jobs);

  Query<Map<String, dynamic>> get _owned => _col.where('ownerId', isEqualTo: _uid);

  Stream<List<Job>> watchAll() =>
      _owned.orderBy('createdAt', descending: true).snapshots().map(_mapDocs);

  Stream<List<Job>> watchByStatus(JobStatus status) => _owned
      .where('status', isEqualTo: status.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapDocs);

  Stream<List<Job>> watchForCustomer(String customerId) => _owned
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapDocs);

  Stream<Job?> watchById(String id) => _col.doc(id).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> d) =>
          d.exists ? Job.fromMap(d.id, d.data()!) : null);

  Future<Job?> fetchById(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> d = await _col.doc(id).get();
    return d.exists ? Job.fromMap(d.id, d.data()!) : null;
  }

  Future<String> create(Job job) async {
    final String id = _uuid.v4();
    final Job toSave = Job(
      id: id,
      ownerId: _uid,
      customerId: job.customerId,
      customerName: job.customerName,
      title: job.title,
      siteAddress: job.siteAddress,
      description: job.description,
      status: job.status,
      startDate: job.startDate,
      completionDate: job.completionDate,
      notes: job.notes,
      createdAt: DateTime.now(),
    );
    await _col.doc(id).set(toSave.toMap());
    return id;
  }

  Future<void> update(Job job) =>
      _col.doc(job.id).set(job.toMap(), SetOptions(merge: true));

  Future<void> updateStatus(String id, JobStatus status) => _col.doc(id).set(
        <String, dynamic>{'status': status.name, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  Future<void> delete(String id) => _col.doc(id).delete();

  List<Job> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => Job.fromMap(d.id, d.data()))
      .toList();
}
