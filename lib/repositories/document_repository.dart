import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/document_file.dart';
import '../services/storage_service.dart';

/// CRUD for the `documents` collection (contracts, certificates, guarantees,
/// planning docs, receipts, invoices, …).
class DocumentRepository {
  DocumentRepository(this._db, this._uid, this._storage);

  final FirebaseFirestore _db;
  final String _uid;
  final StorageService _storage;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.documents);

  Query<Map<String, dynamic>> get _owned => _col.where('ownerId', isEqualTo: _uid);

  Stream<List<DocumentFile>> watchAll() =>
      _owned.orderBy('createdAt', descending: true).snapshots().map(_mapDocs);

  Stream<List<DocumentFile>> watchForJob(String jobId) => _owned
      .where('jobId', isEqualTo: jobId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapDocs);

  Future<String> add({
    required File file,
    required String name,
    required String category,
    required String contentType,
    String? jobId,
    String? customerId,
  }) async {
    final UploadResult upload = await _storage.uploadFile(
      folder: StoragePaths.documents(_uid),
      file: file,
      fileName: '${DateTime.now().millisecondsSinceEpoch}_$name',
      contentType: contentType,
    );
    final String id = _uuid.v4();
    final DocumentFile doc = DocumentFile(
      id: id,
      ownerId: _uid,
      name: name,
      url: upload.url,
      storagePath: upload.path,
      category: category,
      contentType: contentType,
      sizeBytes: upload.sizeBytes,
      jobId: jobId,
      customerId: customerId,
      createdAt: DateTime.now(),
    );
    await _col.doc(id).set(doc.toMap());
    return id;
  }

  Future<void> delete(DocumentFile doc) async {
    await _storage.delete(doc.storagePath);
    await _col.doc(doc.id).delete();
  }

  List<DocumentFile> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => DocumentFile.fromMap(d.id, d.data()))
      .toList();
}
