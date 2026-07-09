import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/job_photo.dart';
import '../services/storage_service.dart';

/// CRUD for the `photos` collection. Photos are attached to a job and stored
/// in Firebase Storage under the owner's folder.
class PhotoRepository {
  PhotoRepository(this._db, this._uid, this._storage);

  final FirebaseFirestore _db;
  final String _uid;
  final StorageService _storage;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.photos);

  Query<Map<String, dynamic>> get _owned => _col.where('ownerId', isEqualTo: _uid);

  Stream<List<JobPhoto>> watchForJob(String jobId) => _owned
      .where('jobId', isEqualTo: jobId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_mapDocs);

  /// Uploads [file] and creates the photo record.
  Future<String> add({
    required String jobId,
    required File file,
    String category = 'Progress',
    String caption = '',
  }) async {
    final UploadResult upload = await _storage.uploadFile(
      folder: StoragePaths.jobPhotos(_uid, jobId),
      file: file,
      contentType: 'image/jpeg',
    );
    final String id = _uuid.v4();
    final JobPhoto photo = JobPhoto(
      id: id,
      ownerId: _uid,
      jobId: jobId,
      url: upload.url,
      storagePath: upload.path,
      category: category,
      caption: caption,
      createdAt: DateTime.now(),
    );
    await _col.doc(id).set(photo.toMap());
    return id;
  }

  Future<void> delete(JobPhoto photo) async {
    await _storage.delete(photo.storagePath);
    await _col.doc(photo.id).delete();
  }

  List<JobPhoto> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => JobPhoto.fromMap(d.id, d.data()))
      .toList();
}
